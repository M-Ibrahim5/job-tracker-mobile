import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_filter.dart';
import 'package:jobtrail/features/applications/application/filter_labels.dart';
import 'package:jobtrail/features/dashboard/application/chart_logic.dart';

Map<ApplicationStatus, int> _counts(List<int> v) => {
  for (var i = 0; i < ApplicationStatus.values.length; i++)
    ApplicationStatus.values[i]: v[i],
};

void main() {
  group('applicationsUriForStatus', () {
    test('uses the camelCase status name', () {
      expect(
        applicationsUriForStatus(ApplicationStatus.applied).toString(),
        '/applications?status=applied',
      );
      expect(
        applicationsUriForStatus(ApplicationStatus.interview).toString(),
        '/applications?status=interview',
      );
    });
  });

  group('applicationsUriForWeek', () {
    test('runs Monday to Sunday', () {
      expect(
        applicationsUriForWeek(DateTime(2026, 10, 12)).toString(),
        '/applications?from=2026-10-12&to=2026-10-18',
      );
    });

    test('rolls over month and year ends', () {
      expect(
        applicationsUriForWeek(DateTime(2026, 8, 31)).toString(),
        '/applications?from=2026-08-31&to=2026-09-06',
      );
      expect(
        applicationsUriForWeek(DateTime(2024, 12, 30)).toString(),
        '/applications?from=2024-12-30&to=2025-01-05',
      );
    });

    test('is not shifted by daylight saving or the time of day', () {
      // US spring-forward week; a stray time-of-day must not leak through.
      expect(
        applicationsUriForWeek(DateTime(2026, 3, 9, 23, 30)).toString(),
        '/applications?from=2026-03-09&to=2026-03-15',
      );
      // European fall-back week.
      expect(
        applicationsUriForWeek(DateTime(2026, 10, 26)).toString(),
        '/applications?from=2026-10-26&to=2026-11-01',
      );
    });

    test('a leap-day week ends on the right date', () {
      expect(
        applicationsUriForWeek(DateTime(2028, 2, 28)).toString(),
        '/applications?from=2028-02-28&to=2028-03-05',
      );
    });
  });

  group('filterFromQuery', () {
    test('parses a single status', () {
      final f = filterFromQuery({'status': 'applied'});
      expect(f.statuses, {ApplicationStatus.applied});
      expect(f.appliedFrom, isNull);
    });

    test('parses several statuses and arrangements', () {
      final f = filterFromQuery({
        'status': 'screening,interview',
        'arrangement': 'remote,hybrid',
      });
      expect(f.statuses, {
        ApplicationStatus.screening,
        ApplicationStatus.interview,
      });
      expect(f.arrangements, {WorkArrangement.remote, WorkArrangement.hybrid});
    });

    test('parses an inclusive date range', () {
      final f = filterFromQuery({'from': '2026-10-12', 'to': '2026-10-18'});
      expect(f.appliedFrom, DateTime(2026, 10, 12));
      expect(f.appliedTo, DateTime(2026, 10, 18));
    });

    test('parses q and sort', () {
      final f = filterFromQuery({'q': ' flutter ', 'sort': 'companyAZ'});
      expect(f.query, 'flutter');
      expect(f.sort, ApplicationSort.companyAZ);
    });

    test('ignores unknown keys and invalid values', () {
      final f = filterFromQuery({
        'status': 'applied,bogus',
        'arrangement': 'moon',
        'from': '12/10/2026',
        'to': '2026-02-31',
        'sort': 'sideways',
        'page': '3',
      });
      expect(f.statuses, {ApplicationStatus.applied});
      expect(f.arrangements, isEmpty);
      expect(f.appliedFrom, isNull);
      expect(f.appliedTo, isNull);
      expect(f.sort, ApplicationSort.newest);
    });

    test('an inverted range is dropped', () {
      final f = filterFromQuery({'from': '2026-10-18', 'to': '2026-10-12'});
      expect(f.appliedFrom, isNull);
      expect(f.appliedTo, isNull);
    });

    test('nothing recognised gives the default filter', () {
      expect(filterFromQuery({'x': 'y'}), const ApplicationFilter());
      expect(hasFilterParams({'x': 'y'}), isFalse);
      expect(hasFilterParams({'from': '2026-10-12'}), isTrue);
    });

    test('a URI built from a filter parses back to it', () {
      final filter = ApplicationFilter(
        statuses: {ApplicationStatus.offer, ApplicationStatus.applied},
        arrangements: {WorkArrangement.remote},
        appliedFrom: DateTime(2026, 10, 12),
        appliedTo: DateTime(2026, 10, 18),
        query: 'dev',
        sort: ApplicationSort.companyAZ,
      );
      final uri = applicationsUriForFilter(filter);
      expect(filterFromQuery(uri.queryParameters), filter);
      expect(
        applicationsUriForFilter(const ApplicationFilter()).toString(),
        '/applications',
      );
    });
  });

  group('percentages', () {
    test('always sum to exactly 100', () {
      for (final v in [
        [9, 7, 8, 4, 6],
        [1, 1, 1, 0, 0],
        [1, 1, 1, 1, 1],
        [33, 33, 34, 0, 0],
        [1, 0, 0, 0, 0],
        [2, 3, 7, 11, 13],
      ]) {
        final p = percentages(_counts(v));
        expect(p.values.fold<int>(0, (a, b) => a + b), 100, reason: '$v');
      }
    });

    test('give the leftover points to the largest remainders', () {
      // 9/34 = 26.47, 7/34 = 20.59, 8/34 = 23.53, 4/34 = 11.76, 6/34 = 17.65
      final p = percentages(_counts([9, 7, 8, 4, 6]));
      expect(p.values.toList(), [26, 21, 23, 12, 18]);
    });

    test('never gives a share to an empty status', () {
      final p = percentages(_counts([1, 1, 1, 0, 0]));
      expect(p[ApplicationStatus.offer], 0);
      expect(p[ApplicationStatus.rejected], 0);
      expect(p.values.take(3).toList(), [34, 33, 33]);
    });

    test('all zero when there is nothing to share', () {
      final p = percentages(_counts([0, 0, 0, 0, 0]));
      expect(p.values.every((v) => v == 0), isTrue);
    });
  });

  group('axisMax and peakIndex', () {
    test('the scale never drops below four', () {
      expect(axisMax(const []), 4);
      expect(axisMax(const [0, 0, 1]), 4);
      expect(axisMax(const [4, 2]), 4);
    });

    test('grows with the busiest week', () {
      expect(axisMax(const [1, 7, 3]), 7);
    });

    test('the peak is the earliest of the busiest weeks', () {
      expect(peakIndex(const [0, 3, 1, 3]), 1);
      expect(peakIndex(const [2, 0, 0, 0, 0, 0, 0, 2]), 0);
    });

    test('there is no peak when every week is empty', () {
      expect(peakIndex(const [0, 0, 0]), isNull);
    });
  });

  group('weekTooltip', () {
    test('labels past, current and empty weeks', () {
      expect(
        weekTooltip(
          count: 4,
          weekStart: DateTime(2026, 10, 12),
          isCurrent: false,
        ),
        '4 · wk of 12 Oct',
      );
      expect(
        weekTooltip(
          count: 2,
          weekStart: DateTime(2026, 10, 19),
          isCurrent: true,
        ),
        '2 · this week',
      );
      expect(
        weekTooltip(
          count: 0,
          weekStart: DateTime(2026, 9, 7),
          isCurrent: false,
        ),
        '0 · wk of 7 Sep',
      );
    });
  });

  group('ringSegmentAt', () {
    const size = Size(200, 200);
    const counts = [1, 1, 2]; // quarter, quarter, half

    int? at(double dx, double dy) =>
        ringSegmentAt(Offset(100 + dx, 100 + dy), size, counts, holeRadius: 64);

    test('starts at 12 o\'clock and runs clockwise', () {
      expect(at(5, -80), 0); // just right of the top
      expect(at(80, 5), 1); // 3 o'clock is in the second quarter
      expect(at(0, 80), 2); // 6 o'clock
      expect(at(-80, 0), 2); // 9 o'clock
      expect(at(-5, -80), 2); // just left of the top closes the ring
    });

    test('misses the hole and the outside', () {
      expect(at(0, 0), isNull);
      expect(at(30, 30), isNull);
      expect(at(150, 0), isNull);
    });

    test('is null without data', () {
      expect(
        ringSegmentAt(const Offset(100, 20), size, const [], holeRadius: 64),
        isNull,
      );
    });
  });

  group('filter labels', () {
    test('caption for a single status', () {
      expect(
        listCaption(
          5,
          const ApplicationFilter(statuses: {ApplicationStatus.applied}),
        ),
        '5 Applied applications',
      );
    });

    test('caption for a week', () {
      expect(
        listCaption(
          3,
          ApplicationFilter(
            appliedFrom: DateTime(2026, 10, 12),
            appliedTo: DateTime(2026, 10, 18),
          ),
        ),
        '3 applications · 12–18 Oct',
      );
      expect(
        listCaption(
          3,
          ApplicationFilter(
            appliedFrom: DateTime(2026, 9, 28),
            appliedTo: DateTime(2026, 10, 4),
          ),
        ),
        '3 applications · 28 Sep – 4 Oct',
      );
    });

    test('caption falls back to the total', () {
      expect(listCaption(7, const ApplicationFilter()), '7 total');
    });

    test('chips describe each active criterion', () {
      final chips = activeFilterChips(
        ApplicationFilter(
          statuses: {ApplicationStatus.applied},
          arrangements: {WorkArrangement.remote},
          appliedFrom: DateTime(2026, 10, 12),
          appliedTo: DateTime(2026, 10, 18),
        ),
      );
      expect(chips.map((c) => c.label), [
        'Status: Applied',
        'Work: Remote',
        '12 Oct – 18 Oct',
      ]);
    });

    test('removing a chip clears only that criterion', () {
      final filter = ApplicationFilter(
        statuses: {ApplicationStatus.applied},
        appliedFrom: DateTime(2026, 10, 12),
        appliedTo: DateTime(2026, 10, 18),
      );
      final noDates = withoutFilter(filter, ActiveFilterKind.dates);
      expect(noDates.appliedFrom, isNull);
      expect(noDates.statuses, {ApplicationStatus.applied});
      expect(
        withoutFilter(filter, ActiveFilterKind.status).appliedFrom,
        DateTime(2026, 10, 12),
      );
    });
  });
}
