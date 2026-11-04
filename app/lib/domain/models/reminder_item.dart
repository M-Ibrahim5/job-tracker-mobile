import '../../core/utils/api_date.dart';
import '../enums/enums.dart';

/// A local notification to schedule (`items[]` in `GET /reminders/upcoming`).
class ReminderItem {
  /// Creates a reminder.
  const ReminderItem({
    required this.key,
    required this.kind,
    required this.fireAt,
    required this.title,
    required this.body,
    this.applicationId,
    this.interviewId,
  });

  /// Parses an API reminder.
  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
    key: json['key'] as String,
    kind: enumByName(ReminderKind.values, json['kind'] as String),
    fireAt: ApiDate.parseUtc(json['fireAt'] as String),
    title: json['title'] as String,
    body: json['body'] as String,
    applicationId: json['applicationId'] as int?,
    interviewId: json['interviewId'] as int?,
  );

  final String key;
  final ReminderKind kind;
  final DateTime fireAt;
  final String title;
  final String body;
  final int? applicationId;
  final int? interviewId;

  /// Stable positive 31-bit id derived from [key] (FNV-1a), used to cancel or
  /// replace the matching local notification. `String.hashCode` is not stable
  /// across runs, so it cannot be used here.
  int get notificationId {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
