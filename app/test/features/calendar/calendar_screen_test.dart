import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/core/constants/dashboard_strings.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/calendar_event.dart';
import 'package:jobtrail/domain/repositories/misc_repositories.dart';
import 'package:jobtrail/features/calendar/application/calendar_logic.dart';
import 'package:jobtrail/features/calendar/application/calendar_providers.dart';
import 'package:jobtrail/features/calendar/presentation/calendar_screen.dart';
import 'package:jobtrail/features/calendar/presentation/calendar_widgets.dart';
import 'package:jobtrail/features/calendar/presentation/day_sheet.dart';
import 'package:jobtrail/features/calendar/presentation/job_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../applications/harness.dart';
import '../interviews/interviews_harness.dart';

final _today = DateTime(2026, 10, 27, 9);

CalendarEvent _event(
  CalendarEventType type,
  DateTime date, {
  int app = 12,
  int? interview,
  String title = 'Senior Flutter Developer',
  String company = 'Northwind Labs',
  DateTime? at,
  ApplicationStatus? status,
  InterviewType? interviewType,
}) => CalendarEvent(
  date: DateTime(date.year, date.month, date.day),
  type: type,
  applicationId: app,
  interviewId: interview,
  companyName: company,
  title: title,
  at: at,
  status: status,
  interviewType: interviewType,
);

final _events = [
  _event(
    CalendarEventType.interview,
    DateTime(2026, 10, 27),
    interview: 3,
    title: 'Technical interview · Round 2',
    at: DateTime(2026, 10, 27, 10),
    interviewType: InterviewType.video,
  ),
  _event(
    CalendarEventType.applied,
    DateTime(2026, 10, 27),
    app: 13,
    title: 'Backend Developer',
    company: 'Delta Corp',
  ),
  _event(
    CalendarEventType.statusChange,
    DateTime(2026, 10, 27),
    at: DateTime(2026, 10, 27, 8),
    status: ApplicationStatus.interview,
  ),
  _event(
    CalendarEventType.followUp,
    DateTime(2026, 10, 27),
    app: 14,
    title: 'Flutter Developer',
    company: 'Orbit Health',
    at: DateTime(2026, 10, 27, 9),
  ),
  _event(
    CalendarEventType.applied,
    DateTime(2026, 10, 28),
    app: 15,
    title: 'Mobile Engineer',
    company: 'Lumen Pay',
  ),
  _event(
    CalendarEventType.interview,
    DateTime(2026, 11, 5),
    interview: 4,
    title: 'Final round',
    at: DateTime(2026, 11, 5, 14),
  ),
];

/// Calendar repository serving [data] and recording every request.
class _Calendar implements CalendarRepository {
  _Calendar(this.data);

  final List<CalendarEvent> data;
  final calls = <({DateTime from, DateTime to, String tz})>[];
  Object? failNext;

  @override
  Future<List<CalendarEvent>> events({
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) async {
    calls.add((from: from, to: to, tz: timezone));
    final e = failNext;
    if (e != null) {
      failNext = null;
      throw e;
    }
    return [
      for (final ev in data)
        if (!ev.date.isBefore(from) && !ev.date.isAfter(to)) ev,
    ];
  }
}

class _Setup {
  _Setup({List<CalendarEvent>? events}) {
    fixture = InterviewFixture();
    calendar = _Calendar(events ?? _events);
  }

  late final InterviewFixture fixture;
  late final _Calendar calendar;

