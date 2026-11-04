import '../enums/enums.dart';
import '../models/interview.dart';
import '../models/page.dart';

/// Interviews (`API.md` → Interviews).
abstract interface class InterviewRepository {
  /// `GET /interviews`; upcoming is ascending, past is descending.
  Future<Page<Interview>> list({
    InterviewScope? scope,
    int? applicationId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  });

  /// `GET /interviews/:id`.
  Future<Interview> getById(int id);

  /// `POST /applications/:id/interviews`. Throws an `INTERVIEW_CONFLICT`
  /// [ApiFailure] when the application already has one at the same time.
  Future<Interview> create(int applicationId, Interview interview);

  /// `PATCH /interviews/:id`.
  Future<Interview> update(Interview interview);

  /// `DELETE /interviews/:id`.
  Future<void> delete(int id);
}
