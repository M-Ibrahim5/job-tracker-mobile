import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/account_strings.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/biometric_service.dart';
import 'auth_controller.dart';

/// Whether fingerprint login can be offered, and whether it is switched on.
class BiometricStatus {
  /// Creates a status.
  const BiometricStatus({required this.available, required this.enabled});

  /// The device has a sensor with an enrolled fingerprint / face.
  final bool available;

  /// A device token is saved, so the login screen shows the fingerprint button.
  final bool enabled;

  /// Show the "sign in with fingerprint" button.
  bool get canSignIn => available && enabled;
}

/// Current [BiometricStatus]; invalidated by [BiometricActions] on changes.
final biometricStatusProvider = FutureProvider.autoDispose<BiometricStatus>((
  ref,
) async {
  final available = await ref
      .watch(biometricAuthenticatorProvider)
      .isAvailable();
  final saved = await ref.watch(deviceTokenStoreProvider).read();
  return BiometricStatus(available: available, enabled: saved != null);
});

/// Turn fingerprint login on / off and sign in with it.
///
/// The phone keeps a revocable *device token* issued by the server; the
/// password is only typed once, to enrol, and is never stored.
class BiometricActions {
  /// Creates the actions bound to [_ref].
  BiometricActions(this._ref);

  final Ref _ref;

  BiometricAuthenticator get _sensor =>
      _ref.read(biometricAuthenticatorProvider);
  DeviceTokenStore get _store => _ref.read(deviceTokenStoreProvider);

  /// Turns the feature on. The fingerprint is checked first, then the server
  /// verifies [password] and issues the device token. Returns false when the
  /// user cancelled the fingerprint prompt. Throws the repository's [Failure]
  /// when the password is wrong or the call fails.
  Future<bool> enable({required String password}) async {
    if (!await _sensor.authenticate(AccountStrings.biometricEnableReason)) {
      return false;
    }
    final token = await _ref
        .read(authRepositoryProvider)
        .createDeviceToken(password: password);
    await _store.save(token);
    _ref.invalidate(biometricStatusProvider);
    return true;
  }

  /// Turns the feature off: the token is revoked on the server (best effort,
  /// e.g. offline) and always forgotten locally.
  Future<void> disable() async {
    final token = await _store.read();
    if (token != null) {
      try {
        await _ref.read(authRepositoryProvider).revokeDeviceToken(token);
      } on Failure {
        // The token also expires on its own; the local copy is what matters.
      }
    }
    await forget();
  }

  /// Forgets the local token without calling the server (account deleted or
  /// the server already rejected it).
  Future<void> forget() async {
    await _store.clear();
    _ref.invalidate(biometricStatusProvider);
  }

  /// Signs in after a successful fingerprint scan. Returns false when the scan
  /// was cancelled / failed or nothing is saved. If the server rejects the
  /// token (revoked, expired) it is forgotten and the failure is rethrown.
  Future<bool> signIn() async {
    final token = await _store.read();
    if (token == null) return false;
    if (!await _sensor.authenticate(AccountStrings.biometricSignInReason)) {
      return false;
    }
    try {
      await _ref
          .read(authControllerProvider.notifier)
          .signInWithDeviceToken(token);
    } on UnauthorizedFailure {
      await forget();
      rethrow;
    }
    return true;
  }

  /// A password change revokes every device token on the server; while the
  /// session is still valid, enrol this phone again with the new password.
  Future<void> passwordChanged(String newPassword) async {
    if (await _store.read() == null) return;
    try {
      final token = await _ref
          .read(authRepositoryProvider)
          .createDeviceToken(password: newPassword);
      await _store.save(token);
    } on Failure {
      await forget();
    }
  }
}

/// Provider for [BiometricActions].
final biometricActionsProvider = Provider<BiometricActions>(
  BiometricActions.new,
);