  List<Override> overrides([SharedPreferences? prefs]) => [
    ...fixture.overrides,
    calendarRepositoryProvider.overrideWithValue(calendar),
    if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
  ];
}

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<_Setup> _pump(
  WidgetTester tester, {
  _Setup? setup,
  SharedPreferences? prefs,
  DateTime Function()? today,
  Size size = const Size(390, 1000),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final s = setup ?? _Setup();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routedApp(
      CalendarScreen(today: today ?? () => _today),
      overrides: s.overrides(prefs ?? await _prefs()),
      textScale: textScale,
      brightness: brightness,
      routes: [
        GoRoute(
          path: '/interviews/new',
          builder: (_, st) => Scaffold(
            body: Text('NEW-INTERVIEW date=${st.uri.queryParameters['date']}'),
          ),
        ),
        GoRoute(
          path: '/applications/new',
          builder: (_, st) => Scaffold(
            body: Text(
              'NEW-APPLICATION appliedDate='
              '${st.uri.queryParameters['appliedDate']}',
            ),
          ),
        ),
        GoRoute(
          path: '/applications/:id',
          builder: (_, st) => Scaffold(
            body: Text(
              'APP-${st.pathParameters['id']} '
              'focus=${st.uri.queryParameters['focusInterview']}',
            ),
          ),
        ),
        GoRoute(
          path: '/interviews/:id',
          builder: (_, st) =>
              Scaffold(body: Text('INTERVIEW-${st.pathParameters['id']}')),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

Finder _dayCell(int day, {bool inMonth = true}) => find.byWidgetPredicate(
  (w) => w is DayCell && w.day.day == day && (!inMonth || !w.isOutside),
  description: 'DayCell($day)',
);

Finder _marker(CalendarEventType t) => find.byKey(ValueKey('marker-${t.name}'));

/// Taps a day and returns with its sheet open.
Future<void> _openDay(WidgetTester tester, int day) async {
  await tester.tap(_dayCell(day));
  await tester.pumpAndSettle();
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip(CalendarStrings.sheetClose));
  await tester.pumpAndSettle();
}

/// Selects a day and dismisses the sheet it opens.
Future<void> _tapDay(WidgetTester tester, int day) async {
  await _openDay(tester, day);
  await _closeSheet(tester);
}

Future<void> _tapFormat(WidgetTester tester, String label) async {
  await tester.ensureVisible(
    find.byType(SegmentedButton<CalendarFormat>, skipOffstage: false),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(SegmentedButton<CalendarFormat>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

TableCalendar<DayMarker> _table(WidgetTester tester) =>
    tester.widget(find.byType(TableCalendar<DayMarker>));

void main() {
  group('layout of the screen', () {
    testWidgets('title, Today, formats, grid, legend and FAB', (tester) async {
      await _pump(tester);

      expect(find.text(CalendarStrings.title), findsOneWidget);
      expect(find.text(CalendarStrings.today), findsOneWidget);
      for (final label in ['Month', '2 weeks', 'Week']) {
        expect(
          find.widgetWithText(SegmentedButton<CalendarFormat>, label),
          findsOneWidget,
        );
      }
      expect(find.text('October 2026'), findsOneWidget);
      expect(_table(tester).startingDayOfWeek, StartingDayOfWeek.monday);
      expect(find.text('Mon'), findsOneWidget);
      for (final l in [
        CalendarStrings.legendApplied,
        CalendarStrings.legendStatus,
        CalendarStrings.legendInterview,
        CalendarStrings.legendFollowUp,
      ]) {
        expect(
          find.descendant(
            of: find.byType(CalendarLegend),
            matching: find.text(l),
          ),
          findsOneWidget,
          reason: l,
        );
      }
      expect(
        find.widgetWithText(FloatingActionButton, CalendarStrings.fab),
        findsOneWidget,
      );
    });

    testWidgets('Today shows a calendar page with the current date', (
      tester,
    ) async {
      await _pump(tester);
      final page = find.byKey(const ValueKey('today-page'));
      expect(page, findsOneWidget);
      expect(
        find.descendant(of: page, matching: find.text('OCT')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: page, matching: find.text('27')),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Jump to today, Tuesday, October 27, 2026'),
        findsOneWidget,
      );
    });

    testWidgets('today has a ring and the selected day is filled', (
      tester,
    ) async {
      await _pump(tester);
      final cell = tester.widget<DayCell>(_dayCell(27));
      expect(cell.isToday, isTrue);
      expect(cell.isSelected, isTrue);

      await _tapDay(tester, 28);
      expect(tester.widget<DayCell>(_dayCell(28)).isSelected, isTrue);
      final old = tester.widget<DayCell>(_dayCell(27));
      expect(old.isSelected, isFalse);
      expect(old.isToday, isTrue);
    });
  });

  group('markers', () {
    testWidgets('each event type shows its dot, capped at three per day', (
      tester,
    ) async {
      await _pump(tester);
      // 27 Oct has four kinds of event: the lowest priority (applied) is cut.
      expect(_marker(CalendarEventType.interview), findsOneWidget);
      expect(_marker(CalendarEventType.followUp), findsOneWidget);
      expect(_marker(CalendarEventType.statusChange), findsOneWidget);
      // The only applied dot left is the one on 28 Oct.
      expect(_marker(CalendarEventType.applied), findsOneWidget);
    });

    testWidgets('interview dots are bigger than the others', (tester) async {
      await _pump(tester);
      double diameter(CalendarEventType t) =>
          tester.widget<Container>(_marker(t)).constraints!.maxWidth;
      expect(diameter(CalendarEventType.interview), 8);
      expect(diameter(CalendarEventType.followUp), 6);
      expect(diameter(CalendarEventType.applied), 6);
      expect(diameter(CalendarEventType.statusChange), 6);
    });

    testWidgets('dot colors follow the design', (tester) async {
      await _pump(tester);
      Color? color(CalendarEventType t) =>
          ((tester.widget<Container>(_marker(t))).decoration! as BoxDecoration)
              .color;
      expect(color(CalendarEventType.interview), const Color(0xFF8E24AA));
      expect(color(CalendarEventType.applied), const Color(0xFF1E88E5));
      expect(color(CalendarEventType.followUp), const Color(0xFF00897B));
      // Status-change dot uses the accent of the new status (Interview).
      expect(color(CalendarEventType.statusChange), const Color(0xFF8E24AA));
    });
  });

  group('day sheet', () {
    testWidgets('the inline day agenda is gone, the timeline stays', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Tuesday, 27 Oct'), findsNothing);
      expect(find.byType(DaySheet), findsNothing);
      expect(find.text(CalendarStrings.jobTimeline), findsOneWidget);
    });

    testWidgets('tapping a date opens the sheet with title and count', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 27);
      expect(find.text('Tue, 27 Oct 2026'), findsOneWidget);
      expect(find.text('4 events'), findsOneWidget);
      expect(tester.widget<DayCell>(_dayCell(27)).isSelected, isTrue);

      await _closeSheet(tester);
      await _openDay(tester, 28);
      expect(find.text('Wed, 28 Oct 2026'), findsOneWidget);
      expect(find.text('1 event'), findsOneWidget);
    });

    testWidgets('rows are ordered: timed first, then Applied, Status', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 27);
      // The 9:00 follow-up comes before the 10:00 interview.
      final order = [
        'FOLLOW-UP · 9:00 AM',
        'INTERVIEW · 10:00 AM',
        'APPLIED · ALL DAY',
        'STATUS CHANGE · ALL DAY',
      ];
      final ys = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('each type shows its label, title, subtitle and colour', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 27);

      expect(find.text('Technical interview · Round 2'), findsOneWidget);
      expect(find.text('Northwind Labs · Video'), findsOneWidget);
      expect(find.text('Orbit Health'), findsOneWidget);
      expect(find.text('Delta Corp'), findsOneWidget);
      expect(find.text('Northwind Labs · Moved to Interview'), findsOneWidget);

      Color edge(String label) {
        final row = find.ancestor(
          of: find.text(label),
          matching: find.byType(EventRow),
        );
        final strip = find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxWidth == 4,
          ),
        );
        return tester.widget<Container>(strip).color!;
      }

      expect(edge('INTERVIEW · 10:00 AM'), const Color(0xFF8E24AA));
      expect(edge('FOLLOW-UP · 9:00 AM'), const Color(0xFF00897B));
      expect(edge('STATUS CHANGE · ALL DAY'), const Color(0xFFFFA000));
      expect(edge('APPLIED · ALL DAY'), const Color(0xFF1E88E5));
      Color? labelColor(String t) =>
          tester.widget<Text>(find.text(t)).style?.color;
      expect(labelColor('INTERVIEW · 10:00 AM'), const Color(0xFF6A1B80));
      expect(labelColor('FOLLOW-UP · 9:00 AM'), const Color(0xFF00695C));
      expect(labelColor('STATUS CHANGE · ALL DAY'), const Color(0xFF7A4B00));
      expect(labelColor('APPLIED · ALL DAY'), const Color(0xFF0D47A1));
    });

    testWidgets('an empty day shows the message and both buttons', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 30);
      expect(find.text('No events'), findsOneWidget);
      expect(find.text(CalendarStrings.sheetEmptyTitle), findsOneWidget);
      expect(find.text(CalendarStrings.sheetEmptyMessage), findsOneWidget);
      expect(find.text(CalendarStrings.addInterview), findsOneWidget);
      expect(find.text(CalendarStrings.addApplication), findsOneWidget);
    });

    testWidgets('an interview row opens its application and focuses it', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 27);
      await tester.tap(find.text('Technical interview · Round 2'));
      await tester.pumpAndSettle();
      expect(find.byType(DaySheet), findsNothing);
      expect(find.text('APP-12 focus=3'), findsOneWidget);

      // Back returns to the calendar with the day selected, sheet closed.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DaySheet), findsNothing);
      expect(tester.widget<DayCell>(_dayCell(27)).isSelected, isTrue);
    });

    testWidgets('other rows open the application without a focus', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 27);
      await tester.tap(find.text('Orbit Health'));
      await tester.pumpAndSettle();
      expect(find.text('APP-14 focus=null'), findsOneWidget);
    });

    testWidgets('Add interview passes the tapped date', (tester) async {
      await _pump(tester);
      await _openDay(tester, 28);
      await tester.tap(find.text(CalendarStrings.addInterview));
      await tester.pumpAndSettle();
      expect(find.text('NEW-INTERVIEW date=2026-10-28'), findsOneWidget);
    });

    testWidgets('Add job application: a past day keeps its date', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 20);
      await tester.tap(find.text(CalendarStrings.addApplication));
      await tester.pumpAndSettle();
      expect(
        find.text('NEW-APPLICATION appliedDate=2026-10-20'),
        findsOneWidget,
      );
    });

    testWidgets('Add job application: a future day becomes today', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 30);
      await tester.tap(find.text(CalendarStrings.addApplication));
      await tester.pumpAndSettle();
      expect(
        find.text('NEW-APPLICATION appliedDate=2026-10-27'),
        findsOneWidget,
      );
    });

    testWidgets('the scrim closes the sheet and the date stays selected', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 28);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.byType(DaySheet), findsNothing);
      expect(tester.widget<DayCell>(_dayCell(28)).isSelected, isTrue);
    });

    testWidgets('tapping the selected date opens the sheet again', (
      tester,
    ) async {
      await _pump(tester);
      await _tapDay(tester, 28);
      await _openDay(tester, 28);
      expect(find.byType(DaySheet), findsOneWidget);
    });

    testWidgets('Today does not open the sheet', (tester) async {
      await _pump(tester);
      await _tapDay(tester, 28);
      await tester.tap(find.text(CalendarStrings.today));
      await tester.pumpAndSettle();
      expect(find.byType(DaySheet), findsNothing);
      expect(tester.widget<DayCell>(_dayCell(27)).isSelected, isTrue);
    });

    testWidgets('a muted day of the next month switches month and opens', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is DayCell &&
              w.isOutside &&
              w.day.month == 11 &&
              w.day.day == 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.byType(DaySheet), findsOneWidget);
      expect(find.text('Sun, 1 Nov 2026'), findsOneWidget);
    });

    testWidgets('a long day scrolls while the buttons stay visible', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 10; i++)
          _event(
            CalendarEventType.interview,
            DateTime(2026, 10, 29),
            app: 100 + i,
            interview: 100 + i,
            title: 'Round $i',
            at: DateTime(2026, 10, 29, 8 + i),
          ),
      ];
      await _pump(
        tester,
        setup: _Setup(events: many),
        size: const Size(390, 700),
      );
      await _openDay(tester, 29);
      expect(find.text('10 events'), findsOneWidget);
      expect(find.text(CalendarStrings.addApplication), findsOneWidget);
      expect(
        tester.getSize(find.byType(DaySheet)).height,
        lessThanOrEqualTo(700 * 0.75 + 1),
      );
    });

    testWidgets('rows and the sheet are announced for screen readers', (
      tester,
    ) async {
      await _pump(tester);
      await _openDay(tester, 27);
      expect(
        find.bySemanticsLabel(
          'Interview, 10:00 AM, Technical interview · Round 2, Northwind Labs',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Events on Tuesday, October 27, 2026'),
        findsOneWidget,
      );
    });

    testWidgets('fits 320px at 1.5x text in both themes', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          size: const Size(320, 700),
          textScale: 1.5,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        await _openDay(tester, 27);
        expect(tester.takeException(), isNull, reason: 'dark=$dark');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('formats', () {
    testWidgets('switching shows the matching number of weeks', (tester) async {
      await _pump(tester);
      int cells() => find.byType(DayCell).evaluate().length;
      expect(cells(), 35); // Sep 28 … Nov 1

      await _tapFormat(tester, '2 weeks');
      expect(cells(), 14);
      await _tapFormat(tester, 'Week');
      expect(_table(tester).calendarFormat, CalendarFormat.week);
      expect(cells(), 7);
      await _tapFormat(tester, 'Month');
      expect(cells(), 35);
    });

    testWidgets('the last format is remembered', (tester) async {
      final prefs = await _prefs();
      await _pump(tester, prefs: prefs);
      await _tapFormat(tester, '2 weeks');
      expect(prefs.getString(kCalendarFormatKey), 'twoWeeks');

      // A fresh screen (new app launch) starts in the stored format.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, prefs: prefs, setup: _Setup());
      expect(_table(tester).calendarFormat, CalendarFormat.twoWeeks);
      final selected = tester.widget<SegmentedButton<CalendarFormat>>(
        find.byType(SegmentedButton<CalendarFormat>),
      );
      expect(selected.selected, {CalendarFormat.twoWeeks});
    });

    testWidgets('defaults to month when nothing is stored', (tester) async {
      await _pump(tester);
      expect(_table(tester).calendarFormat, CalendarFormat.month);
    });

    testWidgets('an unknown stored value falls back to month', (tester) async {
      final prefs = await _prefs({kCalendarFormatKey: 'decade'});
      await _pump(tester, prefs: prefs);
      expect(_table(tester).calendarFormat, CalendarFormat.month);
    });
  });

  group('loading events', () {
    testWidgets('one padded request per month, cached afterwards', (
      tester,
    ) async {
      final s = await _pump(tester);
      expect(s.calendar.calls, hasLength(1));
      final call = s.calendar.calls.single;
      expect(call.tz, 'UTC');
      expect(call.from, DateTime(2026, 9, 21));
      expect(call.to, DateTime(2026, 11, 8));
      expect(call.to.difference(call.from).inDays + 1, lessThanOrEqualTo(70));

      // Other formats of the same month and day changes reuse the cache.
      await _tapFormat(tester, 'Week');
      await _tapFormat(tester, 'Month');
      await _tapDay(tester, 28);
      expect(s.calendar.calls, hasLength(1));
    });

    testWidgets('paging to the next month fetches it once', (tester) async {
      final s = await _pump(tester);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(s.calendar.calls, hasLength(2));
      expect(s.calendar.calls.last.from, DateTime(2026, 10, 19));

      // The 5 Nov interview has its dot, and so does 27 Oct, which the
      // November grid still shows as an outside day.
      expect(_marker(CalendarEventType.interview), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(s.calendar.calls, hasLength(2), reason: 'October is cached');
    });

    testWidgets('Today returns to the current month', (tester) async {
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CalendarStrings.today));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(tester.widget<DayCell>(_dayCell(27)).isSelected, isTrue);
    });

    testWidgets('a failure shows a banner; Retry reloads', (tester) async {
      final s = _Setup()..calendar.failNext = const NetworkFailure();
      await _pump(tester, setup: s);
      expect(find.text(CalendarStrings.loadFailed), findsOneWidget);
      expect(s.calendar.calls, hasLength(1), reason: 'no retry loop');

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text(CalendarStrings.loadFailed), findsNothing);
      expect(_marker(CalendarEventType.interview), findsOneWidget);
    });

    testWidgets('pull to refresh reloads the visible month', (tester) async {
      final s = await _pump(tester);
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(s.calendar.calls, hasLength(2));
    });

    testWidgets('data changes elsewhere clear the cache', (tester) async {
      final s = await _pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarScreen)),
      );
      container.read(dataRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();
      expect(s.calendar.calls, hasLength(2));
    });
  });

  group('quick add', () {
    testWidgets('the FAB opens a new interview on the selected day', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('NEW-INTERVIEW date=2026-10-27'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tapDay(tester, 30);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('NEW-INTERVIEW date=2026-10-30'), findsOneWidget);
    });
  });

  group('job timeline mode', () {
    Future<void> pickCompany(WidgetTester tester, String query) async {
      await tester.ensureVisible(find.text(CalendarStrings.pickJob));
      await tester.tap(find.text(CalendarStrings.pickJob));
      await tester.pumpAndSettle();
      expect(find.text(CalendarStrings.pickJobTitle), findsOneWidget);
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
    }

    testWidgets('search, pick, see the timeline and highlighted days', (
      tester,
    ) async {
      // Use the real clock so the fixture's relative dates fall in view.
      await _pump(tester, today: DateTime.now, size: const Size(390, 1600));

      await pickCompany(tester, 'northwind');
      expect(find.text('Helio Systems'), findsNothing, reason: 'filtered');
      await tester.tap(find.text('Northwind Labs'));
      await tester.pumpAndSettle();

      // The picker card now shows the company, role and current status.
      final card = find.byKey(const ValueKey('job-picker-selected'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Northwind Labs')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(StatusChip)),
        findsOneWidget,
      );
      expect(find.byType(JobTimelineList), findsOneWidget);
      for (final t in ['Applied', 'Screening', 'Interview']) {
        expect(
          find.descendant(
            of: find.byType(JobTimelineList),
            matching: find.text(t),
          ),
          findsWidgets,
          reason: t,
        );
      }
      // The scheduled round is in the future and marked as such.
      expect(
        find.descendant(
          of: find.byType(JobTimelineList),
          matching: find.text('Technical interview · Round 2'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Upcoming'), findsOneWidget);

      final highlighted = tester
          .widgetList<DayCell>(find.byType(DayCell))
          .where((c) => c.isTimeline);
      expect(highlighted, isNotEmpty);
    });

    testWidgets('clearing leaves the mode and removes the highlight', (
      tester,
    ) async {
      await _pump(tester, today: DateTime.now, size: const Size(390, 1600));
      await pickCompany(tester, 'northwind');
      await tester.tap(find.text('Northwind Labs'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(CalendarStrings.clearTimeline));
      await tester.pumpAndSettle();

      expect(find.byType(JobTimelineList), findsNothing);
      expect(find.byKey(const ValueKey('job-picker-empty')), findsOneWidget);
      expect(
        tester
            .widgetList<DayCell>(find.byType(DayCell))
            .any((c) => c.isTimeline),
        isFalse,
      );
    });

    testWidgets('the selected card can change the job', (tester) async {
      await _pump(tester, today: DateTime.now, size: const Size(390, 1600));
      await pickCompany(tester, 'northwind');
      await tester.tap(find.text('Northwind Labs'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(CalendarStrings.changeJob));
      await tester.pumpAndSettle();
      expect(find.text(CalendarStrings.pickJobTitle), findsOneWidget);
    });

    testWidgets('an unmatched search says so', (tester) async {
      await _pump(tester);
      await pickCompany(tester, 'zzzz');
      expect(find.text(CalendarStrings.noJobs), findsOneWidget);
    });
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets('fits 320px at 1.5x text (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        await _pump(
          tester,
          size: const Size(320, 700),
          textScale: 1.5,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
        await _tapFormat(tester, 'Week');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
