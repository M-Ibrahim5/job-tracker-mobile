import '../../../core/utils/date_helpers.dart';
import '../../../domain/models/app_notification.dart';

/// Day bucket of the Alerts list.
enum NotificationGroupKind {
  today('Today'),
  yesterday('Yesterday'),
  earlier('Earlier');

  const NotificationGroupKind(this.label);

  /// Heading shown above the group.
  final String label;
}

/// Notifications that share a [kind] bucket, in the original order.
class NotificationGroup {
  /// Creates a group.
  const NotificationGroup(this.kind, this.items);

  final NotificationGroupKind kind;
  final List<AppNotification> items;
}

/// Bucket of a notification created at [createdAt] as seen at [now], by
/// calendar day in the device's local time.
NotificationGroupKind notificationGroupOf(DateTime createdAt, DateTime now) {
  final day = DateHelpers.dayOnly(createdAt.toLocal());
  final today = DateHelpers.dayOnly(now.toLocal());
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (!day.isBefore(today)) return NotificationGroupKind.today;
  if (day == yesterday) return NotificationGroupKind.yesterday;
  return NotificationGroupKind.earlier;
}

/// Splits [items] (newest first) into Today / Yesterday / Earlier groups,
/// dropping empty ones. Timestamps in the future count as today.
List<NotificationGroup> groupNotifications(
  List<AppNotification> items,
  DateTime now,
) {
  final buckets = {
    for (final k in NotificationGroupKind.values) k: <AppNotification>[],
  };
  for (final n in items) {
    buckets[notificationGroupOf(n.createdAt, now)]!.add(n);
  }
  return [
    for (final k in NotificationGroupKind.values)
      if (buckets[k]!.isNotEmpty) NotificationGroup(k, buckets[k]!),
  ];
}
