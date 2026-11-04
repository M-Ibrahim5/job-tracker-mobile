import 'package:table_calendar/table_calendar.dart' show CalendarFormat;

import '../../../core/utils/date_helpers.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_extras.dart';
import '../../../domain/models/calendar_event.dart';

/// Most dots shown under one day.
const int kMaxDayMarkers = 3;

/// Extra days fetched around a month grid so the edges stay filled.
const int kFetchPaddingDays = 7;

/// Inclusive range of calendar days.
typedef DayRange = ({DateTime from, DateTime to});

/// Days shown by the calendar for [format] around [focusedDay], weeks starting
/// on Monday (month: the full weeks of the grid; 2 weeks: the focused week and
/// the next; week: the focused week).
DayRange visibleRange(CalendarFormat format, DateTime focusedDay) {
  final focused = DateHelpers.dayOnly(focusedDay);
  switch (format) {
    case CalendarFormat.week:
      final start = DateHelpers.startOfWeek(focused);
      return (from: start, to: _addDays(start, 6));
    case CalendarFormat.twoWeeks:
      final start = DateHelpers.startOfWeek(focused);
      return (from: start, to: _addDays(start, 13));
    case CalendarFormat.month:
      final first = DateTime(focused.year, focused.month, 1);
      final last = DateTime(focused.year, focused.month + 1, 0);
      return (
        from: DateHelpers.startOfWeek(first),
        to: _addDays(DateHelpers.startOfWeek(last), 6),
      );
  }
}

DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Cache key of a month, e.g. `2026-10`.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// First day of the month of [key].
DateTime monthOfKey(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

/// Months whose events are needed to draw [range].
List<String> monthsForRange(DayRange range) {
  final keys = <String>[];
  var cursor = DateTime(range.from.year, range.from.month);
  final end = DateTime(range.to.year, range.to.month);
  while (!cursor.isAfter(end)) {
    keys.add(monthKey(cursor));
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return keys;
}

/// Months that must be loaded to draw [format] around [focusedDay]. A month's
/// padded fetch already covers its whole grid and the adjacent days, so most
/// views need a single request.
List<String> requiredMonths(CalendarFormat format, DateTime focusedDay) {
  final base = monthKey(focusedDay);
  final range = visibleRange(format, focusedDay);
  final covered = fetchRangeForMonth(base);
  if (!range.from.isBefore(covered.from) && !range.to.isAfter(covered.to)) {
    return [base];
  }
  return monthsForRange(range);
}

/// Range requested from the server for the month [key]: its grid plus
/// [kFetchPaddingDays] on each side (at most 56 days, under the API's 70).
DayRange fetchRangeForMonth(String key) {
  final grid = visibleRange(CalendarFormat.month, monthOfKey(key));
  return (
    from: _addDays(grid.from, -kFetchPaddingDays),
    to: _addDays(grid.to, kFetchPaddingDays),
  );
}

/// Events keyed by local calendar day (midnight), each day sorted by time of
/// day with untimed events first.
Map<DateTime, List<CalendarEvent>> groupEventsByDay(
  Iterable<CalendarEvent> events,
) {
  final map = <DateTime, List<CalendarEvent>>{};
  for (final e in events) {
    map.putIfAbsent(DateHelpers.dayOnly(e.date), () => []).add(e);
  }
  for (final list in map.values) {
    list.sort((a, b) {
      if (a.at == null && b.at == null) return 0;
      if (a.at == null) return -1;
      if (b.at == null) return 1;
      return a.at!.compareTo(b.at!);
    });
  }
  return map;
}

/// A dot under a day.
class DayMarker {
  /// Creates a marker.
  const DayMarker(this.type, {this.status});

  final CalendarEventType type;

  /// Accent source for status-change dots.
  final ApplicationStatus? status;

  /// Dot diameter: interviews are emphasized.
  double get size => type == CalendarEventType.interview ? 8 : 6;

  @override
  bool operator ==(Object other) =>
      other is DayMarker && other.type == type && other.status == status;

  @override
  int get hashCode => Object.hash(type, status);
}

/// Display priority when a day has more than [kMaxDayMarkers] kinds of event.
const _markerPriority = [
  CalendarEventType.interview,
  CalendarEventType.followUp,
  CalendarEventType.statusChange,
  CalendarEventType.applied,
];

/// Up to [kMaxDayMarkers] dots for a day: one per event type, interviews
/// first, then follow-ups, status changes and applications.
List<DayMarker> markersForDay(Iterable<CalendarEvent> events) {
  final markers = <DayMarker>[];
  for (final type in _markerPriority) {
    final match = events.where((e) => e.type == type);
    if (match.isEmpty) continue;
    markers.add(
      DayMarker(
        type,
        status: type == CalendarEventType.statusChange
            ? match.first.status
            : null,
      ),
    );
    if (markers.length == kMaxDayMarkers) break;
  }
  return markers;
}

/// Stable id of an event, used to break ordering ties.
int _eventId(CalendarEvent e) => e.interviewId ?? e.applicationId;

/// Whether [e] has a time of day. Applied and status-change events are always
/// all-day, whatever timestamp the server attached.
bool isTimedEvent(CalendarEvent e) =>
    e.at != null &&
    (e.type == CalendarEventType.interview ||
        e.type == CalendarEventType.followUp);

/// Orders one day's events for the day sheet: timed items first (earliest
/// first), then all-day Applied, Status change and untimed Follow-up items by
/// company name. Ties fall back to the id so the order is stable.
List<CalendarEvent> sortDayEvents(Iterable<CalendarEvent> events) {
  int allDayRank(CalendarEventType t) => switch (t) {
    CalendarEventType.applied => 0,
    CalendarEventType.statusChange => 1,
    CalendarEventType.followUp => 2,
    CalendarEventType.interview => 3,
  };
  return events.toList()..sort((a, b) {
    final aTimed = isTimedEvent(a);
    final bTimed = isTimedEvent(b);
    if (aTimed != bTimed) return aTimed ? -1 : 1;
    var c = 0;
    if (aTimed) {
      c = a.at!.compareTo(b.at!);
    } else {
      c = allDayRank(a.type).compareTo(allDayRank(b.type));
      if (c == 0) {
        c = a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase());
      }
    }
    return c != 0 ? c : _eventId(a).compareTo(_eventId(b));
  });
}

/// `appliedDate` the Add application form starts with after tapping [tapped]:
/// the tapped day, or [today] when it lies in the future.
DateTime appliedDateForTap(DateTime tapped, DateTime today) {
  final day = DateHelpers.dayOnly(tapped);
  final now = DateHelpers.dayOnly(today);
  return day.isAfter(now) ? now : day;
}

/// One row of the job timeline.
class TimelineItem {
  /// Creates an item.
  const TimelineItem({
    required this.at,
    required this.status,
    required this.isInterview,
    required this.upcoming,
    required this.title,
    this.subtitle,
    this.interviewId,
  });

  final DateTime at;

  /// Status the row stands for (interviews use [ApplicationStatus.interview]).
  final ApplicationStatus status;
  final bool isInterview;

  /// True for interviews that haven't happened yet (drawn outlined).
  final bool upcoming;
  final String title;
  final String? subtitle;
  final int? interviewId;
}

/// Merges status history and interviews into one chronological list.
List<TimelineItem> timelineItems(ApplicationTimeline timeline, DateTime now) {
  final items = <TimelineItem>[
    for (final h in timeline.history)
      TimelineItem(
        at: h.changedAt,
        status: h.toStatus,
        isInterview: false,
        upcoming: false,
        title: h.toStatus.label,
        subtitle: h.note,
      ),
    for (final i in timeline.interviews)
      TimelineItem(
        at: i.scheduledAt,
        status: ApplicationStatus.interview,
        isInterview: true,
        upcoming: i.scheduledAt.isAfter(now),
        title: i.title,
        subtitle: i.type.label,
        interviewId: i.id,
      ),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return items;
}

/// Calendar days to highlight while a job timeline is shown.
Set<DateTime> timelineDates(ApplicationTimeline timeline) => {
  for (final h in timeline.history) DateHelpers.dayOnly(h.changedAt),
  for (final i in timeline.interviews) DateHelpers.dayOnly(i.scheduledAt),
};
