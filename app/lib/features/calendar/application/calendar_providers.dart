import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart' show CalendarFormat;

import '../../../app/providers.dart';
import '../../../core/services/device_timezone.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../domain/models/application_extras.dart';
import '../../../domain/models/calendar_event.dart';
import '../../../domain/models/job_application.dart';
import '../../applications/application/application_providers.dart';
import '../../interviews/application/interviews_providers.dart';
import 'calendar_logic.dart';

/// `shared_preferences` key of the last used calendar format.
const kCalendarFormatKey = 'calendar_format';

/// Last chosen Month / 2 weeks / Week format, remembered on the device.
class CalendarFormatController extends StateNotifier<CalendarFormat> {
  /// Reads the stored format (month by default).
  CalendarFormatController(this._ref) : super(_initial(_ref));

  final Ref _ref;

  static CalendarFormat _initial(Ref ref) {
    final name = ref
        .read(sharedPreferencesProvider)
        ?.getString(kCalendarFormatKey);
    return CalendarFormat.values.firstWhere(
      (f) => f.name == name,
      orElse: () => CalendarFormat.month,
    );
  }

  /// Switches the format and remembers it.
  void set(CalendarFormat format) {
    state = format;
    _ref
        .read(sharedPreferencesProvider)
        ?.setString(kCalendarFormatKey, format.name);
  }
}

/// Provider for [CalendarFormatController].
final calendarFormatProvider =
    StateNotifierProvider<CalendarFormatController, CalendarFormat>(
      CalendarFormatController.new,
    );

/// Events cached per month.
class CalendarEventsState {
  /// Creates a state.
  const CalendarEventsState({
    this.months = const {},
    this.loading = const {},
    this.error,
  });

  /// Loaded months (`2026-10`) and their events.
  final Map<String, List<CalendarEvent>> months;

  /// Months currently being fetched.
  final Set<String> loading;

  /// Last fetch failure; cleared by a refresh.
  final Object? error;

  /// Events of every loaded month, without duplicates from overlapping
  /// padding.
  List<CalendarEvent> get all {
    final seen = <String>{};
    return [
      for (final list in months.values)
        for (final e in list)
          if (seen.add(
            '${e.type.name}|${e.date.toIso8601String()}|${e.applicationId}|'
            '${e.interviewId}|${e.at?.toIso8601String()}|${e.status?.name}',
          ))
            e,
    ];
  }

  /// Whether all of [keys] are loaded.
  bool hasAll(Iterable<String> keys) => keys.every(months.containsKey);

  /// Whether any of [keys] is being fetched.
  bool isLoadingAny(Iterable<String> keys) => keys.any(loading.contains);

  /// Returns a copy with the given fields replaced.
  CalendarEventsState copyWith({
    Map<String, List<CalendarEvent>>? months,
    Set<String>? loading,
    Object? error,
    bool clearError = false,
  }) => CalendarEventsState(
    months: months ?? this.months,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Loads calendar events month by month and keeps them cached. Everything is
/// dropped when applications, interviews or all data change.
class CalendarEventsNotifier extends Notifier<CalendarEventsState> {
  int _generation = 0;

  @override
  CalendarEventsState build() {
    ref.watch(dataRevisionProvider);
    ref.watch(applicationsRevisionProvider);
    ref.watch(interviewsRevisionProvider);
    _generation++;
    return const CalendarEventsState();
  }

  /// Fetches the given [months] that aren't cached yet.
  Future<void> ensure(List<String> months) async {
    final missing = [
      for (final key in months)
        if (!state.months.containsKey(key) && !state.loading.contains(key)) key,
    ];
    if (missing.isEmpty || state.error != null) return;
    await Future.wait(missing.map(_load));
  }

  Future<void> _load(String key) async {
    final generation = _generation;
    state = state.copyWith(loading: {...state.loading, key});
    try {
      final tz = await ref.read(deviceTimezoneProvider)();
      final range = fetchRangeForMonth(key);
      final events = await ref
          .read(calendarRepositoryProvider)
          .events(from: range.from, to: range.to, timezone: tz);
      if (generation != _generation) return;
      state = state.copyWith(
        months: {...state.months, key: events},
        loading: {...state.loading}..remove(key),
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        error: e,
        loading: {...state.loading}..remove(key),
      );
    }
  }

  /// Drops the cache and reloads [months] (pull-to-refresh, Retry).
  Future<void> refresh(List<String> months) async {
    _generation++;
    state = const CalendarEventsState();
    await ensure(months);
  }
}

/// Provider for [CalendarEventsNotifier].
final calendarEventsProvider =
    NotifierProvider<CalendarEventsNotifier, CalendarEventsState>(
      CalendarEventsNotifier.new,
    );

/// Events of one day for the day sheet, derived from [calendarEventsProvider].
/// Loading while the month holding the day isn't cached; an error when the
/// fetch failed.
final calendarDayProvider = Provider.autoDispose
    .family<AsyncValue<List<CalendarEvent>>, DateTime>((ref, date) {
      final day = DateHelpers.dayOnly(date);
      final state = ref.watch(calendarEventsProvider);
      final loaded = state.months.keys.any((key) {
        final range = fetchRangeForMonth(key);
        return !day.isBefore(range.from) && !day.isAfter(range.to);
      });
      if (!loaded) {
        return state.error != null
            ? AsyncValue.error(state.error!, StackTrace.empty)
            : const AsyncValue.loading();
      }
      return AsyncValue.data(
        sortDayEvents(groupEventsByDay(state.all)[day] ?? const []),
      );
    });

/// Application whose job timeline is shown, or null for the normal calendar.
final timelineApplicationProvider = StateProvider<JobApplication?>(
  (ref) => null,
);

/// Status history and interviews of one application.
final applicationTimelineProvider = FutureProvider.autoDispose
    .family<ApplicationTimeline, int>((ref, id) {
      ref.watch(dataRevisionProvider);
      ref.watch(applicationsRevisionProvider);
      ref.watch(interviewsRevisionProvider);
      return ref.watch(jobApplicationRepositoryProvider).timeline(id);
    });
