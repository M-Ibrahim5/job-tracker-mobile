import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/core/constants/account_strings.dart';
import 'package:jobtrail/core/constants/app_constants.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/models/user.dart';
import 'package:jobtrail/features/auth/application/auth_controller.dart';
import 'package:jobtrail/features/auth/presentation/login_screen.dart';
import 'package:jobtrail/core/services/biometric_service.dart';
import 'package:jobtrail/features/auth/presentation/register_screen.dart';

import '../helpers/test_app.dart';

class _OfflineAuthRepository extends FakeAuthRepository {
  _OfflineAuthRepository(super.b);

  @override
  Future<User> signIn({required String email, required String password}) =>
      Future.error(const NetworkFailure());
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget screen, {
  FakeBackend? backend,
  bool offline = false,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final b = backend ?? FakeBackend(latency: Duration.zero);
  await tester.pumpWidget(
    testApp(
      screen,
      overrides: [
        authRepositoryProvider.overrideWithValue(
          offline ? _OfflineAuthRepository(b) : FakeAuthRepository(b),
        ),
        // Signing in looks at the saved fingerprint token; secure storage is
        // not available in widget tests.
        deviceTokenStoreProvider.overrideWithValue(MemoryDeviceTokenStore()),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

Finder _field(int index) => find.byType(TextFormField).at(index);

void main() {
  group('LoginScreen', () {
    testWidgets('validates empty and malformed input before submitting', (
      tester,
    ) async {
      final container = await _pump(tester, const LoginScreen());
      await container.read(authControllerProvider.future);

      await tester.tap(
        find.widgetWithText(FilledButton, AccountStrings.signIn),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.errRequired), findsOneWidget);
      expect(find.text(AccountStrings.errPasswordRequired), findsOneWidget);

      await tester.enterText(_field(0), 'not-an-email');
      await tester.enterText(_field(1), 'x');
      await tester.tap(
        find.widgetWithText(FilledButton, AccountStrings.signIn),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.errInvalidEmail), findsOneWidget);
      expect(
        container.read(authControllerProvider).value,
        isA<AuthUnauthenticated>(),
      );
    });

    testWidgets('shows an inline banner for wrong credentials', (tester) async {
      await _pump(tester, const LoginScreen());

      await tester.enterText(_field(0), kFakeEmail);
      await tester.enterText(_field(1), 'WrongPass1!');
      await tester.tap(
        find.widgetWithText(FilledButton, AccountStrings.signIn),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NoticeBanner), findsOneWidget);
      expect(find.text(AppStrings.errInvalidCredentials), findsOneWidget);
    });

    testWidgets('a network error is a snackbar, not a banner', (tester) async {
      await _pump(tester, const LoginScreen(), offline: true);

      await tester.enterText(_field(0), kFakeEmail);
      await tester.enterText(_field(1), kFakePassword);
      await tester.tap(
        find.widgetWithText(FilledButton, AccountStrings.signIn),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(AppStrings.errNetwork), findsOneWidget);
      expect(find.byType(NoticeBanner), findsNothing);
    });

    testWidgets('signs in with valid credentials', (tester) async {
      final container = await _pump(tester, const LoginScreen());

      await tester.enterText(_field(0), kFakeEmail);
      await tester.enterText(_field(1), kFakePassword);
      await tester.tap(
        find.widgetWithText(FilledButton, AccountStrings.signIn),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(authControllerProvider).value,
        isA<AuthAuthenticated>(),
      );
    });

    testWidgets('forgot password shows the neutral confirmation', (
      tester,
    ) async {
      await _pump(tester, const LoginScreen());

      await tester.tap(find.text(AccountStrings.forgotPassword));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'nobody@example.com',
      );
      await tester.tap(find.text(AccountStrings.forgotSend));
      await tester.pumpAndSettle();

      expect(find.text(AccountStrings.forgotSent), findsOneWidget);
    });
  });

  group('RegisterScreen', () {
    Finder submit() =>
        find.widgetWithText(FilledButton, AccountStrings.createAccount);

    testWidgets('the button stays disabled until the terms are accepted', (
      tester,
    ) async {
      await _pump(tester, const RegisterScreen());
      expect(tester.widget<FilledButton>(submit()).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<FilledButton>(submit()).onPressed, isNotNull);
    });

    testWidgets('the strength meter follows the typed password', (
      tester,
    ) async {
      await _pump(tester, const RegisterScreen());

      await tester.enterText(_field(2), 'abc');
      await tester.pump();
      expect(find.text('Weak'), findsOneWidget);

      await tester.enterText(_field(2), 'abcdef1!');
      await tester.pump();
      expect(find.text('Good'), findsOneWidget);

      await tester.enterText(_field(2), 'Abcdef1!');
      await tester.pump();
      expect(find.text('Strong'), findsOneWidget);
    });

    testWidgets('validates fields and a mismatching confirmation', (
      tester,
    ) async {
      await _pump(tester, const RegisterScreen());
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.enterText(_field(1), 'bad');
      await tester.enterText(_field(2), 'short');
      await tester.enterText(_field(3), 'other');
      await tester.tap(submit());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errRequired), findsOneWidget);
      expect(find.text(AppStrings.errInvalidEmail), findsOneWidget);
      expect(find.text(AccountStrings.errPasswordRules), findsOneWidget);
      expect(find.text(AccountStrings.errPasswordMismatch), findsOneWidget);
    });

    testWidgets('maps EMAIL_TAKEN onto the email field', (tester) async {
      await _pump(tester, const RegisterScreen());
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.enterText(_field(0), 'Ada Lovelace');
      await tester.enterText(_field(1), kFakeEmail);
      await tester.enterText(_field(2), 'Abcdef1!');
      await tester.enterText(_field(3), 'Abcdef1!');
      await tester.tap(submit());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errEmailTaken), findsOneWidget);
    });

    testWidgets('creates the account and signs in', (tester) async {
      final container = await _pump(tester, const RegisterScreen());
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.enterText(_field(0), 'Ada Lovelace');
      await tester.enterText(_field(1), 'ada@example.com');
      await tester.enterText(_field(2), 'Abcdef1!');
      await tester.enterText(_field(3), 'Abcdef1!');
      await tester.tap(submit());
      await tester.pumpAndSettle();

      final auth = container.read(authControllerProvider).value;
      expect(auth, isA<AuthAuthenticated>());
      expect((auth! as AuthAuthenticated).user.fullName, 'Ada Lovelace');
    });
  });
}
