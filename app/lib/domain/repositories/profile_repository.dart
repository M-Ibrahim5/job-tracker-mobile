import '../models/settings.dart';
import '../models/user.dart';

/// Profile and settings (`API.md` → Me / profile / settings).
abstract interface class ProfileRepository {
  /// `GET /me`.
  Future<User> getMe();

  /// `PATCH /me`. Only the non-null arguments are sent.
  Future<User> updateMe({
    String? fullName,
    String? phone,
    String? currentRole,
    String? lookingFor,
    String? location,
  });

  /// `POST /me/avatar` with the image at [filePath] (jpeg/png, ≤ 2 MB).
  Future<User> uploadAvatar(String filePath);

  /// `DELETE /me`.
  Future<void> deleteAccount({required String password});

  /// `GET /me/settings`.
  Future<Settings> getSettings();

  /// `PATCH /me/settings` with the full [settings] value.
  Future<Settings> updateSettings(Settings settings);
}
