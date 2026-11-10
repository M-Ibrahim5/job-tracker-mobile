import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/models/user.dart';

/// Whether and as whom the user is signed in.
sealed class AuthState {
  const AuthState();
}

/// The stored session has not been checked yet.
class AuthUnknown extends AuthState {
  /// Creates the state.
  const AuthUnknown();
}

/// A valid session exists for [user].
class AuthAuthenticated extends AuthState {
  /// Creates the state.
  const AuthAuthenticated(this.user);

  final User user;
}

/// There is no valid session.
class AuthUnauthenticated extends AuthState {
  /// Creates the state.
  const AuthUnauthenticated();
}

/// Owns the session: restores it on launch and exposes sign in / up / out.
///
/// `signIn` and `signUp` rethrow the repository's [Failure] so form
/// controllers can show it; they do not flip the state to loading, which would
/// make the router bounce the user to the splash screen.
class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      return user == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(user);
    } on Failure catch (e) {
      ref.read(loggerProvider).w('Could not restore session: $e');
      return const AuthUnauthenticated();
    }
  }

  /// Signs in and moves to [AuthAuthenticated].
  Future<void> signIn({required String email, required String password}) async {
    final user = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
    await _forgetForeignDeviceToken(user);
    state = AsyncData(AuthAuthenticated(user));
  }

  /// Signs in with a fingerprint-login [deviceToken].
  Future<void> signInWithDeviceToken(String deviceToken) async {
    final user = await ref
        .read(authRepositoryProvider)
        .deviceSignIn(deviceToken);
    // A token saved before owners were recorded now has a known owner.
    try {
      final store = ref.read(deviceTokenStoreProvider);
      if (await store.readOwner() == null) {
        await store.save(deviceToken, userId: user.id);
      }
    } on Object catch (e) {
      ref.read(loggerProvider).w('Could not record the token owner: $e');
    }
    state = AsyncData(AuthAuthenticated(user));
  }

  /// Fingerprint login signs in as whoever enrolled it. When someone else
  /// signs in with a password, forget the saved token (the server lets it
  /// expire) so it cannot be used to get back into the other account.
  Future<void> _forgetForeignDeviceToken(User user) async {
    try {
      final store = ref.read(deviceTokenStoreProvider);
      if (await store.read() == null) return;
      if (await store.readOwner() != user.id) {
        await store.clear();
      }
    } on Object catch (e) {
      // Secure storage trouble must not stop the user from signing in.
      ref.read(loggerProvider).w('Could not check the fingerprint token: $e');
    }
  }

  /// Registers, signs in and moves to [AuthAuthenticated].
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .signUp(fullName: fullName, email: email, password: password);
    await _forgetForeignDeviceToken(user);
    state = AsyncData(AuthAuthenticated(user));
  }

  /// Revokes the session, cancels local reminders and moves to [AuthUnauthenticated].
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    try {
      await ref.read(reminderCancellerProvider).cancelAll();
    } on Object catch (e) {
      ref.read(loggerProvider).w('Could not cancel reminders: $e');
    }
    state = const AsyncData(AuthUnauthenticated());
  }

  /// Called by the network layer after the stored session was rejected and
  /// its credentials were already cleared.
  void sessionExpired() {
    state = const AsyncData(AuthUnauthenticated());
  }

  /// Replaces the signed-in user after a profile change.
  void updateUser(User user) {
    if (state.valueOrNull is AuthAuthenticated) {
      state = AsyncData(AuthAuthenticated(user));
    }
  }
}

/// Session state for the whole app.
final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
