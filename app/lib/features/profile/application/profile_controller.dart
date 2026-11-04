import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/biometric_controller.dart';

/// Profile edits. State is the result of the latest action; the signed-in user
/// held by [authControllerProvider] is updated on success.
class ProfileController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Sends only the provided (changed) fields. A non-null [avatarPath] is
  /// uploaded first; the photo is only ever sent from here, i.e. on Save.
  Future<void> save({
    String? avatarPath,
    String? fullName,
    String? phone,
    String? currentRole,
    String? lookingFor,
    String? location,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(profileRepositoryProvider);
      final auth = ref.read(authControllerProvider.notifier);
      if (avatarPath != null) {
        auth.updateUser(await repo.uploadAvatar(avatarPath));
      }
      final hasFields = [
        fullName,
        phone,
        currentRole,
        lookingFor,
        location,
      ].any((v) => v != null);
      if (hasFields) {
        auth.updateUser(
          await repo.updateMe(
            fullName: fullName,
            phone: phone,
            currentRole: currentRole,
            lookingFor: lookingFor,
            location: location,
          ),
        );
      }
    });
  }

  /// Deletes the account, then signs out locally.
  Future<void> deleteAccount(String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .deleteAccount(password: password);
      await ref.read(biometricActionsProvider).forget();
      await ref.read(authControllerProvider.notifier).signOut();
    });
  }
}

/// Provider for [ProfileController].
final profileControllerProvider =
    AutoDisposeAsyncNotifierProvider<ProfileController, void>(
      ProfileController.new,
    );
