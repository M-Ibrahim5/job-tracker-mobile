import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/services/flutter_notification_gateway.dart';
import 'package:jobtrail/core/services/reminder_scheduler.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/reminder_item.dart';
import 'package:jobtrail/domain/repositories/misc_repositories.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _FakeGateway implements NotificationGateway {
  final calls = <String>[];
  final scheduled = <({ScheduledReminder reminder, bool exact})>[];
  void Function(String)? onTap;
  String timezone = 'Asia/Kuala_Lumpur';
  String? timezoneSet;
  bool enabled = true;
  bool exactAllowed = true;
  String? launch;
  int inits = 0;
  int cancels = 0;

  @override
  Future<void> init({required void Function(String payload) onTap}) async {
    inits++;
    this.onTap = onTap;
  }

  @override
  Future<String> deviceTimezone() async => timezone;

  @override
  Future<void> setTimezone(String name) async {
    timezoneSet = name;
    calls.add('tz:$name');
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<bool> requestPermission() async {
    enabled = true;
    return true;
  }

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  @override
  Future<void> cancelAll() async {
    cancels++;
    calls.add('cancel');
    scheduled.clear();
  }

  @override
  Future<void> schedule(
    ScheduledReminder reminder, {
    required bool exact,
  }) async {
    calls.add('schedule:${reminder.id}');
    scheduled.add((reminder: reminder, exact: exact));
  }
}

class _FakeRepo implements ReminderRepository {
  List<ReminderItem> items = [];
  Object? error;
  int calls = 0;

  @override
  Future<List<ReminderItem>> upcoming() async {
    calls++;
    if (error != null) throw error!;
    return items;
  }
}

final _now = DateTime.utc(2026, 10, 25, 4);

ReminderItem _item(
  String key,
  Duration fromNow, {
  ReminderKind kind = ReminderKind.interviewReminder,
  int? interviewId,
  int? applicationId = 12,
}) => ReminderItem(
  key: key,
  kind: kind,
  fireAt: _now.add(fromNow),
  title: 'Title $key',
  body: 'Body $key',
  applicationId: applicationId,
  interviewId: interviewId,
);

({
  LocalReminderScheduler scheduler,
  _FakeGateway gateway,
  _FakeRepo repo,
  List<String> taps,
})
_build({bool signedIn = true}) {
  final gateway = _FakeGateway();
  final repo = _FakeRepo();
  final taps = <String>[];
  final scheduler = LocalReminderScheduler(
    gateway: gateway,
    repository: repo,
    isSignedIn: () => signedIn,
    onOpenPayload: taps.add,
    clock: () => _now,
  );
  return (scheduler: scheduler, gateway: gateway, repo: repo, taps: taps);
}

