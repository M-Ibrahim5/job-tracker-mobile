import 'package:dio/dio.dart';

import '../../core/errors/failures.dart';

/// Extracts `error.code` from an API error body, if present.
String? apiErrorCode(Object? data) {
  final error = data is Map ? data['error'] : null;
  final code = error is Map ? error['code'] : null;
  return code is String ? code : null;
}

/// Converts a [DioException] into a typed [Failure].
Failure mapDioException(DioException e) {
  final existing = e.error;
  if (existing is Failure) return existing;

  final response = e.response;
  if (response == null) {
    return switch (e.type) {
      DioExceptionType.cancel => const NetworkFailure('Request cancelled'),
      _ => const NetworkFailure(),
    };
  }

  final data = response.data;
  final error = data is Map ? data['error'] : null;
  final code = apiErrorCode(data);
  final status = response.statusCode;

  if (status == 401 &&
      (code == ApiCodes.tokenExpired ||
          code == ApiCodes.unauthorized ||
          code == null)) {
    return const UnauthorizedFailure();
  }

  final fields = <String, String>{};
  if (error is Map && error['fields'] is Map) {
    (error['fields'] as Map).forEach((k, v) => fields['$k'] = '$v');
  }
  return ApiFailure(
    code:
        code ??
        (status != null && status >= 500 ? ApiCodes.internal : 'UNKNOWN'),
    message: error is Map && error['message'] is String
        ? error['message'] as String
        : 'Request failed ($status)',
    fields: fields,
    statusCode: status,
  );
}

/// Runs [call] and rethrows any [DioException] as a [Failure].
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw mapDioException(e);
  }
}
