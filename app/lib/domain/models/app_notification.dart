import '../../core/utils/api_date.dart';
import '../enums/enums.dart';

/// An entry in the in-app notification center (`Notification` in `API.md`).
class AppNotification {
  /// Creates an immutable notification entry.
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.relatedApplicationId,
    this.relatedInterviewId,
    this.isRead = false,
  });

  /// Parses an API notification.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: enumByName(NotificationType.values, json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      relatedApplicationId: json['relatedApplicationId'] as int?,
      relatedInterviewId: json['relatedInterviewId'] as int?,
      createdAt: ApiDate.parseUtc(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  final int id;
  final NotificationType type;
  final String title;
  final String body;
  final int? relatedApplicationId;
  final int? relatedInterviewId;
  final DateTime createdAt;
  final bool isRead;

  /// Returns a copy with the given fields replaced.
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      relatedApplicationId: relatedApplicationId,
      relatedInterviewId: relatedInterviewId,
      isRead: isRead ?? this.isRead,
    );
  }

  /// JSON mirror of the API representation.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'relatedApplicationId': relatedApplicationId,
    'relatedInterviewId': relatedInterviewId,
    'createdAt': ApiDate.toUtcIso(createdAt),
    'isRead': isRead,
  };
}
