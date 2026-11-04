/// User-facing strings of the Alerts center and notification permission flow.
abstract final class AlertsStrings {
  static const title = 'Alerts';
  static const markAllRead = 'Mark all read';
  static const clearAll = 'Clear all';
  static const clearTitle = 'Clear all alerts?';
  static const clearMessage = 'This removes every alert from the list.';
  static const emptyTitle = "You're all caught up";
  static const emptyMessage = 'New reminders and status updates show up here.';
  static const deleteFailed = "Couldn't update your alerts.";
  static const loadMoreFailed = "Couldn't load more.";
  static String semanticsUnread(String title) => 'Unread: $title';

  // Permission banner / sheet.
  static const bannerMessage =
      'Phone reminders are off. Turn on notifications to be reminded about '
      'interviews and follow-ups.';
  static const bannerAction = 'Enable';
  static const permissionTitle = 'Get reminders on your phone';
  static const permissionBody =
      'JobTrail can remind you before an interview and when it is time to '
      'follow up. You can change this any time in your phone settings.';
  static const permissionAllow = 'Allow notifications';
  static const permissionLater = 'Not now';
  static const permissionDenied =
      'Notifications are off. You can enable them in your phone settings.';
}
