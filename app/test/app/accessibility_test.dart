import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/app.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/app/router.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';

import '../helpers/test_app.dart';

/// Flutter's accessibility guidelines on every main screen in both themes:
/// every tappable has a label, targets are at least 48dp, and text meets the
/// WCAG contrast ratio.
const _routes = [
  '/',
  '/applications',
  '/applications/1',
  '/applications/new',
  '/interviews',
  '/interviews/1',
  '/calendar',
  '/notifications',
  '/settings',
  '/settings/profile',
];

Future<void> _check(
  WidgetTester tester,
  ThemeMode mode,
  List<String> routes,
) async {
  final handle = tester.ensureSemantics();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = FakeBackend(latency: Duration.zero);
  backend.currentUser = backend.usersByEmail[kFakeEmail];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeOverrides(backend),
        themeModeProvider.overrideWith((ref) => mode),
      ],
      child: const JobTrailApp(useGoogleFonts: false),
    ),
  );
  await tester.pumpAndSettle();
  final router = ProviderScope.containerOf(
    tester.element(find.byType(JobTrailApp)),
  ).read(routerProvider);
  for (final route in routes) {
    router.go(route);
    await tester.pumpAndSettle();
    await expectLater(
      tester,
      meetsGuideline(labeledTapTargetGuideline),
      reason: '$route labels',
    );
    await expectLater(
      tester,
      meetsGuideline(androidTapTargetGuideline),
      reason: '$route targets',
    );
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '$route contrast',
    );
  }
  handle.dispose();
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('accessibility guidelines hold (${mode.name})', (tester) async {
      await _check(tester, mode, _routes);
    });
  }

  testWidgets('sign-in and register meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(FakeBackend(latency: Duration.zero)),
        child: const JobTrailApp(useGoogleFonts: false),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
