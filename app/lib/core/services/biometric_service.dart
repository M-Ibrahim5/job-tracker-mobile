import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Asks the device to verify the user's fingerprint / face.
abstract interface class BiometricAuthenticator {
  /// True when the device has a sensor with at least one enrolled biometric.
  Future<bool> isAvailable();

  /// Shows the system prompt with [reason]. Resolves to true only when the
  /// user was recognised; cancel, failure and "no sensor" all give false.
  Future<bool> authenticate(String reason);
}

/// [BiometricAuthenticator] backed by `local_auth`.
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  /// Creates the authenticator; pass [auth] to override the plugin in tests.
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Biometrics only: a device PIN is not a "fingerprint login".
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}

/// Where the fingerprint-login device token lives (platform keystore/keychain).
///
/// Only a revocable server-issued token is kept here, never the password.
abstract interface class DeviceTokenStore {
  /// The saved token, or null when fingerprint login is off.
  Future<String?> read();

  /// Id of the user the saved token was issued to, or null when none is
  /// saved or it was saved without an owner.
  Future<int?> readOwner();

  /// Saves [token] for [userId], turning fingerprint login on for that user.
  Future<void> save(String token, {required int userId});

  /// Forgets the token and its owner, turning fingerprint login off.
  Future<void> clear();
}

/// [DeviceTokenStore] backed by `flutter_secure_storage`.
class SecureDeviceTokenStore implements DeviceTokenStore {
  /// Creates the store; pass [storage] to override the plugin in tests.
  SecureDeviceTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'device_token';
  static const _ownerKey = 'device_token_owner';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<int?> readOwner() async =>
      int.tryParse(await _storage.read(key: _ownerKey) ?? '');

  @override
  Future<void> save(String token, {required int userId}) async {
    await _storage.write(key: _ownerKey, value: '$userId');
    await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _ownerKey);
  }
}

/// In-memory [DeviceTokenStore] for tests and the fake backend.
class MemoryDeviceTokenStore implements DeviceTokenStore {
  /// Creates a store, optionally pre-filled with [_token] owned by [_owner].
  MemoryDeviceTokenStore([this._token, this._owner]);

  String? _token;
  int? _owner;

  @override
  Future<String?> read() async => _token;

  @override
  Future<int?> readOwner() async => _owner;

  @override
  Future<void> save(String token, {required int userId}) async {
    _token = token;
    _owner = userId;
  }

  @override
  Future<void> clear() async {
    _token = null;
    _owner = null;
  }
}

/// Authenticator used with the fake backend: no sensor, so the feature is off.
class UnavailableBiometricAuthenticator implements BiometricAuthenticator {
  /// Creates the authenticator.
  const UnavailableBiometricAuthenticator();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
