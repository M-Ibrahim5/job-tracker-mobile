import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// Submits the registration form; server field errors are available from the
/// state's `ApiFailure.fields`.
class RegisterController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates the account and signs in.
  Future<void> submit({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authControllerProvider.notifier)
          .signUp(
            fullName: fullName.trim(),
            email: email.trim(),
            password: password,
          ),
    );
  }
}

/// Provider for [RegisterController].
final registerControllerProvider =
    AutoDisposeAsyncNotifierProvider<RegisterController, void>(
      RegisterController.new,
    );
