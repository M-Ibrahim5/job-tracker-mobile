import '../enums/enums.dart';
import '../models/application_extras.dart';
import '../models/application_filter.dart';
import '../models/job_application.dart';
import '../models/page.dart';
import '../models/status_history_entry.dart';

/// Applications and their status history (`API.md` → Applications).
abstract interface class JobApplicationRepository {
  /// `GET /applications`.
  Future<Page<JobApplication>> list(
    ApplicationFilter filter, {
    int page = 1,
    int pageSize = 20,
  });

  /// `GET /applications/:id` (includes the job description).
  Future<JobApplication> getById(int id);

  /// `POST /applications`; [application]'s id, status and timestamps are
  /// ignored (the server starts it as `applied`).
  Future<JobApplication> create(JobApplication application);

  /// `PATCH /applications/:id` with every editable field; status is ignored.
  Future<JobApplication> update(JobApplication application);

  /// `DELETE /applications/:id`. Undo is client-side: callers delay this call
  /// until the Undo snackbar closes.
  Future<void> delete(int id);

  /// `POST /applications/:id/status`.
  Future<StatusChangeResult> changeStatus(
    int id,
    ApplicationStatus status, {
    String? note,
  });

  /// `GET /applications/:id/history`, oldest first.
  Future<List<StatusHistoryEntry>> history(int id);

  /// `GET /applications/:id/timeline`.
  Future<ApplicationTimeline> timeline(int id);
}
