import '../../core/utils/api_date.dart';
import '../enums/enums.dart';

/// A job the user applied for (`JobApplication` in `API.md`).
class JobApplication {
  /// Creates an immutable application.
  const JobApplication({
    required this.id,
    required this.jobTitle,
    required this.companyName,
    required this.location,
    required this.workArrangement,
    required this.appliedDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.jobDescription,
    this.applicationLink,
    this.employmentType,
    this.salaryRange,
    this.source,
    this.notes,
    this.contactName,
    this.contactEmail,
    this.followUpAt,
    this.nextInterviewAt,
  });

  /// Parses an API application.
  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: json['id'] as int,
      jobTitle: json['jobTitle'] as String,
      companyName: json['companyName'] as String,
      location: json['location'] as String,
      workArrangement: enumByName(
        WorkArrangement.values,
        json['workArrangement'] as String,
      ),
      jobDescription: json['jobDescription'] as String?,
      applicationLink: json['applicationLink'] as String?,
      employmentType: enumByNameOrNull(
        EmploymentType.values,
        json['employmentType'] as String?,
      ),
      salaryRange: json['salaryRange'] as String?,
      source: enumByNameOrNull(
        ApplicationSource.values,
        json['source'] as String?,
      ),
      appliedDate: ApiDate.parseDate(json['appliedDate'] as String),
      status: enumByName(ApplicationStatus.values, json['status'] as String),
      notes: json['notes'] as String?,
      contactName: json['contactName'] as String?,
      contactEmail: json['contactEmail'] as String?,
      followUpAt: ApiDate.parseUtcOrNull(json['followUpAt'] as String?),
      nextInterviewAt: ApiDate.parseUtcOrNull(
        json['nextInterviewAt'] as String?,
      ),
      createdAt: ApiDate.parseUtc(json['createdAt'] as String),
      updatedAt: ApiDate.parseUtc(json['updatedAt'] as String),
    );
  }

  /// Server id (0 for not-yet-saved drafts).
  final int id;
  final String jobTitle;
  final String companyName;
  final String location;
  final WorkArrangement workArrangement;

  /// Null in list responses; present in detail responses.
  final String? jobDescription;
  final String? applicationLink;
  final EmploymentType? employmentType;
  final String? salaryRange;
  final ApplicationSource? source;

  /// Calendar day (local midnight).
  final DateTime appliedDate;
  final ApplicationStatus status;
  final String? notes;
  final String? contactName;
  final String? contactEmail;
  final DateTime? followUpAt;

  /// Computed by the server: earliest future interview.
  final DateTime? nextInterviewAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced. Nullable fields can be
  /// cleared with the matching `clear*` flag.
  JobApplication copyWith({
    int? id,
    String? jobTitle,
    String? companyName,
    String? location,
    WorkArrangement? workArrangement,
    String? jobDescription,
    String? applicationLink,
    EmploymentType? employmentType,
    String? salaryRange,
    ApplicationSource? source,
    DateTime? appliedDate,
    ApplicationStatus? status,
    String? notes,
    String? contactName,
    String? contactEmail,
    DateTime? followUpAt,
    bool clearFollowUpAt = false,
    DateTime? nextInterviewAt,
    bool clearNextInterviewAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobApplication(
      id: id ?? this.id,
      jobTitle: jobTitle ?? this.jobTitle,
      companyName: companyName ?? this.companyName,
      location: location ?? this.location,
      workArrangement: workArrangement ?? this.workArrangement,
      jobDescription: jobDescription ?? this.jobDescription,
      applicationLink: applicationLink ?? this.applicationLink,
      employmentType: employmentType ?? this.employmentType,
      salaryRange: salaryRange ?? this.salaryRange,
      source: source ?? this.source,
      appliedDate: appliedDate ?? this.appliedDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      followUpAt: clearFollowUpAt ? null : (followUpAt ?? this.followUpAt),
      nextInterviewAt: clearNextInterviewAt
          ? null
          : (nextInterviewAt ?? this.nextInterviewAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Editable fields only, as sent to `POST`/`PATCH /applications`. Status,
  /// computed fields, id and timestamps are left out; nulls clear a value.
  Map<String, dynamic> toJson() => {
    'jobTitle': jobTitle,
    'companyName': companyName,
    'location': location,
    'workArrangement': workArrangement.name,
    'jobDescription': jobDescription,
    'applicationLink': applicationLink,
    'employmentType': employmentType?.name,
    'salaryRange': salaryRange,
    'source': source?.name,
    'appliedDate': ApiDate.toDateOnly(appliedDate),
    'notes': notes,
    'contactName': contactName,
    'contactEmail': contactEmail,
    'followUpAt': followUpAt == null ? null : ApiDate.toUtcIso(followUpAt!),
  };
}