void main() {
  group('resync', () {
    test(
      'schedules every future reminder with a stable id and payload',
      () async {
        final t = _build();
        t.repo.items = [
          _item('interview:3:1440', const Duration(hours: 20), interviewId: 3),
          _item(
            'followUp:12',
            const Duration(days: 2),
            kind: ReminderKind.followUpReminder,
          ),
        ];
        await t.scheduler.resync();

        expect(t.gateway.scheduled, hasLength(2));
        final first = t.gateway.scheduled[0].reminder;
        expect(first.id, t.repo.items[0].notificationId);
        expect(first.fireAt, _now.add(const Duration(hours: 20)));
        expect(first.channelId, ReminderChannels.interview);
        expect(first.payload, '/interviews/3');
        expect(first.title, 'Title interview:3:1440');

        final second = t.gateway.scheduled[1].reminder;
        expect(second.channelId, ReminderChannels.followUp);
        expect(second.payload, '/applications/12');
        expect(first.id, isNot(second.id));
        expect(first.id & 0x7fffffff, first.id, reason: 'positive 31-bit id');
      },
    );

    test('never schedules a time that is not in the future', () async {
      final t = _build();
      t.repo.items = [
        _item('interview:1:60', const Duration(minutes: -1), interviewId: 1),
        _item('interview:1:15', Duration.zero, interviewId: 1),
        _item('interview:2:60', const Duration(minutes: 1), interviewId: 2),
      ];
      await t.scheduler.resync();
      expect(t.gateway.scheduled.map((s) => s.reminder.payload), [
        '/interviews/2',
      ]);
    });

    test('replaces the previous schedule instead of adding to it', () async {
      final t = _build();
      t.repo.items = [
        _item('interview:1:60', const Duration(hours: 1), interviewId: 1),
        _item('interview:2:60', const Duration(hours: 2), interviewId: 2),
      ];
      await t.scheduler.resync();
      expect(t.gateway.scheduled, hasLength(2));

      // Interview 2 was deleted on the server.
      t.repo.items = [t.repo.items.first];
      await t.scheduler.resync();
      expect(t.gateway.scheduled, hasLength(1));
      expect(t.gateway.cancels, 2);
      // Cancel always comes before the new schedules.
      expect(
        t.gateway.calls.sublist(t.gateway.calls.lastIndexOf('cancel')).first,
        'cancel',
      );
    });

    test('schedules the soonest ones when there are too many', () async {
      final t = _build();
      t.repo.items = [
        for (var i = 0; i < 70; i++)
          _item(
            'followUp:$i',
            Duration(hours: 70 - i),
            kind: ReminderKind.followUpReminder,
            applicationId: i + 1,
          ),
      ];
      await t.scheduler.resync();
      expect(t.gateway.scheduled, hasLength(kMaxScheduledReminders));
      final latest = t.gateway.scheduled
          .map((s) => s.reminder.fireAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      expect(latest, _now.add(const Duration(hours: 70 - 10)));
    });

    test('uses inexact alarms when exact ones are not allowed', () async {
      final t = _build();
      t.gateway.exactAllowed = false;
      t.repo.items = [
        _item('interview:1:60', const Duration(hours: 1), interviewId: 1),
      ];
      await t.scheduler.resync();
      expect(t.gateway.scheduled.single.exact, isFalse);

      t.gateway.exactAllowed = true;
      await t.scheduler.resync();
      expect(t.gateway.scheduled.single.exact, isTrue);
    });

    test('does nothing when signed out or notifications are off', () async {
      final out = _build(signedIn: false);
      out.repo.items = [
        _item('interview:1:60', const Duration(hours: 1), interviewId: 1),
      ];
      await out.scheduler.resync();
      expect(out.repo.calls, 0);
      expect(out.gateway.scheduled, isEmpty);

      final off = _build();
      off.gateway.enabled = false;
      off.repo.items = out.repo.items;
      await off.scheduler.resync();
      expect(off.repo.calls, 0);
      expect(off.gateway.scheduled, isEmpty);
    });

    test('a failing request keeps the current schedule', () async {
      final t = _build();
      t.repo.items = [
        _item('interview:1:60', const Duration(hours: 1), interviewId: 1),
      ];
      await t.scheduler.resync();

      t.repo.error = const NetworkFailure();
      await t.scheduler.resync();
      expect(t.gateway.scheduled, hasLength(1), reason: 'not cancelled');
      expect(t.gateway.cancels, 1);
    });

    test(
      'concurrent calls are coalesced into at most one extra pass',
      () async {
        final t = _build();
        t.repo.items = [
          _item('interview:1:60', const Duration(hours: 1), interviewId: 1),
        ];
        await Future.wait([
          t.scheduler.resync(),
          t.scheduler.resync(),
          t.scheduler.resync(),
        ]);
        expect(t.repo.calls, lessThanOrEqualTo(2));
        expect(t.gateway.scheduled, hasLength(1));
      },
    );

    test('init runs once and sets the device timezone', () async {
      final t = _build();
      await t.scheduler.init();
      await t.scheduler.init();
      await t.scheduler.resync();
      expect(t.gateway.inits, 1);
      expect(t.gateway.timezoneSet, 'Asia/Kuala_Lumpur');
    });
  });

  group('timezone', () {
    test(
      'a changed device timezone updates the zone and reschedules',
      () async {
        final t = _build();
        t.repo.items = [
          _item('interview:1:60', const Duration(hours: 1), interviewId: 1),
        ];
        await t.scheduler.resync();
        final before = t.repo.calls;

        await t.scheduler.checkTimezone();
        expect(t.repo.calls, before, reason: 'unchanged zone: nothing to do');

        t.gateway.timezone = 'Europe/London';
        await t.scheduler.checkTimezone();
        expect(t.gateway.timezoneSet, 'Europe/London');
        expect(t.repo.calls, before + 1);
      },
    );

    test('toZoned keeps the instant and expresses it in the local zone', () {
      tzdata.initializeTimeZones();
      final kl = tz.getLocation('Asia/Kuala_Lumpur');
      final ny = tz.getLocation('America/New_York');
      final instant = DateTime.utc(2026, 10, 27, 2); // 10:00 in Kuala Lumpur

      final a = toZoned(instant, kl);
      expect(a.hour, 10);
      expect(a.isAtSameMomentAs(instant), isTrue);

      final b = toZoned(instant, ny);
      expect(b.hour, 22); // previous evening, EDT (UTC-4)
      expect(b.day, 26);
      expect(b.isAtSameMomentAs(instant), isTrue);
    });
  });

  group('permission, launch and taps', () {
    test('requestPermission asks the OS and then plans reminders', () async {
      final t = _build();
      t.gateway.enabled = false;
      t.repo.items = [
        _item('interview:1:60', const Duration(hours: 1), interviewId: 1),
      ];

      expect(await t.scheduler.notificationsEnabled(), isFalse);
      expect(await t.scheduler.requestPermission(), isTrue);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(t.gateway.scheduled, hasLength(1));
    });

    test('taps and the launch payload reach the app', () async {
      final t = _build();
      t.gateway.launch = '/interviews/9';
      expect(await t.scheduler.takeLaunchPayload(), '/interviews/9');

      t.gateway.onTap!('/applications/4');
      expect(t.taps, ['/applications/4']);
    });

    test('cancelAll cancels everything', () async {
      final t = _build();
      t.repo.items = [
        _item('interview:1:60', const Duration(hours: 1), interviewId: 1),
      ];
      await t.scheduler.resync();
      await t.scheduler.cancelAll();
      expect(t.gateway.scheduled, isEmpty);
    });

    test('payloads: interview wins over application', () {
      expect(
        reminderPayload(
          _item('k', Duration.zero, interviewId: 5, applicationId: 2),
        ),
        '/interviews/5',
      );
      expect(
        reminderPayload(_item('k', Duration.zero, applicationId: 2)),
        '/applications/2',
      );
    });
  });
}
