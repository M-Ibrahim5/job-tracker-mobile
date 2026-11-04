import '../../core/utils/api_date.dart';
import '../enums/enums.dart';

/// Default reminder offsets: 1 day and 1 hour before.
const List<Duration> kDefaultReminderOffsets = [
  Duration(days: 1),
  Duration(hours: 1),
];

/// A scheduled interview linked to a job application.
class Interview {
  /// Creates an immutable interview.
  const Interview({
    required this.id,
    required this.applicationId,
    required this.title,
    required this.type,
    required this.scheduledAt,
    this.applicationTitle,
    this.companyName,
    this.durationMinutes = 60,
    this.locationOrLink,
    this.interviewerName,
    this.notes,
    this.reminderOffsets = kDefaultReminderOffsets,
    this.outcome = InterviewOutcome.pending,
    this.createdAt,
    this.updatedAt,
  });

  /// Parses an API interview.
  factory Interview.fromJson(Map<String, dynamic> json) {
    return Interview(
      id: json['id'] as int,
      applicationId: json['applicationId'] as int,
      applicationTitle: json['applicationTitle'] as String?,
      companyName: json['companyName'] as String?,
      title: json['title'] as String,
      type: enumByName(InterviewType.values, json['type'] as String),
      scheduledAt: ApiDate.parseUtc(json['scheduledAt'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 60,
      locationOrLink: json['locationOrLink'] as String?,
      interviewerName: json['interviewerName'] as String?,
      notes: json['notes'] as String?,
      reminderOffsets: (json['reminderOffsetsMinutes'] as List? ?? const [])
          .map((m) => Duration(minutes: m as int))
          .toList(),
      outcome: enumByName(InterviewOutcome.values, json['outcome'] as String),
      createdAt: ApiDate.parseUtcOrNull(json['createdAt'] as String?),
      updatedAt: ApiDate.parseUtcOrNull(json['updatedAt'] as String?),
    );
  }

  final int id;
  final int applicationId;

  /// Denormalized from the application (read-only).
  final String? applicationTitle;
  final String? companyName;
  final String title;
  final InterviewType type;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? locationOrLink;
  final String? interviewerName;
  final String? notes;

  /// How long before [scheduledAt] each reminder fires.
  final List<Duration> reminderOffsets;
  final InterviewOutcome outcome;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Returns a copy with the given fields replaced.
  Interview copyWith({
    int? id,
    int? applicationId,
    String? applicationTitle,
    String? companyName,
    String? title,
    InterviewType? type,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? locationOrLink,
    String? interviewerName,
    String? notes,
    List<Duration>? reminderOffsets,
    InterviewOutcome? outcome,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Interview(
      id: id ?? this.id,
      applicationId: applicationId ?? this.applicationId,
      applicationTitle: applicationTitle ?? this.applicationTitle,
      companyName: companyName ?? this.companyName,
      title: title ?? this.title,
      type: type ?? this.type,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      locationOrLink: locationOrLink ?? this.locationOrLink,
      interviewerName: interviewerName ?? this.interviewerName,
      notes: notes ?? this.notes,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      outcome: outcome ?? this.outcome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Editable fields only, as sent to `POST`/`PATCH` interview endpoints.
  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type.name,
    'scheduledAt': ApiDate.toUtcIso(scheduledAt),
    'durationMinutes': durationMinutes,
    'locationOrLink': locationOrLink,
    'interviewerName': interviewerName,
    'notes': notes,
    'reminderOffsetsMinutes': reminderOffsets.map((d) => d.inMinutes).toList(),
    'outcome': outcome.name,
  };
}
