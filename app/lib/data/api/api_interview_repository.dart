import 'package:dio/dio.dart';

import '../../core/utils/api_date.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/interview.dart';
import '../../domain/models/page.dart';
import '../../domain/repositories/interview_repository.dart';
import 'error_mapper.dart';

/// [InterviewRepository] over the REST API (`API.md` → Interviews).
class ApiInterviewRepository implements InterviewRepository {
  /// Creates the repository.
  ApiInterviewRepository(this._dio);

  final Dio _dio;

  @override
  Future<Page<Interview>> list({
    InterviewScope? scope,
    int? applicationId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>(
        '/interviews',
        queryParameters: {
          'scope': ?scope?.name,
          'applicationId': ?applicationId,
          if (from != null) 'from': ApiDate.toUtcIso(from),
          if (to != null) 'to': ApiDate.toUtcIso(to),
          'page': page,
          'pageSize': pageSize,
        },
      ),
    );
    return Page.fromJson(res.data!, Interview.fromJson);
  }

  @override
  Future<Interview> getById(int id) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/interviews/$id'),
    );
    return Interview.fromJson(res.data!);
  }

  @override
  Future<Interview> create(int applicationId, Interview interview) async {
    final res = await guardApi(
      () => _dio.post<Map<String, dynamic>>(
        '/applications/$applicationId/interviews',
        data: interview.toJson(),
      ),
    );
    return Interview.fromJson(res.data!);
  }

  @override
  Future<Interview> update(Interview interview) async {
    final res = await guardApi(
      () => _dio.patch<Map<String, dynamic>>(
        '/interviews/${interview.id}',
        data: interview.toJson(),
      ),
    );
    return Interview.fromJson(res.data!);
  }

  @override
  Future<void> delete(int id) =>
      guardApi(() => _dio.delete<void>('/interviews/$id'));
}
