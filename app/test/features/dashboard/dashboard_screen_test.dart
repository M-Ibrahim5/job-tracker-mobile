import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/core/constants/dashboard_strings.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/dashboard_data.dart';
import 'package:jobtrail/domain/repositories/misc_repositories.dart';
import 'package:jobtrail/features/dashboard/application/dashboard_providers.dart';
import 'package:jobtrail/features/dashboard/presentation/chart_sheets.dart';
import 'package:jobtrail/features/dashboard/presentation/dashboard_charts.dart';
import 'package:jobtrail/features/dashboard/presentation/dashboard_screen.dart';
import 'package:jobtrail/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:jobtrail/features/interviews/presentation/interview_tile.dart';

import '../applications/harness.dart';
import '../interviews/interviews_harness.dart';

class _Dashboard implements DashboardRepository {
  _Dashboard(this.inner);

  final DashboardRepository inner;
  Completer<void>? gate;
  Object? failNext;
  int loads = 0;
  String? lastTimezone;

  /// Rewrites the loaded data (e.g. to force a zero-count status).
  DashboardData Function(DashboardData)? transform;

  @override
  Future<DashboardData> load({required String timezone}) async {
    loads++;
    lastTimezone = timezone;
    await gate?.future;
    final e = failNext;
    if (e != null) {
      failNext = null;
      throw e;
    }
    final data = await inner.load(timezone: timezone);
    return transform?.call(data) ?? data;
  }
}

class _Setup {
  _Setup() {
    fixture = InterviewFixture();
    dashboard = _Dashboard(FakeDashboardRepository(fixture.backend));
  }

  late final InterviewFixture fixture;
  late final _Dashboard dashboard;
  FakeBackend get backend => fixture.backend;

  List<Override> get overrides => [
    ...fixture.overrides,
    dashboardRepositoryProvider.overrideWithValue(dashboard),
    dashboardClockProvider.overrideWithValue(() => DateTime(2026, 10, 25, 9)),
    currentUserProvider.overrideWithValue(backend.usersByEmail[kFakeEmail]),
  ];
}

