import '../../core/utils/api_date.dart';
import '../enums/enums.dart';

/// One marker on the calendar (`events[]` in `GET /calendar`).
class CalendarEvent {
  /// Creates an event.
  const CalendarEvent({
    required this.date,
    required this.type,
    required this.applicationId,
    required this.companyName,
    required this.title,
    this.interviewId,
    this.status,
    this.interviewType,
    this.at,
  });

  /// Parses an API event.
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      date: ApiDate.parseDate(json['date'] as String),
      type: enumByName(CalendarEventType.values, json['type'] as String),
      applicationId: json['applicationId'] as int,
      interviewId: json['interviewId'] as int?,
      companyName: json['companyName'] as String,
      title: json['title'] as String,
      status: enumByNameOrNull(
        ApplicationStatus.values,
        json['status'] as String?,
      ),
      interviewType: enumByNameOrNull(
        InterviewType.values,
        json['interviewType'] as String?,
      ),
      at: ApiDate.parseUtcOrNull(json['at'] as String?),
    );
  }

  /// Local calendar day, computed server-side in the user's timezone.
  final DateTime date;
  final CalendarEventType type;
  final int applicationId;
  final int? interviewId;
  final String companyName;
  final String title;
  final ApplicationStatus? status;
  final InterviewType? interviewType;
  final DateTime? at;
}
