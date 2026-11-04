import '../../core/utils/api_date.dart';
import '../enums/enums.dart';

/// One recorded status transition of an application.
class StatusHistoryEntry {
  /// Creates an immutable history entry.
  const StatusHistoryEntry({
    required this.id,
    required this.applicationId,
    required this.toStatus,
    required this.changedAt,
    this.fromStatus,
    this.note,
  });

  /// Parses an API history entry.
  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StatusHistoryEntry(
      id: json['id'] as int,
      applicationId: json['applicationId'] as int,
      fromStatus: enumByNameOrNull(
        ApplicationStatus.values,
        json['fromStatus'] as String?,
      ),
      toStatus: enumByName(
        ApplicationStatus.values,
        json['toStatus'] as String,
      ),
      changedAt: ApiDate.parseUtc(json['changedAt'] as String),
      note: json['note'] as String?,
    );
  }

  final int id;
  final int applicationId;

  /// Null for the initial entry created together with the application.
  final ApplicationStatus? fromStatus;
  final ApplicationStatus toStatus;
  final DateTime changedAt;
  final String? note;

  /// JSON mirror of the API representation.
  Map<String, dynamic> toJson() => {
    'id': id,
    'applicationId': applicationId,
    'fromStatus': fromStatus?.name,
    'toStatus': toStatus.name,
    'changedAt': ApiDate.toUtcIso(changedAt),
    'note': note,
  };
}
