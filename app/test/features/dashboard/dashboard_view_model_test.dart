import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/dashboard_data.dart';
import 'package:jobtrail/domain/models/interview.dart';
import 'package:jobtrail/features/dashboard/application/dashboard_view_model.dart';

DashboardData _data({
  int total = 10,
  int active = 6,
  int percent = 40,
  Map<ApplicationStatus, int>? counts,
  List<int> weekly = const [0, 1, 2, 0, 4, 1, 0, 2],
  List<Interview> upcoming = const [],
  List<RecentActivity> activity = const [],
}) => DashboardData(
  total: total,
  active: active,
  responseRatePercent: percent,
  statusCounts:
      counts ??
      {
        ApplicationStatus.applied: 4,
        ApplicationStatus.screening: 3,
        ApplicationStatus.interview: 0,
        ApplicationStatus.offer: 1,
        ApplicationStatus.rejected: 2,
      },
  weekly: [
    for (var i = 0; i < weekly.length; i++)
      WeeklyCount(weekStart: DateTime(2026, 8, 31 + 7 * i), count: weekly[i]),
  ],
  upcomingInterviews: upcoming,
  recentActivity: activity,
);

Interview _interview(int id) => Interview(
  id: id,
  applicationId: 1,
  title: 'I$id',
  type: InterviewType.video,
  scheduledAt: DateTime(2026, 11, id),
);

