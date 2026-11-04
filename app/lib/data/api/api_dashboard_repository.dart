import 'package:dio/dio.dart';

import '../../domain/models/dashboard_data.dart';
import '../../domain/repositories/misc_repositories.dart';
import 'error_mapper.dart';

/// [DashboardRepository] over the REST API (`API.md` → Dashboard).
class ApiDashboardRepository implements DashboardRepository {
  /// Creates the repository.
  ApiDashboardRepository(this._dio);

  final Dio _dio;

  @override
  Future<DashboardData> load({required String timezone}) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>(
        '/dashboard',
        queryParameters: {'tz': timezone},
      ),
    );
    return DashboardData.fromJson(res.data!);
  }
}
