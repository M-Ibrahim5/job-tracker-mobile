import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/theme/app_theme.dart';
import 'package:jobtrail/core/constants/dashboard_strings.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_filter.dart';
import 'package:jobtrail/domain/models/job_application.dart';
import 'package:jobtrail/domain/models/page.dart';
import 'package:jobtrail/features/dashboard/application/chart_drilldown.dart';
import 'package:jobtrail/features/dashboard/presentation/chart_sheets.dart';

JobApplication _app(
  int id,
  DateTime applied,
  ApplicationStatus status, {
  String title = 'Flutter Developer',
  String company = 'Acme',
}) => JobApplication(
  id: id,
  jobTitle: title,
  companyName: company,
  location: 'Remote',
  workArrangement: WorkArrangement.remote,
  appliedDate: applied,
  status: status,
  createdAt: applied,
  updatedAt: applied,
);

final _week = [
  _app(
    3,
    DateTime(2026, 10, 14),
    ApplicationStatus.interview,
    company: 'Orbit',
  ),
  _app(1, DateTime(2026, 10, 12), ApplicationStatus.applied, company: 'Delta'),
  _app(2, DateTime(2026, 10, 12), ApplicationStatus.rejected, company: 'Helio'),
  _app(4, DateTime(2026, 10, 16), ApplicationStatus.applied, company: 'Lumen'),
];

Future<void> _pumpSheet(
  WidgetTester tester,
  Widget sheet, {
  List<JobApplication>? items,
  int? total,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final list = items ?? _week;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chartDrillDownProvider.overrideWith(
          (ref, filter) async => Page(
            items: list,
            page: 1,
            pageSize: kDrillDownLimit,
            total: total ?? list.length,
          ),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.light(useGoogleFonts: false)
            : AppTheme.dark(useGoogleFonts: false),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: sheet),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('logic', () {
    test('the week filter runs Monday to Sunday on applied date', () {
      final f = weekDrillFilter(DateTime(2026, 10, 12, 18, 30));
      expect(f.appliedFrom, DateTime(2026, 10, 12));
      expect(f.appliedTo, DateTime(2026, 10, 18));
      expect(f.sort, ApplicationSort.oldest);
      expect(f.statuses, isEmpty);
    });

    test('the status filter selects only that status', () {
      expect(
        statusDrillFilter(ApplicationStatus.offer),
        const ApplicationFilter(statuses: {ApplicationStatus.offer}),
      );
    });

    test('applications are grouped by applied day, earliest first', () {
      final days = groupByAppliedDay(_week);
      expect(days.map((d) => d.day), [
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 16),
      ]);
      expect(days.first.applications.map((a) => a.id), [1, 2]);
      expect(groupByAppliedDay(const []), isEmpty);
    });

    test('the breakdown counts current statuses in pipeline order', () {
      expect(statusBreakdown(_week), [
        (ApplicationStatus.applied, 2),
        (ApplicationStatus.interview, 1),
        (ApplicationStatus.rejected, 1),
      ]);
      expect(statusBreakdown(const []), isEmpty);
    });
  });

  group('week pop-up', () {
    final sheet = WeekApplicationsSheet(
      monday: DateTime(2026, 10, 12),
      isCurrent: false,
    );

    testWidgets('header, outcome strip and a day-by-day timeline', (
      tester,
    ) async {
      await _pumpSheet(tester, sheet);

      expect(find.text('Week of 12 Oct'), findsOneWidget);
      expect(find.text('4 applications · 12–18 Oct'), findsOneWidget);

      expect(find.text(DashboardStrings.whereTheyAreNow), findsOneWidget);
      for (final s in [
        ApplicationStatus.applied,
        ApplicationStatus.interview,
        ApplicationStatus.rejected,
      ]) {
        expect(find.byKey(ValueKey('outcome-${s.name}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('outcome-offer')), findsNothing);
      expect(find.text('2 Applied'), findsOneWidget);

      final days = [
        'Mon 12 Oct · 2 applications',
        'Wed 14 Oct · 1 application',
        'Fri 16 Oct · 1 application',
      ];
      final ys = [for (final d in days) tester.getTopLeft(find.text(d)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.byType(DrillApplicationRow), findsNWidgets(4));
    });

    testWidgets('the current week is titled This week', (tester) async {
      await _pumpSheet(
        tester,
        WeekApplicationsSheet(monday: DateTime(2026, 10, 12), isCurrent: true),
      );
      expect(find.text(DashboardStrings.thisWeekTitle), findsOneWidget);
    });

    testWidgets('more than the limit says how many are shown', (tester) async {
      await _pumpSheet(tester, sheet, total: 120);
      expect(find.text('Showing 4 of 120'), findsOneWidget);
    });

    testWidgets('an empty week says so', (tester) async {
      await _pumpSheet(tester, sheet, items: const []);
      expect(find.text(DashboardStrings.noWeeklyData), findsOneWidget);
      expect(find.byType(OutcomeStrip), findsNothing);
    });
  });

  group('status pop-up', () {
    testWidgets('rows show title, company and status; empty says so', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        const StatusApplicationsSheet(status: ApplicationStatus.applied),
        items: [_week[1], _week[3]],
      );
      expect(find.text('Applied'), findsWidgets);
      expect(find.text('2 applications'), findsOneWidget);
      expect(find.text('Delta'), findsOneWidget);
      expect(find.text('Lumen'), findsOneWidget);
      expect(find.byType(StatusChip), findsNWidgets(2));
      expect(find.byType(CompanyMonogram), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(
          'Flutter Developer at Delta, Applied. Opens the application',
        ),
        findsOneWidget,
      );

      await _pumpSheet(
        tester,
        const StatusApplicationsSheet(status: ApplicationStatus.offer),
        items: const [],
      );
      expect(find.text('No Offer applications yet'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets('fits 320px at 1.5x text (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        await _pumpSheet(
          tester,
          WeekApplicationsSheet(
            monday: DateTime(2026, 10, 12),
            isCurrent: false,
          ),
          width: 320,
          textScale: 1.5,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
        await _pumpSheet(
          tester,
          const StatusApplicationsSheet(status: ApplicationStatus.interview),
          width: 320,
          textScale: 1.5,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
