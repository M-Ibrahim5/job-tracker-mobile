import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/utils/api_date.dart';
import 'package:jobtrail/core/utils/date_helpers.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_extras.dart';
import 'package:jobtrail/domain/models/calendar_event.dart';
import 'package:jobtrail/domain/models/interview.dart';
import 'package:jobtrail/domain/models/status_history_entry.dart';
import 'package:jobtrail/features/calendar/application/calendar_logic.dart';
import 'package:table_calendar/table_calendar.dart' show CalendarFormat;

CalendarEvent _e(
  CalendarEventType type, {
  DateTime? date,
  DateTime? at,
  ApplicationStatus? status,
  int app = 1,
  int? interview,
}) => CalendarEvent(
  date: date ?? DateTime(2026, 10, 27),
  type: type,
  applicationId: app,
  interviewId: interview,
  companyName: 'Acme',
  title: 'T',
  status: status,
  at: at,
);

void main() {
  group('visibleRange', () {
    test('month: whole Monday-first weeks around October 2026', () {
      // 1 Oct 2026 is a Thursday, 31 Oct a Saturday.
      final r = visibleRange(CalendarFormat.month, DateTime(2026, 10, 14, 15));
      expect(r.from, DateTime(2026, 9, 28));
      expect(r.to, DateTime(2026, 11, 1));
      expect(r.from.weekday, DateTime.monday);
      expect(r.to.weekday, DateTime.sunday);
    });

    test('month: a month that starts on Monday and ends on Sunday', () {
      // June 2026: Mon 1 Jun … Tue 30 Jun → ends Sun 5 Jul.
      final r = visibleRange(CalendarFormat.month, DateTime(2026, 6, 20));
      expect(r.from, DateTime(2026, 6, 1));
      expect(r.to, DateTime(2026, 7, 5));
      // Feb 2027: Mon 1 Feb … Sun 28 Feb exactly four weeks.
      final feb = visibleRange(CalendarFormat.month, DateTime(2027, 2, 10));
      expect(feb.from, DateTime(2027, 2, 1));
      expect(feb.to, DateTime(2027, 2, 28));
    });

    test('month: year boundary', () {
      final r = visibleRange(CalendarFormat.month, DateTime(2026, 12, 31));
      expect(r.from, DateTime(2026, 11, 30));
      expect(r.to, DateTime(2027, 1, 3));
    });

    test('week and two weeks start on the Monday of the focused day', () {
      final week = visibleRange(
        CalendarFormat.week,
        DateTime(2026, 10, 25),
      ); // Sunday
      expect(week.from, DateTime(2026, 10, 19));
      expect(week.to, DateTime(2026, 10, 25));

      final two = visibleRange(CalendarFormat.twoWeeks, DateTime(2026, 10, 21));
      expect(two.from, DateTime(2026, 10, 19));
      expect(two.to, DateTime(2026, 11, 1));
    });

    test('is not thrown off by a time of day or daylight saving', () {
      final r = visibleRange(
        CalendarFormat.week,
        DateTime(2026, 3, 29, 23, 59),
      );
      expect(r.from.hour, 0);
      expect(r.to.hour, 0);
      expect(r.to.difference(r.from).inDays, anyOf(5, 6));
    });
  });

  group('month cache helpers', () {
    test('monthsForRange lists every touched month', () {
      expect(
        monthsForRange(
          visibleRange(CalendarFormat.month, DateTime(2026, 10, 14)),
        ),
        ['2026-09', '2026-10', '2026-11'],
      );
      expect(
        monthsForRange(
          visibleRange(CalendarFormat.week, DateTime(2026, 10, 14)),
        ),
        ['2026-10'],
      );
      expect(
        monthsForRange(
          visibleRange(CalendarFormat.twoWeeks, DateTime(2026, 10, 27)),
        ),
        ['2026-10', '2026-11'],
      );
    });

    test('most views need a single month request', () {
      for (final f in CalendarFormat.values) {
        expect(requiredMonths(f, DateTime(2026, 10, 27)), [
          '2026-10',
        ], reason: f.name);
      }
      // A week that straddles two months is still inside the padded fetch.
      expect(requiredMonths(CalendarFormat.week, DateTime(2026, 11, 2)), [
        '2026-11',
      ]);
    });

    test('keys round trip', () {
      expect(monthKey(DateTime(2026, 3, 9)), '2026-03');
      expect(monthOfKey('2026-03'), DateTime(2026, 3));
    });

    test('a month fetch stays within the 70 day API limit', () {
      for (var m = 1; m <= 12; m++) {
        final r = fetchRangeForMonth(monthKey(DateTime(2026, m)));
        final days = r.to.difference(r.from).inDays + 1;
        expect(days, lessThanOrEqualTo(70), reason: 'month $m');
        // The padded range still covers the whole grid.
        final grid = visibleRange(CalendarFormat.month, DateTime(2026, m));
        expect(r.from.isBefore(grid.from), isTrue);
        expect(r.to.isAfter(grid.to), isTrue);
      }
    });
  });

  group('groupEventsByDay', () {
    test('groups by calendar day and sorts by time, untimed first', () {
      final a = _e(CalendarEventType.interview, at: DateTime(2026, 10, 27, 14));
      final b = _e(CalendarEventType.followUp, at: DateTime(2026, 10, 27, 9));
      final c = _e(CalendarEventType.applied);
      final other = _e(
        CalendarEventType.applied,
        date: DateTime(2026, 10, 28, 5, 30),
      );

      final map = groupEventsByDay([a, b, c, other]);
      expect(map.keys, {DateTime(2026, 10, 27), DateTime(2026, 10, 28)});
      expect(map[DateTime(2026, 10, 27)], [c, b, a]);
      expect(map[DateTime(2026, 10, 28)], [
        other,
      ], reason: 'time of day ignored in key');
    });

    test('no events, no groups', () {
      expect(groupEventsByDay(const []), isEmpty);
    });
  });

  group('markersForDay', () {
    test('one dot per type', () {
      final markers = markersForDay([
        _e(CalendarEventType.interview),
        _e(CalendarEventType.interview, interview: 2),
        _e(CalendarEventType.applied),
      ]);
      expect(markers.map((m) => m.type), [
        CalendarEventType.interview,
        CalendarEventType.applied,
      ]);
    });

    test('at most three, dropping the lowest priority (applied)', () {
      final markers = markersForDay([
        _e(CalendarEventType.applied),
        _e(CalendarEventType.statusChange, status: ApplicationStatus.screening),
        _e(CalendarEventType.followUp),
        _e(CalendarEventType.interview),
      ]);
      expect(markers, hasLength(3));
      expect(markers.map((m) => m.type), [
        CalendarEventType.interview,
        CalendarEventType.followUp,
        CalendarEventType.statusChange,
      ]);
    });

    test('status-change dots carry the status; interviews are bigger', () {
      final markers = markersForDay([
        _e(CalendarEventType.statusChange, status: ApplicationStatus.offer),
        _e(CalendarEventType.interview),
        _e(CalendarEventType.followUp),
        _e(CalendarEventType.applied),
      ]);
      expect(markers.map((m) => m.size), [8, 6, 6]);
      expect(markers.last.status, ApplicationStatus.offer);
    });

    test('empty day has no dots', () {
      expect(markersForDay(const []), isEmpty);
    });
  });

  group('sortDayEvents', () {
    CalendarEvent ev(
      CalendarEventType type, {
      DateTime? at,
      String company = 'Acme',
      int app = 1,
      int? interview,
    }) => CalendarEvent(
      date: DateTime(2026, 10, 27),
      type: type,
      applicationId: app,
      interviewId: interview,
      companyName: company,
      title: 'T',
      at: at,
    );

    test('timed first (earliest first), then Applied, then Status change', () {
      final late = ev(
        CalendarEventType.interview,
        at: DateTime(2026, 10, 27, 15),
        interview: 1,
      );
      final early = ev(
        CalendarEventType.followUp,
        at: DateTime(2026, 10, 27, 8),
        app: 2,
      );
      final status = ev(CalendarEventType.statusChange, company: 'Alpha');
      final appliedB = ev(CalendarEventType.applied, company: 'Beta', app: 3);
      final appliedA = ev(CalendarEventType.applied, company: 'Alpha', app: 4);

      expect(sortDayEvents([status, appliedB, late, appliedA, early]), [
        early,
        late,
        appliedA,
        appliedB,
        status,
      ]);
    });

    test('a status change with a timestamp still counts as all day', () {
      final timed = ev(
        CalendarEventType.interview,
        at: DateTime(2026, 10, 27, 20),
        interview: 1,
      );
      final status = ev(
        CalendarEventType.statusChange,
        at: DateTime(2026, 10, 27, 7),
      );
      expect(isTimedEvent(status), isFalse);
      expect(sortDayEvents([status, timed]), [timed, status]);
    });

    test('ties are broken by id, whatever the input order', () {
      final at = DateTime(2026, 10, 27, 10);
      final a = ev(CalendarEventType.interview, at: at, interview: 2);
      final b = ev(CalendarEventType.interview, at: at, interview: 9);
      expect(sortDayEvents([b, a]), [a, b]);
      expect(sortDayEvents([a, b]), [a, b]);
    });
  });

  group('time-zone bucketing', () {
    test(
      'an instant parsed from UTC is a local time, then bucketed locally',
      () {
        final at = ApiDate.parseUtc('2026-10-27T23:30:00Z');
        expect(at.isUtc, isFalse);
        final expected = DateTime.utc(2026, 10, 27, 23, 30).toLocal();
        expect(DateHelpers.dayOnly(at), DateHelpers.dayOnly(expected));
        final byDay = groupEventsByDay([
          CalendarEvent(
            date: DateHelpers.dayOnly(at),
            type: CalendarEventType.interview,
            applicationId: 1,
            interviewId: 1,
            companyName: 'Acme',
            title: 'T',
            at: at,
          ),
        ]);
        expect(byDay.keys.single, DateHelpers.dayOnly(expected));
      },
    );
  });

  group('appliedDateForTap', () {
    final today = DateTime(2026, 10, 27, 15);
    test('past and today keep the tapped date', () {
      expect(
        appliedDateForTap(DateTime(2026, 10, 20), today),
        DateTime(2026, 10, 20),
      );
      expect(
        appliedDateForTap(DateTime(2026, 10, 27), today),
        DateTime(2026, 10, 27),
      );
    });
    test('the future becomes today', () {
      expect(
        appliedDateForTap(DateTime(2026, 11, 2), today),
        DateTime(2026, 10, 27),
      );
    });
  });

  group('job timeline', () {
    final now = DateTime(2026, 10, 25, 12);
    final timeline = ApplicationTimeline(
      history: [
        StatusHistoryEntry(
          id: 1,
          applicationId: 1,
          toStatus: ApplicationStatus.applied,
          changedAt: DateTime(2026, 10, 20, 9),
        ),
        StatusHistoryEntry(
          id: 2,
          applicationId: 1,
          fromStatus: ApplicationStatus.applied,
          toStatus: ApplicationStatus.screening,
          changedAt: DateTime(2026, 10, 22, 9),
          note: 'Called',
        ),
      ],
      interviews: [
        Interview(
          id: 7,
          applicationId: 1,
          title: 'Round 2',
          type: InterviewType.video,
          scheduledAt: DateTime(2026, 10, 28, 10),
        ),
        Interview(
          id: 6,
          applicationId: 1,
          title: 'Round 1',
          type: InterviewType.phone,
          scheduledAt: DateTime(2026, 10, 23, 10),
        ),
      ],
    );

    test('merges history and interviews chronologically', () {
      final items = timelineItems(timeline, now);
      expect(items.map((i) => i.title), [
        'Applied',
        'Screening',
        'Round 1',
        'Round 2',
      ]);
      expect(items[1].subtitle, 'Called');
    });

    test('only future interviews are upcoming', () {
      final items = timelineItems(timeline, now);
      expect(items.map((i) => i.upcoming), [false, false, false, true]);
      expect(items.where((i) => i.isInterview).map((i) => i.interviewId), [
        6,
        7,
      ]);
    });

    test('highlight dates cover history and interviews', () {
      expect(timelineDates(timeline), {
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 22),
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 28),
      });
    });
  });
}
