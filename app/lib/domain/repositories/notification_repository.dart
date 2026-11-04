import '../models/app_notification.dart';
import '../models/page.dart';

/// In-app notification center (`API.md` → Notifications).
abstract interface class NotificationRepository {
  /// `GET /notifications`, newest first.
  Future<Page<AppNotification>> list({int page = 1, int pageSize = 20});

  /// `GET /notifications/unread-count` (drives the nav badge).
  Future<int> unreadCount();

  /// `POST /notifications/:id/read`.
  Future<void> markRead(int id);

  /// `POST /notifications/read-all`.
  Future<void> markAllRead();

  /// `DELETE /notifications/:id`.
  Future<void> delete(int id);

  /// `DELETE /notifications`.
  Future<void> clear();
}
