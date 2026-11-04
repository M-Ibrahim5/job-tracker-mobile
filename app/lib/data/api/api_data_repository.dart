import 'package:dio/dio.dart';

import '../../domain/enums/enums.dart';
import '../../domain/repositories/misc_repositories.dart';
import 'error_mapper.dart';

/// [DataRepository] over the REST API.
class ApiDataRepository implements DataRepository {
  /// Creates the repository.
  ApiDataRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<int>> export(
    ExportFormat format, {
    String timezone = 'UTC',
  }) async {
    final res = await guardApi(
      () => _dio.get<List<int>>(
        '/export',
        queryParameters: {'format': format.name},
        options: Options(
          responseType: ResponseType.bytes,
          // Timestamps in the CSV are printed in the user's own time zone.
          headers: {'X-Timezone': timezone},
        ),
      ),
    );
    return res.data ?? const [];
  }

  @override
  Future<void> deleteAllData() {
    return guardApi(
      () => _dio.delete<void>('/data', data: {'confirm': 'DELETE'}),
    );
  }
}
