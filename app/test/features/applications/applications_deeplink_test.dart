import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobtrail/core/constants/application_strings.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/features/applications/presentation/application_card.dart';
import 'package:jobtrail/features/applications/presentation/applications_screen.dart';

import 'harness.dart';

/// The list mounted at `/applications` the way the real router does, with a
/// way to navigate like the dashboard charts do.
Future<(AppFixture, String Function())> _pump(
  WidgetTester tester,
  String location,
) async {
  final f = AppFixture();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routedApp(
      const SizedBox.shrink(),
      overrides: f.overrides,
      routes: [
        GoRoute(
          path: '/applications',
          builder: (_, state) =>
              ApplicationsScreen(query: state.uri.queryParameters),
        ),
      ],
    ),
  );
  GoRouter.of(tester.element(find.byType(SizedBox).first)).go(location);
  await tester.pumpAndSettle();
  String current() => GoRouter.of(
    tester.element(find.byType(ApplicationsScreen)),
  ).routerDelegate.currentConfiguration.uri.toString();
  return (f, current);
}

int _cards(WidgetTester tester) =>
    find.byType(ApplicationCard, skipOffstage: false).evaluate().length;

void main() {
  testWidgets('?status= filters the list and shows a removable chip', (
    tester,
  ) async {
    final (f, _) = await _pump(tester, '/applications?status=offer');

    expect(f.repo.listCalls.last.filter.statuses, {ApplicationStatus.offer});
    expect(_cards(tester), 1);
    expect(find.text('Status: Offer'), findsOneWidget);
    expect(find.text('1 Offer applications'), findsOneWidget);
  });

  testWidgets('a week link filters on the applied date', (tester) async {
    final (f, _) = await _pump(
      tester,
      '/applications?from=2026-10-12&to=2026-10-18',
    );

    final used = f.repo.listCalls.last.filter;
    expect(used.appliedFrom, DateTime(2026, 10, 12));
    expect(used.appliedTo, DateTime(2026, 10, 18));
    expect(find.text('12 Oct – 18 Oct'), findsOneWidget);
    expect(find.textContaining('· 12–18 Oct'), findsOneWidget);
  });

  testWidgets('arriving from a link replaces the previous filter', (
    tester,
  ) async {
    final (f, _) = await _pump(
      tester,
      '/applications?status=rejected&arrangement=remote',
    );
    expect(f.repo.listCalls.last.filter.arrangements, {WorkArrangement.remote});

    GoRouter.of(
      tester.element(find.byType(ApplicationsScreen)),
    ).go('/applications?status=applied');
    await tester.pumpAndSettle();

    final used = f.repo.listCalls.last.filter;
    expect(used.statuses, {ApplicationStatus.applied});
    expect(used.arrangements, isEmpty, reason: 'replaced, not merged');
  });

  testWidgets('removing the chip clears the filter and the query', (
    tester,
  ) async {
    final (f, current) = await _pump(tester, '/applications?status=offer');

    await tester.tap(find.byTooltip('Remove filter Status: Offer'));
    await tester.pumpAndSettle();

    expect(f.repo.listCalls.last.filter.statuses, isEmpty);
    expect(current(), '/applications');
    expect(find.byKey(const ValueKey('filter-chip-status')), findsNothing);
  });

  testWidgets('Clear all resets every criterion and drops the params', (
    tester,
  ) async {
    final (f, current) = await _pump(
      tester,
      '/applications?status=applied&from=2026-10-12&to=2026-10-18',
    );
    expect(find.text('Status: Applied'), findsOneWidget);

    await tester.tap(find.text(ApplicationStrings.clearAll));
    await tester.pumpAndSettle();

    final used = f.repo.listCalls.last.filter;
    expect(used.isActive, isFalse);
    expect(current(), '/applications');
    expect(find.text(ApplicationStrings.clearAll), findsNothing);
  });

  testWidgets('a stage without applications says so and can be cleared', (
    tester,
  ) async {
    final f = AppFixture();
    f.backend.applications.removeWhere(
      (_, a) => a.status == ApplicationStatus.offer,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      routedApp(
        const SizedBox.shrink(),
        overrides: f.overrides,
        routes: [
          GoRoute(
            path: '/applications',
            builder: (_, state) =>
                ApplicationsScreen(query: state.uri.queryParameters),
          ),
        ],
      ),
    );
    GoRouter.of(
      tester.element(find.byType(SizedBox).first),
    ).go('/applications?status=offer');
    await tester.pumpAndSettle();

    expect(find.text('No Offer applications yet'), findsOneWidget);
    await tester.tap(find.text(ApplicationStrings.clearFilter));
    await tester.pumpAndSettle();
    expect(find.text('No Offer applications yet'), findsNothing);
    expect(_cards(tester), greaterThan(0));
  });
}
