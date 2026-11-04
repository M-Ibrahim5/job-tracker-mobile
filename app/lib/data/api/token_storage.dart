import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_models.dart';

/// Persistence for the access/refresh token pair.
abstract interface class TokenStorage {
  /// The stored tokens, or null when signed out.
  Future<AuthTokens?> read();

  /// Replaces the stored tokens.
  Future<void> save(AuthTokens tokens);

  /// Removes any stored tokens.
  Future<void> clear();
}

/// [TokenStorage] backed by the platform keychain / keystore.
class SecureTokenStorage implements TokenStorage {
  /// Creates storage; pass [storage] to override the plugin in tests.
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// In-memory [TokenStorage] for tests and the fake backend.
class MemoryTokenStorage implements TokenStorage {
  /// Creates storage, optionally pre-filled with [tokens].
  MemoryTokenStorage([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> save(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
