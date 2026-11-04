import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/deep_links.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/app_notification.dart';
import 'package:jobtrail/features/notifications/application/group_notifications.dart';

AppNotification _n(int id, DateTime at, {int? app, int? interview}) =>
    AppNotification(
      id: id,
      type: NotificationType.system,
      title: 't$id',
      body: 'b',
      createdAt: at,
      relatedApplicationId: app,
      relatedInterviewId: interview,
    );

void main() {
  final now = DateTime(2026, 10, 25, 9, 30);

  group('groupNotifications', () {
    test('splits into Today / Yesterday / Earlier and drops empty groups', () {
      final groups = groupNotifications([
        _n(1, DateTime(2026, 10, 25, 8)),
        _n(2, DateTime(2026, 10, 24, 22)),
        _n(3, DateTime(2026, 10, 20)),
        _n(4, DateTime(2026, 10, 25, 1)),
      ], now);

      expect(groups.map((g) => g.kind), [
        NotificationGroupKind.today,
        NotificationGroupKind.yesterday,
        NotificationGroupKind.earlier,
      ]);
      expect(groups[0].items.map((n) => n.id), [1, 4], reason: 'order kept');
      expect(groups[1].items.single.id, 2);
      expect(groups[2].items.single.id, 3);

      expect(
        groupNotifications([
          _n(1, DateTime(2026, 10, 25, 8)),
        ], now).map((g) => g.kind),
        [NotificationGroupKind.today],
      );
      expect(groupNotifications(const [], now), isEmpty);
    });

    test('midnight boundaries', () {
      NotificationGroupKind of(DateTime d) => notificationGroupOf(d, now);

      expect(of(DateTime(2026, 10, 25, 0, 0, 0)), NotificationGroupKind.today);
      expect(
        of(DateTime(2026, 10, 24, 23, 59, 59, 999)),
        NotificationGroupKind.yesterday,
      );
      expect(of(DateTime(2026, 10, 24, 0, 0)), NotificationGroupKind.yesterday);
      expect(
        of(DateTime(2026, 10, 23, 23, 59, 59)),
        NotificationGroupKind.earlier,
      );
    });

    test(
      '"now" just after midnight still has yesterday evening as yesterday',
      () {
        final justAfterMidnight = DateTime(2026, 10, 25, 0, 0, 5);
        expect(
          notificationGroupOf(
            DateTime(2026, 10, 24, 23, 59, 58),
            justAfterMidnight,
          ),
          NotificationGroupKind.yesterday,
        );
        expect(
          notificationGroupOf(
            DateTime(2026, 10, 25, 0, 0, 1),
            justAfterMidnight,
          ),
          NotificationGroupKind.today,
        );
      },
    );

    test('compares calendar days in local time, not UTC', () {
      // The same instant lands on different local days depending on the
      // device zone, so the bucket must follow `toLocal()`.
      final instant = DateTime.utc(2026, 10, 24, 23, 30);
      final localDay = instant.toLocal();
      final nowLocal = DateTime(
        localDay.year,
        localDay.month,
        localDay.day,
        12,
      );
      expect(
        notificationGroupOf(instant, nowLocal),
        NotificationGroupKind.today,
      );
      expect(
        notificationGroupOf(instant, nowLocal.add(const Duration(days: 1))),
        NotificationGroupKind.yesterday,
      );
    });

    test('a timestamp slightly in the future counts as today', () {
      expect(
        notificationGroupOf(DateTime(2026, 10, 25, 23), now),
        NotificationGroupKind.today,
      );
    });
  });

  group('deep links', () {
    test('only interview and application detail paths are safe', () {
      expect(isSafeDeepLink('/interviews/3'), isTrue);
      expect(isSafeDeepLink('/applications/12'), isTrue);
      expect(isSafeDeepLink('/applications/new'), isFalse);
      expect(isSafeDeepLink('/settings'), isFalse);
      expect(isSafeDeepLink('https://evil.example/interviews/1'), isFalse);
      expect(isSafeDeepLink('/interviews/1/edit'), isFalse);
      expect(isSafeDeepLink(null), isFalse);
    });

    test('a notification opens its interview, else its application', () {
      expect(
        deepLinkForNotification(_n(1, now, app: 2, interview: 3)),
        '/interviews/3',
      );
      expect(deepLinkForNotification(_n(1, now, app: 2)), '/applications/2');
      expect(deepLinkForNotification(_n(1, now)), isNull);
    });
  });
}
