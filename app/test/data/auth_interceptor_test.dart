import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/data/api/api_client.dart';
import 'package:jobtrail/data/api/auth_interceptor.dart';
import 'package:jobtrail/data/api/error_mapper.dart';
import 'package:jobtrail/data/api/token_storage.dart';
import 'package:jobtrail/domain/models/auth_models.dart';
import 'package:logger/logger.dart';

import '../helpers/test_app.dart';

const _expired =
    '{"error":{"code":"TOKEN_EXPIRED","message":"Access token expired"}}';
const _unauthorized =
    '{"error":{"code":"UNAUTHORIZED","message":"Invalid token"}}';
const _newTokens = '{"accessToken":"new","refreshToken":"r2"}';

Future<Failure?> _failureOf(Future<Object?> Function() call) async {
  try {
    await guardApi(call);
    return null;
  } on Failure catch (e) {
    return e;
  }
}

void main() {
  late MemoryTokenStorage tokens;
  late int signedOut;

  setUp(() {
    tokens = MemoryTokenStorage(
      const AuthTokens(accessToken: 'old', refreshToken: 'r1'),
    );
    signedOut = 0;
  });

  Dio build(ScriptedAdapter adapter) {
    final dio = createApiDio(
      tokens: tokens,
      logger: Logger(level: Level.off),
      baseUrl: 'http://test/api/v1',
      onSignedOut: () async => signedOut++,
    );
    dio.httpClientAdapter = adapter;
    return dio;
  }

  String? bearer(RequestOptions o) => o.headers['Authorization'] as String?;

  test('attaches the bearer token except on public paths', () async {
    final adapter = ScriptedAdapter((_) async => jsonBody('{}', 200));
    final dio = build(adapter);

    await dio.get<dynamic>('/me');
    await dio.post<dynamic>('/auth/login', data: {});

    expect(bearer(adapter.requests[0]), 'Bearer old');
    expect(bearer(adapter.requests[1]), isNull);
  });

  test('refreshes once on TOKEN_EXPIRED and retries the request', () async {
    final adapter = ScriptedAdapter((o) async {
      if (o.path == '/auth/refresh') return jsonBody(_newTokens, 200);
      return bearer(o) == 'Bearer new'
          ? jsonBody('{"ok":true}', 200)
          : jsonBody(_expired, 401);
    });
    final dio = build(adapter);

    final res = await dio.get<Map<String, dynamic>>('/me');

    expect(res.data, {'ok': true});
    expect(adapter.requests.map((r) => r.path), [
      '/me',
      '/auth/refresh',
      '/me',
    ]);
    expect((await tokens.read())!.refreshToken, 'r2');
    expect(signedOut, 0);
  });

  test('concurrent expirations share a single refresh call', () async {
    final refreshGate = Completer<void>();
    final adapter = ScriptedAdapter((o) async {
      if (o.path == '/auth/refresh') {
        await refreshGate.future;
        return jsonBody(_newTokens, 200);
      }
      return bearer(o) == 'Bearer new'
          ? jsonBody('{}', 200)
          : jsonBody(_expired, 401);
    });
    final dio = build(adapter);

    final calls = Future.wait([
      dio.get<dynamic>('/applications'),
      dio.get<dynamic>('/notifications'),
      dio.get<dynamic>('/me/settings'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    refreshGate.complete();
    final results = await calls;

    expect(results.map((r) => r.statusCode), [200, 200, 200]);
    expect(
      adapter.requests.where((r) => r.path == '/auth/refresh'),
      hasLength(1),
    );
  });

  test('signs out when the refresh token is rejected', () async {
    final adapter = ScriptedAdapter((o) async {
      return o.path == '/auth/refresh'
          ? jsonBody(_unauthorized, 401)
          : jsonBody(_expired, 401);
    });
    final dio = build(adapter);

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));

    expect(await tokens.read(), isNull);
    expect(signedOut, 1);
  });

  test('keeps the session when the refresh cannot reach the server', () async {
    final adapter = ScriptedAdapter((o) async {
      if (o.path == '/auth/refresh') {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        );
      }
      return jsonBody(_expired, 401);
    });
    final dio = build(adapter);

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));

    expect(await tokens.read(), isNotNull);
    expect(signedOut, 0);
  });

  for (final status in [429, 408, 503]) {
    test('keeps the session when the refresh answers $status', () async {
      final adapter = ScriptedAdapter((o) async {
        if (o.path == '/auth/refresh') {
          return jsonBody(
            '{"error":{"code":"RATE_LIMITED","message":"Too many requests"}}',
            status,
          );
        }
        return jsonBody(_expired, 401);
      });
      final dio = build(adapter);

      await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));

      expect(await tokens.read(), isNotNull, reason: 'session kept');
      expect(signedOut, 0);
    });
  }

  test('only real rejections count as an invalid refresh token', () {
    expect(AuthInterceptor.isRefreshRejection(401), isTrue);
    expect(AuthInterceptor.isRefreshRejection(400), isTrue);
    expect(AuthInterceptor.isRefreshRejection(429), isFalse);
    expect(AuthInterceptor.isRefreshRejection(408), isFalse);
    expect(AuthInterceptor.isRefreshRejection(503), isFalse);
    expect(AuthInterceptor.isRefreshRejection(null), isFalse);
  });

  test('does not loop when the retried request is rejected again', () async {
    final adapter = ScriptedAdapter((o) async {
      if (o.path == '/auth/refresh') return jsonBody(_newTokens, 200);
      return jsonBody(_expired, 401);
    });
    final dio = build(adapter);

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));

    expect(
      adapter.requests.where((r) => r.path == '/auth/refresh'),
      hasLength(1),
    );
    expect(signedOut, 1);
  });

  group('error mapping', () {
    late Dio dio;

    setUp(() {
      dio = build(
        ScriptedAdapter((o) async {
          return switch (o.path) {
            '/v' => jsonBody(
              '{"error":{"code":"VALIDATION_ERROR","message":"Bad",'
              '"fields":{"jobTitle":"This field is required"}}}',
              422,
            ),
            '/c' => jsonBody(
              '{"error":{"code":"INVALID_CREDENTIALS","message":"No"}}',
              401,
            ),
            _ => throw DioException(
              requestOptions: o,
              type: DioExceptionType.connectionTimeout,
            ),
          };
        }),
      );
    });

    test('keeps code and field errors of API failures', () async {
      final failure = await _failureOf(() => dio.get<dynamic>('/v'));
      expect(failure, isA<ApiFailure>());
      expect((failure! as ApiFailure).code, ApiCodes.validation);
      expect((failure as ApiFailure).fields['jobTitle'], isNotNull);
    });

    test('maps INVALID_CREDENTIALS without treating it as expiry', () async {
      final failure = await _failureOf(() => dio.get<dynamic>('/c'));
      expect((failure! as ApiFailure).code, ApiCodes.invalidCredentials);
    });

    test('maps transport errors to NetworkFailure', () async {
      final failure = await _failureOf(() => dio.get<dynamic>('/n'));
      expect(failure, isA<NetworkFailure>());
    });
  });
}
