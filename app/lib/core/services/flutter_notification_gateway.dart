import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// Converts an instant to a [tz.TZDateTime] in [location].
tz.TZDateTime toZoned(DateTime instant, tz.Location location) =>
    tz.TZDateTime.from(instant, location);

/// [NotificationGateway] over `flutter_local_notifications`.
class FlutterNotificationGateway implements NotificationGateway {
  /// Creates the gateway; pass a [plugin] only in tests.
  FlutterNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init({required void Function(String payload) onTap}) async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    final android = _android;
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          ReminderChannels.interview,
          'Interview reminders',
          description: 'Reminders before your interviews',
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          ReminderChannels.followUp,
          'Follow-up reminders',
          description: 'Reminders to follow up on applications',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  @override
  Future<String> deviceTimezone() async =>
      (await FlutterTimezone.getLocalTimezone());

  @override
  Future<void> setTimezone(String name) async {
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final granted = await _android?.requestNotificationsPermission();
      // Exact alarms are optional; without them reminders are less precise.
      await _android?.requestExactAlarmsPermission();
      return granted ?? false;
    }
    if (Platform.isIOS) {
      return await _ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<bool> areEnabled() async {
    if (Platform.isAndroid) {
      return await _android?.areNotificationsEnabled() ?? false;
    }
    if (Platform.isIOS) {
      return (await _ios?.checkPermissions())?.isEnabled ?? false;
    }
    return false;
  }

  @override
  Future<bool> canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule(ScheduledReminder reminder, {required bool exact}) {
    final isInterview = reminder.channelId == ReminderChannels.interview;
    return _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      reminder.body,
      toZoned(reminder.fireAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          reminder.channelId,
          isInterview ? 'Interview reminders' : 'Follow-up reminders',
          importance: isInterview
              ? Importance.high
              : Importance.defaultImportance,
          priority: isInterview ? Priority.high : Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminder.payload,
    );
  }
}
