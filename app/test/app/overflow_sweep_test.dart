import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/app.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/app/router.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';

import '../helpers/test_app.dart';

/// Every screen on the smallest supported phone (320×568) with large text, in
/// both themes, must lay out without overflow, also when scrolled to the end.
const _signedInRoutes = [
  '/',
  '/applications',
  '/applications/new',
  '/applications/1',
  '/applications/1/edit',
  '/interviews',
  '/interviews/new',
  '/interviews/1',
  '/interviews/1/edit',
  '/applications/1/interviews/new',
  '/calendar',
  '/notifications',
  '/settings',
  '/settings/profile',
];
const _signedOutRoutes = ['/login', '/register'];

Future<void> _sweep(
  WidgetTester tester, {
  required List<String> routes,
  required bool signedIn,
  required double scale,
  required ThemeMode mode,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final backend = FakeBackend(latency: Duration.zero);
  if (signedIn) backend.currentUser = backend.usersByEmail[kFakeEmail];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeOverrides(backend),
        themeModeProvider.overrideWith((ref) => mode),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 568),
          textScaler: TextScaler.linear(scale),
        ),
        child: const JobTrailApp(useGoogleFonts: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(JobTrailApp)),
  );

  for (final route in routes) {
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$route at top');
    // Scroll to the bottom in steps so every lazily built child is laid out.
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      for (var i = 0; i < 6; i++) {
        await tester.drag(scrollables.first, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route scrolled $i');
      }
    }
  }
}

void main() {
  for (final scale in [1.5, 2.0]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final label = 'text ×$scale, ${mode.name}';
      testWidgets('signed-in screens fit 320×568 ($label)', (tester) async {
        await _sweep(
          tester,
          routes: _signedInRoutes,
          signedIn: true,
          scale: scale,
          mode: mode,
        );
      });
      testWidgets('auth screens fit 320×568 ($label)', (tester) async {
        await _sweep(
          tester,
          routes: _signedOutRoutes,
          signedIn: false,
          scale: scale,
          mode: mode,
        );
      });
    }
  }
}
