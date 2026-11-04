import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/errors/failures.dart';
import '../../domain/models/auth_models.dart';
import 'error_mapper.dart';
import 'token_storage.dart';

/// Extra flag: send the request without a bearer token and never refresh.
const kSkipAuth = 'skipAuth';

const _retriedKey = 'authRetried';

/// Paths that never carry a bearer token (`API.md` → conventions).
const _publicPaths = {
  '/auth/register',
  '/auth/login',
  '/auth/refresh',
  '/auth/device-login',
  '/auth/forgot-password',
  '/health',
};

/// Attaches the access token and transparently refreshes it once on a
/// `TOKEN_EXPIRED` 401. Concurrent expirations share a single refresh call.
class AuthInterceptor extends Interceptor {
  /// Creates the interceptor. [onSignedOut] runs after the stored session was
  /// found invalid and has been cleared.
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokens,
    required Future<void> Function() onSignedOut,
  }) : _dio = dio,
       _tokens = tokens,
       _onSignedOut = onSignedOut;

  final Dio _dio;
  final TokenStorage _tokens;
  final Future<void> Function() _onSignedOut;
  Future<AuthTokens?>? _inflight;

  static bool _isPublic(RequestOptions o) =>
      o.extra[kSkipAuth] == true || _publicPaths.contains(o.path);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options)) {
      final stored = await _tokens.read();
      if (stored != null) {
        options.headers['Authorization'] = 'Bearer ${stored.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || _isPublic(request)) {
      return handler.next(err);
    }

    final code = apiErrorCode(err.response?.data);
    if (code != ApiCodes.tokenExpired || request.extra[_retriedKey] == true) {
      await _expireSession();
      return handler.next(err);
    }

    AuthTokens? fresh;
    try {
      final stored = await _tokens.read();
      final sentWith = request.headers['Authorization'];
      // Another request may already have refreshed while this one was in
      // flight; reuse the new token instead of rotating again.
      if (stored != null && sentWith != 'Bearer ${stored.accessToken}') {
        fresh = stored;
      } else {
        fresh = await _refresh();
      }
    } on DioException {
      // Could not reach the server: keep the session, surface the 401.
      return handler.next(err);
    }

    if (fresh == null) {
      await _expireSession();
      return handler.next(err);
    }

    request.headers['Authorization'] = 'Bearer ${fresh.accessToken}';
    request.extra[_retriedKey] = true;
    final body = request.data;
    if (body is FormData) request.data = body.clone();
    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<AuthTokens?> _refresh() {
    return _inflight ??= _doRefresh().whenComplete(() => _inflight = null);
  }

  /// Returns new tokens, null when the refresh token was rejected, and throws
  /// a [DioException] when the server is unreachable, busy or rate limiting
  /// (`408`/`429`/`5xx`): those are temporary and must not end the session.
  Future<AuthTokens?> _doRefresh() async {
    final stored = await _tokens.read();
    if (stored == null) return null;
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': stored.refreshToken},
      );
      final tokens = AuthTokens.fromJson(res.data!);
      await _tokens.save(tokens);
      return tokens;
    } on DioException catch (e) {
      if (isRefreshRejection(e.response?.statusCode)) return null;
      rethrow;
    }
  }

  /// Whether a refresh answered with [status] means the refresh token is no
  /// longer valid. Rate limiting (429) and timeouts (408) are 4xx too, but
  /// only say "try again later".
  @visibleForTesting
  static bool isRefreshRejection(int? status) =>
      status != null &&
      status >= 400 &&
      status < 500 &&
      status != 408 &&
      status != 429;

  Future<void> _expireSession() async {
    await _tokens.clear();
    await _onSignedOut();
  }
}
