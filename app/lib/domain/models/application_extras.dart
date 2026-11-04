import 'interview.dart';
import 'job_application.dart';
import 'status_history_entry.dart';

/// Response of `POST /applications/:id/status`.
class StatusChangeResult {
  /// Creates a result.
  const StatusChangeResult({required this.application, this.history});

  /// Parses the API response; `history` may be absent for a no-op change.
  factory StatusChangeResult.fromJson(Map<String, dynamic> json) {
    final h = json['history'];
    return StatusChangeResult(
      application: JobApplication.fromJson(
        json['application'] as Map<String, dynamic>,
      ),
      history: h == null
          ? null
          : StatusHistoryEntry.fromJson(h as Map<String, dynamic>),
    );
  }

  final JobApplication application;

  /// Null when the status was unchanged.
  final StatusHistoryEntry? history;
}

/// Response of `GET /applications/:id/timeline`.
class ApplicationTimeline {
  /// Creates a timeline.
  const ApplicationTimeline({required this.history, required this.interviews});

  /// Parses the API response.
  factory ApplicationTimeline.fromJson(Map<String, dynamic> json) {
    return ApplicationTimeline(
      history: (json['history'] as List)
          .map((e) => StatusHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      interviews: (json['interviews'] as List)
          .map((e) => Interview.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<StatusHistoryEntry> history;
  final List<Interview> interviews;
}
