import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../core/config/app_config.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';

/// Logs method, path, status and duration only: never headers or bodies, so
/// tokens and passwords cannot leak into logs.
class SafeLoggingInterceptor extends Interceptor {
  /// Creates the interceptor.
  SafeLoggingInterceptor(this._logger);

  final Logger _logger;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final o = response.requestOptions;
    _logger.d('${o.method} ${o.path} → ${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    _logger.w(
      '${o.method} ${o.path} ✗ ${err.response?.statusCode ?? err.type.name}',
    );
    handler.next(err);
  }
}

/// Adds `X-Timezone` (the device's IANA zone) so the server prints times in
/// notification text in the user's own zone instead of UTC. A header set on the
/// request itself wins.
class TimezoneInterceptor extends Interceptor {
  /// Creates the interceptor.
  TimezoneInterceptor(this._read);

  final Future<String> Function() _read;
  String? _cached;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!options.headers.containsKey('X-Timezone')) {
      try {
        options.headers['X-Timezone'] = _cached ??= await _read();
      } catch (_) {
        // Unknown zone: the server falls back to UTC.
      }
    }
    handler.next(options);
  }
}

/// Builds the app's Dio client.
Dio createApiDio({
  required TokenStorage tokens,
  required Logger logger,
  required Future<void> Function() onSignedOut,
  Future<String> Function()? timezone,
  String? baseUrl,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    ),
  );
  if (timezone != null) dio.interceptors.add(TimezoneInterceptor(timezone));
  dio.interceptors
    ..add(AuthInterceptor(dio: dio, tokens: tokens, onSignedOut: onSignedOut))
    ..add(SafeLoggingInterceptor(logger));
  return dio;
}
