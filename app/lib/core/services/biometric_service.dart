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

  /// Saves [token], turning fingerprint login on.
  Future<void> save(String token);

  /// Forgets the token, turning fingerprint login off.
  Future<void> clear();
}

/// [DeviceTokenStore] backed by `flutter_secure_storage`.
class SecureDeviceTokenStore implements DeviceTokenStore {
  /// Creates the store; pass [storage] to override the plugin in tests.
  SecureDeviceTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'device_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> save(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// In-memory [DeviceTokenStore] for tests and the fake backend.
class MemoryDeviceTokenStore implements DeviceTokenStore {
  /// Creates a store, optionally pre-filled with [_token].
  MemoryDeviceTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
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
