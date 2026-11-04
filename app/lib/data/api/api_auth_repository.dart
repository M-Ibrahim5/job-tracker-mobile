import 'package:dio/dio.dart';

import '../../core/errors/failures.dart';
import '../../domain/models/auth_models.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_interceptor.dart';
import 'error_mapper.dart';
import 'token_storage.dart';

/// [AuthRepository] over the REST API.
class ApiAuthRepository implements AuthRepository {
  /// Creates the repository.
  ApiAuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  Future<User?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      final res = await guardApi(() => _dio.get<Map<String, dynamic>>('/me'));
      return User.fromJson(res.data!);
    } on UnauthorizedFailure {
      await _tokens.clear();
      return null;
    }
  }

  @override
  Future<User> signIn({required String email, required String password}) {
    return _authenticate('/auth/login', {'email': email, 'password': password});
  }

  @override
  Future<User> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _authenticate('/auth/register', {
      'fullName': fullName,
      'email': email,
      'password': password,
    });
  }

  Future<User> _authenticate(String path, Map<String, dynamic> body) async {
    final res = await guardApi(
      () => _dio.post<Map<String, dynamic>>(path, data: body),
    );
    final auth = AuthResponse.fromJson(res.data!);
    await _tokens.save(auth.tokens);
    return auth.user;
  }

  @override
  Future<String> createDeviceToken({required String password}) async {
    final res = await guardApi(
      () => _dio.post<Map<String, dynamic>>(
        '/auth/device-token',
        data: {'password': password},
      ),
    );
    return res.data!['deviceToken'] as String;
  }

  @override
  Future<User> deviceSignIn(String deviceToken) {
    return _authenticate('/auth/device-login', {'deviceToken': deviceToken});
  }

  @override
  Future<void> revokeDeviceToken(String deviceToken) {
    return guardApi(
      () => _dio.delete<void>(
        '/auth/device-token',
        data: {'deviceToken': deviceToken},
      ),
    );
  }

  @override
  Future<void> signOut() async {
    final stored = await _tokens.read();
    try {
      if (stored != null) {
        await guardApi(
          () => _dio.post<void>(
            '/auth/logout',
            data: {'refreshToken': stored.refreshToken},
            options: Options(extra: {kSkipAuth: true}),
          ),
        );
      }
    } on Failure {
      // Revocation is best effort; local credentials are cleared regardless.
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<void> forgotPassword(String email) {
    return guardApi(
      () => _dio.post<void>('/auth/forgot-password', data: {'email': email}),
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final stored = await _tokens.read();
    await guardApi(
      () => _dio.post<void>(
        '/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'refreshToken': ?stored?.refreshToken,
        },
      ),
    );
  }
}
