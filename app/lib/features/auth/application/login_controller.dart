import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// Submits the sign-in form. State is the result of the latest attempt; on
/// success the auth state changes and the router leaves the screen.
class LoginController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Signs in with [email] and [password].
  Future<void> submit({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authControllerProvider.notifier)
          .signIn(email: email.trim(), password: password),
    );
  }
}

/// Provider for [LoginController].
final loginControllerProvider =
    AutoDisposeAsyncNotifierProvider<LoginController, void>(
      LoginController.new,
    );
