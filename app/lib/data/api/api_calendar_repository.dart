import 'package:dio/dio.dart';

import '../../core/utils/api_date.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/repositories/misc_repositories.dart';
import 'error_mapper.dart';

/// [CalendarRepository] over the REST API (`API.md` → Calendar).
class ApiCalendarRepository implements CalendarRepository {
  /// Creates the repository.
  ApiCalendarRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<CalendarEvent>> events({
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>(
        '/calendar',
        queryParameters: {
          'from': ApiDate.toDateOnly(from),
          'to': ApiDate.toDateOnly(to),
          'tz': timezone,
        },
      ),
    );
    return (res.data!['events'] as List)
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
