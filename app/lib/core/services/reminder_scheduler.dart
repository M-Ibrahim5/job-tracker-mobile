import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../domain/enums/enums.dart';
import '../../domain/models/reminder_item.dart';
import '../../domain/repositories/misc_repositories.dart';
import 'reminder_canceller.dart';

/// Most local notifications scheduled at once (iOS keeps at most 64 pending).
const int kMaxScheduledReminders = 60;

/// Channel ids, one per [ReminderKind].
abstract final class ReminderChannels {
  static const interview = 'interview_reminders';
  static const followUp = 'follow_up_reminders';

  /// Channel used for [kind].
  static String of(ReminderKind kind) => switch (kind) {
    ReminderKind.interviewReminder => interview,
    ReminderKind.followUpReminder => followUp,
  };
}

/// Deep-link path opened when a reminder is tapped.
String reminderPayload(ReminderItem item) {
  if (item.interviewId != null) return '/interviews/${item.interviewId}';
  if (item.applicationId != null) return '/applications/${item.applicationId}';
  return '/';
}

/// One notification handed to the platform.
class ScheduledReminder {
  /// Creates a request.
  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.channelId,
    required this.payload,
  });

  /// Stable id derived from the reminder key.
  final int id;
  final String title;
  final String body;

  /// The instant to fire at; the gateway converts it to the device zone.
  final DateTime fireAt;
  final String channelId;
  final String payload;
}

/// Thin seam over `flutter_local_notifications` so scheduling logic can be
/// unit-tested without a platform.
abstract interface class NotificationGateway {
  /// Sets up plugin, timezone database and channels. [onTap] receives the
  /// payload of a tapped notification.
  Future<void> init({required void Function(String payload) onTap});

  /// IANA name of the device timezone, e.g. `Asia/Kuala_Lumpur`.
  Future<String> deviceTimezone();

  /// Makes [name] the zone used to convert fire times.
  Future<void> setTimezone(String name);

  /// Payload of the notification that cold-started the app, if any.
  Future<String?> launchPayload();

  /// Shows the system permission prompt; true when granted.
  Future<bool> requestPermission();

  /// Whether the OS currently lets the app post notifications.
  Future<bool> areEnabled();

  /// Whether exact alarms are allowed (Android 12+).
  Future<bool> canScheduleExact();

  /// Cancels every scheduled notification.
  Future<void> cancelAll();

  /// Schedules [reminder]; [exact] picks an exact vs inexact alarm.
  Future<void> schedule(ScheduledReminder reminder, {required bool exact});
}

/// Schedules and cancels the device's local reminder notifications.
abstract interface class ReminderScheduler implements ReminderCanceller {
  /// Prepares the plugin; safe to call more than once.
  Future<void> init();

  /// Payload of the notification that launched the app (consumed once).
  Future<String?> takeLaunchPayload();

  /// Asks the OS for permission (after the app explained why).
  Future<bool> requestPermission();

  /// Whether notifications are currently allowed.
  Future<bool> notificationsEnabled();

  /// Rebuilds all local reminders from `GET /reminders/upcoming`.
  Future<void> resync();

  /// Re-syncs when the device timezone changed since the last check.
  Future<void> checkTimezone();
}

/// Default that does nothing (tests, fake backend without a platform).
class NoopReminderScheduler implements ReminderScheduler {
  /// Creates the no-op scheduler.
  const NoopReminderScheduler();

  @override
  Future<void> init() async {}

  @override
  Future<String?> takeLaunchPayload() async => null;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<void> resync() async {}

  @override
  Future<void> checkTimezone() async {}

  @override
  Future<void> cancelAll() async {}
}

/// Scheduler backed by a [NotificationGateway] and the reminder endpoint.
class LocalReminderScheduler implements ReminderScheduler {
  /// Creates the scheduler. [isSignedIn] guards against scheduling after
  /// logout; [onOpenPayload] receives taps on notifications.
  LocalReminderScheduler({
    required NotificationGateway gateway,
    required ReminderRepository repository,
    required bool Function() isSignedIn,
    required void Function(String payload) onOpenPayload,
    Logger? logger,
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _repository = repository,
       _isSignedIn = isSignedIn,
       _onOpenPayload = onOpenPayload,
       _logger = logger,
       _clock = clock ?? DateTime.now;

  final NotificationGateway _gateway;
  final ReminderRepository _repository;
  final bool Function() _isSignedIn;
  final void Function(String payload) _onOpenPayload;
  final Logger? _logger;
  final DateTime Function() _clock;

  Future<void>? _initialising;
  Future<void>? _running;
  bool _dirty = false;
  String? _timezone;

  @override
  Future<void> init() => _initialising ??= _init();

  Future<void> _init() async {
    await _gateway.init(onTap: _onOpenPayload);
    _timezone = await _gateway.deviceTimezone();
    await _gateway.setTimezone(_timezone!);
  }

  @override
  Future<String?> takeLaunchPayload() async {
    await init();
    return _gateway.launchPayload();
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    final granted = await _gateway.requestPermission();
    if (granted) unawaited(resync());
    return granted;
  }

  @override
  Future<bool> notificationsEnabled() async {
    await init();
    return _gateway.areEnabled();
  }

  @override
  Future<void> checkTimezone() async {
    await init();
    final current = await _gateway.deviceTimezone();
    if (current == _timezone) return;
    _timezone = current;
    await _gateway.setTimezone(current);
    await resync();
  }

  /// Concurrent calls are coalesced: while a sync runs, further requests just
  /// mark it dirty and one more pass follows.
  @override
  Future<void> resync() {
    _dirty = true;
    return _running ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_dirty) {
        _dirty = false;
        try {
          await _syncOnce();
        } catch (e, st) {
          _logger?.w('Reminder sync failed', error: e, stackTrace: st);
        }
      }
    } finally {
      _running = null;
    }
  }

  Future<void> _syncOnce() async {
    await init();
    if (!_isSignedIn()) return;
    if (!await _gateway.areEnabled()) return;

    final now = _clock();
    final items =
        (await _repository.upcoming())
            .where((r) => r.fireAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.fireAt.compareTo(b.fireAt));

    await _gateway.cancelAll();
    final exact = await _gateway.canScheduleExact();
    for (final item in items.take(kMaxScheduledReminders)) {
      try {
        await _gateway.schedule(
          ScheduledReminder(
            id: item.notificationId,
            title: item.title,
            body: item.body,
            fireAt: item.fireAt,
            channelId: ReminderChannels.of(item.kind),
            payload: reminderPayload(item),
          ),
          exact: exact,
        );
      } catch (e) {
        _logger?.w('Could not schedule ${item.key}: $e');
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _gateway.cancelAll();
  }
}

/// Local reminder scheduler used after data changes. `main` overrides it with
/// [LocalReminderScheduler]; the default is a no-op so tests never touch
/// platform plugins.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => const NoopReminderScheduler(),
);
