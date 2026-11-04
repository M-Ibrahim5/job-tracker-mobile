import 'package:dio/dio.dart';

import '../../domain/enums/enums.dart';
import '../../domain/models/application_extras.dart';
import '../../domain/models/application_filter.dart';
import '../../domain/models/job_application.dart';
import '../../domain/models/page.dart';
import '../../domain/models/status_history_entry.dart';
import '../../domain/repositories/job_application_repository.dart';
import 'error_mapper.dart';

/// [JobApplicationRepository] over the REST API (`API.md` → Applications).
class ApiJobApplicationRepository implements JobApplicationRepository {
  /// Creates the repository.
  ApiJobApplicationRepository(this._dio);

  final Dio _dio;

  @override
  Future<Page<JobApplication>> list(
    ApplicationFilter filter, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>(
        '/applications',
        queryParameters: {
          ...filter.toQuery(),
          'page': page,
          'pageSize': pageSize,
        },
      ),
    );
    return Page.fromJson(res.data!, JobApplication.fromJson);
  }

  @override
  Future<JobApplication> getById(int id) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/applications/$id'),
    );
    return JobApplication.fromJson(res.data!);
  }

  @override
  Future<JobApplication> create(JobApplication application) async {
    final res = await guardApi(
      () => _dio.post<Map<String, dynamic>>(
        '/applications',
        data: application.toJson(),
      ),
    );
    return JobApplication.fromJson(res.data!);
  }

  @override
  Future<JobApplication> update(JobApplication application) async {
    final res = await guardApi(
      () => _dio.patch<Map<String, dynamic>>(
        '/applications/${application.id}',
        data: application.toJson(),
      ),
    );
    return JobApplication.fromJson(res.data!);
  }

  @override
  Future<void> delete(int id) =>
      guardApi(() => _dio.delete<void>('/applications/$id'));

  @override
  Future<StatusChangeResult> changeStatus(
    int id,
    ApplicationStatus status, {
    String? note,
  }) async {
    final res = await guardApi(
      () => _dio.post<Map<String, dynamic>>(
        '/applications/$id/status',
        data: {'status': status.name, 'note': ?note},
      ),
    );
    return StatusChangeResult.fromJson(res.data!);
  }

  @override
  Future<List<StatusHistoryEntry>> history(int id) async {
    final res = await guardApi(
      () => _dio.get<List<dynamic>>('/applications/$id/history'),
    );
    return res.data!
        .map((e) => StatusHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ApplicationTimeline> timeline(int id) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/applications/$id/timeline'),
    );
    return ApplicationTimeline.fromJson(res.data!);
  }
}
