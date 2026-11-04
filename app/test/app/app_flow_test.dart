import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/app.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/core/constants/account_strings.dart';
import 'package:jobtrail/core/constants/app_constants.dart';
import 'package:jobtrail/core/widgets/small_widgets.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/features/auth/application/auth_controller.dart';

import '../helpers/test_app.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...fakeOverrides(), ...overrides],
      child: const JobTrailApp(useGoogleFonts: false),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'starts at login, signs in with the demo account, shows the shell',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(tester);

      // Unauthenticated: the sign-in placeholder, prefilled for the fake.
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      // Authenticated: 5-tab shell on the dashboard.
      expect(find.byType(NavigationBar), findsOneWidget);
      for (final label in [
        AppStrings.tabDashboard,
        AppStrings.tabApplications,
        AppStrings.tabCalendar,
        AppStrings.tabNotifications,
        AppStrings.tabSettings,
      ]) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }

      // Tabs switch.
      await tester.tap(find.text(AppStrings.tabSettings));
      await tester.pumpAndSettle();
      expect(find.text(AccountStrings.editProfile), findsOneWidget);

      // Logging out (with confirmation) returns to login.
      final logOut = find.widgetWithText(OutlinedButton, AccountStrings.logOut);
      await tester.ensureVisible(logOut);
      await tester.tap(logOut);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, AccountStrings.logOut));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets('shows the invalid-credentials message on a wrong password', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.errInvalidCredentials), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('restores an existing session straight into the shell', (
    tester,
  ) async {
    final backend = FakeBackend(latency: Duration.zero);
    backend.currentUser = backend.usersByEmail[kFakeEmail];

    await _pumpApp(tester, overrides: fakeOverrides(backend));

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the Alerts badge follows unreadCountProvider and caps at 9+', (
    tester,
  ) async {
    final backend = FakeBackend(latency: Duration.zero);
    backend.currentUser = backend.usersByEmail[kFakeEmail];

    await _pumpApp(
      tester,
      overrides: [
        ...fakeOverrides(backend),
        unreadCountProvider.overrideWithValue(12),
      ],
    );

    expect(find.text('9+'), findsOneWidget);
    expect(find.byType(UnreadBadge), findsWidgets);
  });

  testWidgets('a rejected session sends the user back to login', (
    tester,
  ) async {
    final backend = FakeBackend(latency: Duration.zero);
    backend.currentUser = backend.usersByEmail[kFakeEmail];
    await _pumpApp(tester, overrides: fakeOverrides(backend));
    expect(find.byType(NavigationBar), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    );
    container.read(authControllerProvider.notifier).sessionExpired();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('light and dark themes both build the shell', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final backend = FakeBackend(latency: Duration.zero);
      backend.currentUser = backend.usersByEmail[kFakeEmail];
      await _pumpApp(
        tester,
        overrides: [
          ...fakeOverrides(backend),
          themeModeProvider.overrideWith((ref) => mode),
        ],
      );
      final brightness = Theme.of(
        tester.element(find.byType(NavigationBar)),
      ).brightness;
      expect(
        brightness,
        mode == ThemeMode.light ? Brightness.light : Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
}
