import 'package:dio/dio.dart';

import '../../core/constants/account_strings.dart';
import '../../core/errors/failures.dart';
import '../../core/services/avatar_image.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/profile_repository.dart';
import 'error_mapper.dart';

/// [ProfileRepository] over the REST API.
class ApiProfileRepository implements ProfileRepository {
  /// Creates the repository.
  ApiProfileRepository(this._dio);

  final Dio _dio;

  @override
  Future<User> getMe() async {
    final res = await guardApi(() => _dio.get<Map<String, dynamic>>('/me'));
    return User.fromJson(res.data!);
  }

  @override
  Future<User> updateMe({
    String? fullName,
    String? phone,
    String? currentRole,
    String? lookingFor,
    String? location,
  }) async {
    final res = await guardApi(
      () => _dio.patch<Map<String, dynamic>>(
        '/me',
        data: {
          'fullName': ?fullName,
          'phone': ?phone,
          'currentRole': ?currentRole,
          'lookingFor': ?lookingFor,
          'location': ?location,
        },
      ),
    );
    return User.fromJson(res.data!);
  }

  @override
  Future<User> uploadAvatar(String filePath) async {
    final AvatarImage image;
    try {
      image = await prepareAvatarImage(filePath);
    } on FormatException {
      throw const ApiFailure(
        code: ApiCodes.validation,
        message: AccountStrings.photoUnsupported,
      );
    }
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        image.bytes,
        filename: image.fileName,
        contentType: DioMediaType('image', image.subtype),
      ),
    });
    final res = await guardApi(
      () => _dio.post<Map<String, dynamic>>('/me/avatar', data: form),
    );
    return User.fromJson(res.data!);
  }

  @override
  Future<void> deleteAccount({required String password}) {
    return guardApi(
      () => _dio.delete<void>('/me', data: {'password': password}),
    );
  }

  @override
  Future<Settings> getSettings() async {
    final res = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/me/settings'),
    );
    return Settings.fromJson(res.data!);
  }

  @override
  Future<Settings> updateSettings(Settings settings) async {
    final res = await guardApi(
      () => _dio.patch<Map<String, dynamic>>(
        '/me/settings',
        data: settings.toJson(),
      ),
    );
    return Settings.fromJson(res.data!);
  }
}