void main() {
  final now = DateTime(2026, 10, 25, 9, 30);

  group('greeting', () {
    test('changes at noon and at 5 pm', () {
      String at(int h, [int m = 0]) =>
          greetingFor(DateTime(2026, 10, 25, h, m), 'Aisha');
      expect(at(0), 'Good morning, Aisha');
      expect(at(11, 59), 'Good morning, Aisha');
      expect(at(12), 'Good afternoon, Aisha');
      expect(at(16, 59), 'Good afternoon, Aisha');
      expect(at(17), 'Good evening, Aisha');
      expect(at(23, 59), 'Good evening, Aisha');
    });

    test('works without a name', () {
      expect(greetingFor(now, null), 'Good morning');
      expect(greetingFor(now, '  '), 'Good morning');
    });

    test('first name is the first word', () {
      expect(firstNameOf('Muhammad Ibrahim'), 'Muhammad');
      expect(firstNameOf('  Aisha  Rahman '), 'Aisha');
      expect(firstNameOf('Cher'), 'Cher');
      expect(firstNameOf(''), isNull);
      expect(firstNameOf(null), isNull);
    });

    test('date line', () {
      expect(dateLineFor(DateTime(2026, 10, 24)), 'Saturday, 24 Oct');
    });
  });

  group('numbers', () {
    test('summary values and response bar fraction', () {
      final vm = DashboardViewModel.from(_data(percent: 67), now: now);
      expect(vm.total, 10);
      expect(vm.active, 6);
      expect(vm.responsePercent, 67);
      expect(vm.responseFraction, closeTo(0.67, 1e-9));
      expect(vm.isEmpty, isFalse);
    });

    test('response rate is clamped to 0 … 100', () {
      expect(
        DashboardViewModel.from(_data(percent: 140), now: now).responseFraction,
        1,
      );
      expect(
        DashboardViewModel.from(_data(percent: -5), now: now).responsePercent,
        0,
      );
    });

    test('an empty account is flagged', () {
      final vm = DashboardViewModel.from(
        _data(
          total: 0,
          active: 0,
          percent: 0,
          counts: {},
          weekly: List.filled(8, 0),
        ),
        now: now,
      );
      expect(vm.isEmpty, isTrue);
      expect(vm.slices, isEmpty);
    });

    test('there is one tile per status in pipeline order, missing = 0', () {
      final vm = DashboardViewModel.from(
        _data(counts: {ApplicationStatus.offer: 2}),
        now: now,
      );
      expect(vm.tiles.map((t) => t.status), ApplicationStatus.values);
      expect(vm.tiles.map((t) => t.count), [0, 0, 0, 2, 0]);
    });

    test('the donut skips statuses without applications', () {
      final vm = DashboardViewModel.from(_data(), now: now);
      expect(vm.slices.map((s) => s.status), [
        ApplicationStatus.applied,
        ApplicationStatus.screening,
        ApplicationStatus.offer,
        ApplicationStatus.rejected,
      ]);
    });

    test('pipeline summary reads every count for screen readers', () {
      final vm = DashboardViewModel.from(_data(), now: now);
      expect(
        vm.pipelineSummary,
        'Pipeline: 10 applications. 4 applied, 3 screening, 0 interview, 1 offer, 2 rejected.',
      );
    });
  });

  group('weekly bars', () {
    test('heights are relative to the tallest week', () {
      final vm = DashboardViewModel.from(_data(), now: now);
      expect(vm.bars, hasLength(8));
      expect(vm.bars.map((b) => b.fraction), [
        0,
        0.25,
        0.5,
        0,
        1,
        0.25,
        0,
        0.5,
      ]);
    });

    test('only the last bar is the current week', () {
      final vm = DashboardViewModel.from(_data(), now: now);
      expect(vm.bars.where((b) => b.isCurrent), hasLength(1));
      expect(vm.bars.last.isCurrent, isTrue);
    });

    test('all-zero weeks give zero heights (no divide by zero)', () {
      final vm = DashboardViewModel.from(
        _data(weekly: List.filled(8, 0)),
        now: now,
      );
      expect(vm.bars.every((b) => b.fraction == 0), isTrue);
    });

    test('axis label is the first week start; summary lists counts', () {
      final vm = DashboardViewModel.from(_data(), now: now);
      expect(vm.axisStart, '31 Aug');
      expect(
        vm.barsSummary,
        'Applications per week, last 8 weeks: 0, 1, 2, 0, 4, 1, 0, 2',
      );
    });

    test('a quiet account keeps the y scale at four', () {
      final vm = DashboardViewModel.from(
        _data(weekly: [0, 0, 0, 0, 0, 0, 0, 1]),
        now: now,
      );
      expect(vm.bars.last.fraction, 0.25);
    });

    test('the peak is the earliest busiest week; tooltips are labelled', () {
      final vm = DashboardViewModel.from(
        _data(weekly: [0, 3, 0, 3, 0, 0, 0, 2]),
        now: now,
      );
      expect(vm.bars.where((b) => b.isPeak).map((b) => b.count), [3]);
      expect(vm.bars[1].isPeak, isTrue);
      expect(vm.bars[1].tooltip, startsWith('3 · wk of '));
      expect(vm.bars.last.tooltip, '2 · this week');
    });
  });

  group('lists', () {
    test('upcoming interviews are capped at three', () {
      final vm = DashboardViewModel.from(
        _data(upcoming: [for (var i = 1; i <= 5; i++) _interview(i)]),
        now: now,
      );
      expect(vm.upcoming.map((i) => i.id), [1, 2, 3]);
    });

    test('recent activity is capped at five with relative times', () {
      final activity = [
        for (var i = 0; i < 7; i++)
          RecentActivity(
            applicationId: i + 1,
            companyName: 'Co$i',
            toStatus: ApplicationStatus.interview,
            changedAt: now.subtract(Duration(hours: 2 + i * 30)),
          ),
      ];
      final vm = DashboardViewModel.from(_data(activity: activity), now: now);
      expect(vm.activity, hasLength(5));
      expect(vm.activity.first.relativeTime, '2h ago');
      expect(vm.activity[1].relativeTime, '1d ago');
      expect(vm.activity.first.company, 'Co0');
    });
  });

  group('against the fake backend fixtures', () {
    test('summary numbers follow the seeded applications', () async {
      final backend = FakeBackend(latency: Duration.zero);
      final data = await FakeDashboardRepository(backend).load(timezone: 'UTC');
      final vm = DashboardViewModel.from(data, now: backend.now);

      final apps = backend.applications.values;
      expect(vm.total, apps.length);
      expect(vm.active, apps.where((a) => a.status.isActive).length);
      final responded = apps.where(
        (a) => a.status != ApplicationStatus.applied,
      );
      expect(
        vm.responsePercent,
        (100 * responded.length / apps.length).round(),
      );
      expect(vm.tiles.fold<int>(0, (s, t) => s + t.count), apps.length);
      for (final t in vm.tiles) {
        expect(t.count, apps.where((a) => a.status == t.status).length);
      }
    });
  });
}
