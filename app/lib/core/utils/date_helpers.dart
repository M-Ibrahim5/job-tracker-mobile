import 'package:intl/intl.dart';

/// Date / time formatting and arithmetic helpers.
abstract final class DateHelpers {
  static final _date = DateFormat.yMMMd();
  static final _dateTime = DateFormat.yMMMd().add_jm();

  /// e.g. "Oct 24, 2026".
  static String formatDate(DateTime d) => _date.format(d);

  /// e.g. "Oct 24, 2026 3:30 PM".
  static String formatDateTime(DateTime d) => _dateTime.format(d);

  /// Midnight of [d] in local time.
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whether both dates fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Monday of the week containing [d].
  static DateTime startOfWeek(DateTime d) =>
      dayOnly(d).subtract(Duration(days: d.weekday - DateTime.monday));

  /// Short relative text such as "just now", "2h ago", "3d ago".
  static String relative(DateTime then, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(then);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(then);
  }

  /// Times at which reminders fire for an event at [eventTime], dropping any
  /// that are not strictly after [now]. Sorted ascending, de-duplicated.
  static List<DateTime> reminderTimes(
    DateTime eventTime,
    Iterable<Duration> offsets, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final times =
        offsets
            .map(eventTime.subtract)
            .where((t) => t.isAfter(current))
            .toSet()
            .toList()
          ..sort();
    return times;
  }
}
