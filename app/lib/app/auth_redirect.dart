import '../features/auth/application/auth_controller.dart';
import 'routes.dart';

/// Pure redirect rule from `DESIGN.md §5`, kept separate so it can be tested.
///
/// Returns the location to redirect to, or null to stay on [location].
/// [auth] is null while the session is still being restored.
String? authRedirect({
  required AuthState? auth,
  required String location,
  required bool onboardingSeen,
}) {
  final onAuthPage = location == Routes.login || location == Routes.register;
  return switch (auth) {
    null || AuthUnknown() => location == Routes.splash ? null : Routes.splash,
    AuthUnauthenticated() => onAuthPage ? null : Routes.login,
    AuthAuthenticated() when !onboardingSeen =>
      location == Routes.onboarding ? null : Routes.onboarding,
    AuthAuthenticated() =>
      onAuthPage || location == Routes.splash ? Routes.dashboard : null,
  };
}
