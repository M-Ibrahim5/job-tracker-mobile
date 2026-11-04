import '../../../core/constants/app_constants.dart';
import '../../../domain/enums/enums.dart';

/// Whether to offer moving an application to Interview when its first
/// interview is added: only from Applied / Screening and only when the
/// application has no interviews yet. Offered, never forced.
bool shouldSuggestInterviewStatus({
  required ApplicationStatus status,
  required int existingInterviews,
}) =>
    existingInterviews == 0 &&
    (status == ApplicationStatus.applied ||
        status == ApplicationStatus.screening);

/// Whether [scheduledAt] is not after [now] (shows a non-blocking warning).
bool isPastSchedule(DateTime scheduledAt, DateTime now) =>
    !scheduledAt.isAfter(now);

/// Combines a calendar [date] and a time of day into a local [DateTime].
DateTime combineDateAndTime(DateTime date, int hour, int minute) =>
    DateTime(date.year, date.month, date.day, hour, minute);

/// Most reminders an interview may have (server limit).
const int kMaxReminderOffsets = 5;

/// Longest allowed reminder lead time (30 days, server limit).
const Duration kMaxReminderOffset = Duration(minutes: 43200);

/// Preset reminder offsets offered as chips.
const List<Duration> kPresetReminderOffsets = [
  Duration(days: 1),
  Duration(hours: 1),
  Duration(minutes: 15),
];

/// Durations offered as chips.
const List<int> kDurationChoices = [30, 45, 60, 90];

/// "1 day before", "2 hours before", "90 min before"…
String reminderOffsetLabel(Duration d) {
  final minutes = d.inMinutes;
  String unit(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';
  if (minutes % 1440 == 0) {
    return '${unit(minutes ~/ 1440, 'day', 'days')} before';
  }
  if (minutes % 60 == 0) {
    return '${unit(minutes ~/ 60, 'hour', 'hours')} before';
  }
  return '$minutes min before';
}

/// Error for a custom reminder lead time, or null when valid.
String? validateReminderMinutes(int? minutes) {
  if (minutes == null || minutes < 1) return AppStrings.errRequired;
  if (minutes > kMaxReminderOffset.inMinutes) {
    return 'At most ${kMaxReminderOffset.inMinutes} minutes (30 days)';
  }
  return null;
}