Future<_Setup> _pump(
  WidgetTester tester, {
  _Setup? setup,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool settle = true,
}) async {
  final s = setup ?? _Setup();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routedApp(
      const DashboardScreen(),
      overrides: s.overrides,
      textScale: textScale,
      brightness: brightness,
      routes: [
        GoRoute(
          path: '/applications',
          builder: (_, st) => Scaffold(body: Text('LIST ${st.uri.query}')),
        ),
        GoRoute(
          path: '/interviews',
          builder: (_, _) => const Scaffold(body: Text('ALL-INTERVIEWS')),
        ),
        ...interviewRoutes(),
      ],
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return s;
}

Finder _scrollable() => find.byType(Scrollable).first;

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: _scrollable());
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  group('content', () {
    testWidgets('greets by time of day with the first name and date', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Good morning, Muhammad'), findsOneWidget);
      expect(find.text('Sunday, 25 Oct'), findsOneWidget);
    });

    testWidgets('summary numbers match the fixture data', (tester) async {
      final s = await _pump(tester);
      final apps = s.backend.applications.values;
      final active = apps.where((a) => a.status.isActive).length;
      final responded = apps.where(
        (a) => a.status != ApplicationStatus.applied,
      );
      final percent = (100 * responded.length / apps.length).round();

      final card = find.byType(SummaryCard);
      Finder inCard(String t) =>
          find.descendant(of: card, matching: find.text(t));
      expect(inCard('${apps.length}'), findsOneWidget);
      expect(inCard('$active'), findsOneWidget);
      expect(inCard('$percent%'), findsOneWidget);
      expect(s.dashboard.lastTimezone, isNotEmpty);

      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: card,
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, closeTo(percent / 100, 1e-9));
    });

    testWidgets('status tiles show the count per status', (tester) async {
      final s = await _pump(tester);
      final tiles = find.byType(StatusTiles);
      for (final status in ApplicationStatus.values) {
        final n = s.backend.applications.values
            .where((a) => a.status == status)
            .length;
        final tile = find.descendant(
          of: tiles,
          matching: find.bySemanticsLabel(
            DashboardStrings.tileSemantics(status.label, n),
          ),
        );
        expect(tile, findsOneWidget, reason: status.name);
      }
    });

    testWidgets('pipeline ring has a ring, total and text summary', (
      tester,
    ) async {
      final s = await _pump(tester);
      await _scrollTo(tester, find.byType(PieChart));

      final total = s.backend.applications.length;
      final chart = tester.widget<PieChart>(find.byType(PieChart));
      final sections = chart.data.sections;
      expect(sections.every((x) => x.radius == 24), isTrue);
      expect(chart.data.centerSpaceRadius, 64);
      expect(
        sections.fold<double>(0, (sum, x) => sum + x.value),
        total.toDouble(),
      );
      expect(
        find.bySemanticsLabel(RegExp('^Pipeline: $total applications\\.')),
        findsOneWidget,
      );
      expect(find.text('$total'), findsWidgets, reason: 'center total');
    });

    testWidgets('weekly chart shows eight labelled columns and axis labels', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, find.text(DashboardStrings.thisWeek));

      expect(find.text(DashboardStrings.sectionWeekly), findsOneWidget);
      expect(find.text(DashboardStrings.weeklyCaption), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Week of ')), findsNWidgets(8));
    });

    testWidgets('upcoming interviews and recent activity are listed', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, find.text(DashboardStrings.sectionActivity));

      expect(find.byType(InterviewTile), findsNWidgets(3));
      expect(find.byType(ActivityRow), findsWidgets);
      expect(find.textContaining('Moved '), findsWidgets);
    });
  });

  group('navigation', () {
    testWidgets('a status tile opens the list filtered by that status', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(StatusTiles),
          matching: find.text('Interview'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LIST status=interview'), findsOneWidget);
    });

    testWidgets('the + button starts a new application', (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip(DashboardStrings.addApplication));
      await tester.pumpAndSettle();
      expect(find.text('NEW-FORM'), findsOneWidget);
    });

    testWidgets('See all opens the interviews list; a row opens its detail', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, find.text(DashboardStrings.seeAll));
      await tester.tap(find.text(DashboardStrings.seeAll));
      await tester.pumpAndSettle();
      expect(find.text('ALL-INTERVIEWS'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Technical interview · Round 2'));
      await tester.tap(find.text('Technical interview · Round 2'));
      await tester.pumpAndSettle();
      expect(
        find.text('Northwind Labs · Senior Flutter Developer'),
        findsOneWidget,
      );
    });

    testWidgets('an activity row opens the application', (tester) async {
      await _pump(tester);
      await _scrollTo(tester, find.byType(ActivityRow).first);
      await tester.tap(find.byType(ActivityRow).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('DETAIL-'), findsOneWidget);
    });
  });

  group('charts', () {
    final weekly = [for (var i = 0; i < 8; i++) DateTime(2026, 8, 31 + 7 * i)];
    const counts = [0, 1, 2, 0, 4, 1, 0, 2];

    void useWeekly(_Setup s, {List<int> weeklyCounts = counts}) {
      s.dashboard.transform = (d) => DashboardData(
        total: d.total,
        active: d.active,
        responseRatePercent: d.responseRatePercent,
        statusCounts: d.statusCounts,
        weekly: [
          for (var i = 0; i < 8; i++)
            WeeklyCount(weekStart: weekly[i], count: weeklyCounts[i]),
        ],
        upcomingInterviews: d.upcomingInterviews,
        recentActivity: d.recentActivity,
      );
    }

    Finder painted(String type) => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter.runtimeType.toString() == type,
    );

    ApplicationStatus firstUsed(_Setup s) =>
        ApplicationStatus.values.firstWhere(
          (st) => s.backend.applications.values.any((a) => a.status == st),
        );

    Future<void> openFullList(WidgetTester tester) async {
      await tester.tap(find.text(DashboardStrings.openInApplications));
      await tester.pumpAndSettle();
    }

    testWidgets('every legend row opens its pop-up, zero counts included', (
      tester,
    ) async {
      final s = _Setup();
      s.dashboard.transform = (d) => DashboardData(
        total: d.total,
        active: d.active,
        responseRatePercent: d.responseRatePercent,
        statusCounts: {...d.statusCounts, ApplicationStatus.offer: 0},
        weekly: d.weekly,
        upcomingInterviews: d.upcomingInterviews,
        recentActivity: d.recentActivity,
      );
      await _pump(tester, setup: s);
      await _scrollTo(tester, find.byType(PieChart));

      for (final status in ApplicationStatus.values) {
        final row = find.descendant(
          of: find.byType(PipelineCard),
          matching: find.text(status.label),
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        final sheet = find.byType(StatusApplicationsSheet);
        expect(sheet, findsOneWidget, reason: status.name);
        expect(tester.widget<StatusApplicationsSheet>(sheet).status, status);
        // The full filtered list is still one tap away.
        await openFullList(tester);
        expect(find.text('LIST status=${status.name}'), findsOneWidget);
        GoRouter.of(tester.element(find.textContaining('LIST'))).go('/');
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.byType(PieChart));
      }
    });

    testWidgets('tapping a segment lists that status in a pop-up', (
      tester,
    ) async {
      final s = await _pump(tester);
      await _scrollTo(tester, find.byType(PieChart));
      final status = firstUsed(s);
      final expected = s.backend.applications.values
          .where((a) => a.status == status)
          .toList();

      final center = tester.getCenter(find.byType(PieChart));
      await tester.tapAt(center + const Offset(3, -80));
      await tester.pumpAndSettle();

      expect(find.textContaining('LIST'), findsNothing, reason: 'no jump');
      final sheet = find.byType(StatusApplicationsSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.byType(DrillApplicationRow)),
        findsNWidgets(expected.length),
      );
      expect(
        find.text(DashboardStrings.applicationCount(expected.length)),
        findsOneWidget,
      );
      // Each row shows title, company and status.
      final a = expected.first;
      final row = find.ancestor(
        of: find.text(a.jobTitle),
        matching: find.byType(DrillApplicationRow),
      );
      expect(
        find.descendant(of: row, matching: find.text(a.companyName)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byType(StatusChip)),
        findsOneWidget,
      );
    });

    testWidgets('a row in the pop-up opens its application', (tester) async {
      final s = await _pump(tester);
      await _scrollTo(tester, find.byType(PieChart));
      final a = s.backend.applications.values.firstWhere(
        (x) => x.status == firstUsed(s),
      );
      await tester.tapAt(
        tester.getCenter(find.byType(PieChart)) + const Offset(3, -80),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(a.jobTitle).first);
      await tester.pumpAndSettle();
      expect(find.byType(StatusApplicationsSheet), findsNothing);
      expect(find.text('DETAIL-${a.id}'), findsOneWidget);
    });

    testWidgets('closing the pop-up stays on the dashboard', (tester) async {
      await _pump(tester);
      await _scrollTo(tester, find.byType(PieChart));
      await tester.tapAt(
        tester.getCenter(find.byType(PieChart)) + const Offset(3, -80),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(DashboardStrings.sheetClose));
      await tester.pumpAndSettle();
      expect(find.byType(StatusApplicationsSheet), findsNothing);
      expect(find.byType(PipelineCard), findsOneWidget);
      expect(find.textContaining('LIST'), findsNothing);
    });

    testWidgets('tapping the hole does nothing', (tester) async {
      await _pump(tester);
      await _scrollTo(tester, find.byType(PieChart));
      await tester.tapAt(tester.getCenter(find.byType(PieChart)));
      await tester.pumpAndSettle();
      expect(find.textContaining('LIST'), findsNothing);
    });

    testWidgets('pressing a segment previews it; moving off it cancels', (
      tester,
    ) async {
      final s = await _pump(tester);
      await _scrollTo(tester, find.byType(PieChart));
      final first = firstUsed(s);
      final total = s.backend.applications.length;

      final center = tester.getCenter(find.byType(PieChart));
      final gesture = await tester.startGesture(center + const Offset(3, -80));
      await tester.pumpAndSettle();

      final chart = tester.widget<PieChart>(find.byType(PieChart));
      expect(chart.data.sections.first.radius, 33);
      expect(find.byKey(ValueKey('ring-center-${first.name}')), findsOneWidget);
      expect(find.textContaining('% of $total'), findsOneWidget);

      await gesture.moveTo(center + const Offset(8, 0)); // into the hole
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ring-center-total')), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.textContaining('LIST'), findsNothing);
    });

    testWidgets('a vertical scroll over the ring cancels the selection', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, find.byType(PieChart));
      final center = tester.getCenter(find.byType(PieChart));

      final gesture = await tester.startGesture(center + const Offset(3, -80));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(find.byKey(const ValueKey('ring-center-total')), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.textContaining('LIST'), findsNothing);
    });

    testWidgets('a bar with applications opens its week pop-up', (
      tester,
    ) async {
      final s = _Setup();
      useWeekly(s);
      await _pump(tester, setup: s);
      await _scrollTo(tester, painted('_WeeklyPainter'));

      final rect = tester.getRect(painted('_WeeklyPainter'));
      final column = rect.width / 8;
      // Any height inside the column counts, not just the bar itself.
      await tester.tapAt(Offset(rect.left + column * 4.5, rect.top + 6));
      await tester.pumpAndSettle();
      final sheet = find.byType(WeekApplicationsSheet);
      expect(sheet, findsOneWidget);
      expect(tester.widget<WeekApplicationsSheet>(sheet).isCurrent, isFalse);
      expect(find.text('Week of 28 Sep'), findsOneWidget);
      await openFullList(tester);
      expect(find.text('LIST from=2026-09-28&to=2026-10-04'), findsOneWidget);
    });

    testWidgets('the current week links to its Monday to Sunday', (
      tester,
    ) async {
      final s = _Setup();
      useWeekly(s);
      await _pump(tester, setup: s);
      await _scrollTo(tester, painted('_WeeklyPainter'));

      final rect = tester.getRect(painted('_WeeklyPainter'));
      await tester.tapAt(
        Offset(rect.left + rect.width / 8 * 7.5, rect.bottom - 10),
      );
      await tester.pumpAndSettle();
      final sheet = find.byType(WeekApplicationsSheet);
      expect(tester.widget<WeekApplicationsSheet>(sheet).isCurrent, isTrue);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(DashboardStrings.thisWeekTitle),
        ),
        findsOneWidget,
      );
      await openFullList(tester);
      expect(find.text('LIST from=2026-10-19&to=2026-10-25'), findsOneWidget);
    });

    testWidgets('a week without applications does not navigate', (
      tester,
    ) async {
      final s = _Setup();
      useWeekly(s);
      await _pump(tester, setup: s);
      await _scrollTo(tester, painted('_WeeklyPainter'));

      final rect = tester.getRect(painted('_WeeklyPainter'));
      await tester.tapAt(
        Offset(rect.left + rect.width / 8 * 3.5, rect.bottom - 10),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('LIST'), findsNothing);
      expect(find.byType(WeeklyBarsCard), findsOneWidget);
    });

    testWidgets('dragging across bars does not navigate', (tester) async {
      final s = _Setup();
      useWeekly(s);
      await _pump(tester, setup: s);
      await _scrollTo(tester, painted('_WeeklyPainter'));

      final rect = tester.getRect(painted('_WeeklyPainter'));
      final y = rect.bottom - 20;
      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width / 8 * 1.5, y),
      );
      await gesture.moveTo(Offset(rect.left + rect.width / 8 * 4.5, y));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.textContaining('LIST'), findsNothing);
    });

    testWidgets('columns are accessible: buttons only for non-empty weeks', (
      tester,
    ) async {
      final s = _Setup();
      useWeekly(s);
      await _pump(tester, setup: s);
      await _scrollTo(tester, painted('_WeeklyPainter'));

      expect(
        find.bySemanticsLabel(
          'Week of 28 Sep: 4 applications. Opens filtered list',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Week of 21 Sep: no applications'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^Applications per week, last 8 weeks: 0, 1, 2, 0, 4, 1, 0, 2',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('legend rows carry a button label with count and percent', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, find.byType(PieChart));
      expect(
        find.bySemanticsLabel(
          RegExp(r'^\w+, \d+ applications, \d+ percent\. Opens filtered list$'),
        ),
        findsNWidgets(ApplicationStatus.values.length),
      );
    });

    testWidgets('no applications in 8 weeks shows a caption and a button', (
      tester,
    ) async {
      final s = _Setup();
      useWeekly(s, weeklyCounts: List.filled(8, 0));
      await _pump(tester, setup: s);
      await _scrollTo(tester, painted('_WeeklyPainter'));

      expect(find.text(DashboardStrings.noWeeklyData), findsOneWidget);
      await tester.tap(find.text(DashboardStrings.addApplicationShort));
      await tester.pumpAndSettle();
      expect(find.text('NEW-FORM'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      final s = _Setup()..dashboard.gate = Completer<void>();
      await _pump(tester, setup: s, settle: false);
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(SummaryCard), findsNothing);
      // The greeting doesn't wait for the data.
      expect(find.text('Good morning, Muhammad'), findsOneWidget);

      s.dashboard.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SummaryCard), findsOneWidget);
    });

    testWidgets('shows an error with Retry', (tester) async {
      final s = _Setup()..dashboard.failNext = const NetworkFailure();
      await _pump(tester, setup: s);
      expect(find.byType(ErrorState), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(SummaryCard), findsOneWidget);
    });

    testWidgets('pull to refresh reloads', (tester) async {
      final s = await _pump(tester);
      final before = s.dashboard.loads;
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(s.dashboard.loads, before + 1);
    });

    testWidgets('empty account shows the illustration and a call to action', (
      tester,
    ) async {
      final s = _Setup()..backend.clearData();
      await _pump(tester, setup: s);

      expect(find.byType(SummaryCard), findsNothing);
      expect(find.text(DashboardStrings.emptyTitle), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.tap(
        find.widgetWithText(FilledButton, DashboardStrings.emptyAction),
      );
      await tester.pumpAndSettle();
      expect(find.text('NEW-FORM'), findsOneWidget);
    });

    testWidgets('reloads when applications change', (tester) async {
      final s = await _pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );
      final before = s.dashboard.loads;
      container.read(dataRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();
      expect(s.dashboard.loads, before + 1);
    });
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets('fits 320px at 1.5x text (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        await _pump(
          tester,
          size: const Size(320, 640),
          textScale: 1.5,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
        for (final t in [
          find.byType(PieChart),
          find.text(DashboardStrings.thisWeek),
          find.byType(ActivityRow).first,
        ]) {
          await _scrollTo(tester, t);
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('empty state fits 320px at 1.5x text', (tester) async {
      final s = _Setup()..backend.clearData();
      await _pump(tester, setup: s, size: const Size(320, 640), textScale: 1.5);
      expect(tester.takeException(), isNull);
    });
  });
}
