import '../models/user.dart';

/// Authentication and session lifecycle (`API.md` → Auth).
abstract interface class AuthRepository {
  /// Returns the user of the stored session, or null when there is none or it
  /// can no longer be refreshed. Network errors are rethrown.
  Future<User?> restoreSession();

  /// `POST /auth/login`; stores the tokens.
  Future<User> signIn({required String email, required String password});

  /// `POST /auth/register`; stores the tokens.
  Future<User> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  /// `POST /auth/device-token`: enrols this phone for fingerprint login after
  /// confirming [password]. Returns the device token to keep in secure storage.
  Future<String> createDeviceToken({required String password});

  /// `POST /auth/device-login`; stores the tokens.
  Future<User> deviceSignIn(String deviceToken);

  /// `DELETE /auth/device-token` (best effort for the caller).
  Future<void> revokeDeviceToken(String deviceToken);

  /// Revokes the refresh token (best effort) and clears local credentials.
  Future<void> signOut();

  /// `POST /auth/forgot-password`.
  Future<void> forgotPassword(String email);

  /// `POST /auth/change-password`; keeps the current session signed in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
