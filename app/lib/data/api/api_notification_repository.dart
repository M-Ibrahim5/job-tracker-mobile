import 'package:dio/dio.dart';

import '../../domain/models/app_notification.dart';
import '../../domain/models/page.dart';
import '../../domain/models/reminder_item.dart';
import '../../domain/repositories/misc_repositories.dart';
import '../../domain/repositories/notification_repository.dart';
import 'error_mapper.dart';

/// [NotificationRepository] over the REST API (`API.md` → Notifications).
class ApiNotificationRepository implements NotificationRepository {
  /// Creates the repository.
  ApiNotificationRepository(this._dio);

  final Dio _dio;

  @override
  Future<Page<AppNotification>> list({int page = 1, int pageSize = 20}) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>(
        '/notifications',
        queryParameters: {'page': page, 'pageSize': pageSize},
      ),
    );
    return Page.fromJson(res.data!, AppNotification.fromJson);
  }

  @override
  Future<int> unreadCount() async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/notifications/unread-count'),
    );
    return res.data!['count'] as int;
  }

  @override
  Future<void> markRead(int id) =>
      guardApi(() => _dio.post<void>('/notifications/$id/read'));

  @override
  Future<void> markAllRead() =>
      guardApi(() => _dio.post<void>('/notifications/read-all'));

  @override
  Future<void> delete(int id) =>
      guardApi(() => _dio.delete<void>('/notifications/$id'));

  @override
  Future<void> clear() => guardApi(() => _dio.delete<void>('/notifications'));
}

/// [ReminderRepository] over the REST API (`API.md` → Device reminders).
class ApiReminderRepository implements ReminderRepository {
  /// Creates the repository.
  ApiReminderRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<ReminderItem>> upcoming() async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/reminders/upcoming'),
    );
    return (res.data!['items'] as List)
        .map((e) => ReminderItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
