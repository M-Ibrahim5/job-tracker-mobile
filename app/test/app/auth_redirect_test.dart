import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/auth_redirect.dart';
import 'package:jobtrail/app/routes.dart';
import 'package:jobtrail/domain/models/user.dart';
import 'package:jobtrail/features/auth/application/auth_controller.dart';

const _user = User(id: 1, email: 'a@b.co', fullName: 'Ada Lovelace');

String? redirect(AuthState? auth, String location, {bool seen = true}) =>
    authRedirect(auth: auth, location: location, onboardingSeen: seen);

void main() {
  group('while the session is unknown', () {
    test('everything goes to the splash screen', () {
      expect(redirect(null, Routes.dashboard), Routes.splash);
      expect(redirect(const AuthUnknown(), Routes.login), Routes.splash);
    });

    test('the splash screen stays put', () {
      expect(redirect(null, Routes.splash), isNull);
    });
  });

  group('unauthenticated', () {
    const auth = AuthUnauthenticated();

    test('protected routes redirect to /login', () {
      expect(redirect(auth, Routes.dashboard), Routes.login);
      expect(redirect(auth, '/applications/12'), Routes.login);
      expect(redirect(auth, Routes.splash), Routes.login);
    });

    test('login and register stay reachable', () {
      expect(redirect(auth, Routes.login), isNull);
      expect(redirect(auth, Routes.register), isNull);
    });
  });

  group('authenticated', () {
    const auth = AuthAuthenticated(_user);

    test('auth pages and the splash redirect to the dashboard', () {
      expect(redirect(auth, Routes.login), Routes.dashboard);
      expect(redirect(auth, Routes.register), Routes.dashboard);
      expect(redirect(auth, Routes.splash), Routes.dashboard);
    });

    test('other routes are untouched', () {
      expect(redirect(auth, Routes.applications), isNull);
      expect(redirect(auth, Routes.editProfile), isNull);
    });

    test('first launch is sent to onboarding until it is seen', () {
      expect(redirect(auth, Routes.dashboard, seen: false), Routes.onboarding);
      expect(redirect(auth, Routes.onboarding, seen: false), isNull);
    });
  });
}
