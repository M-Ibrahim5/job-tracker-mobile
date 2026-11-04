import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../core/utils/api_date.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/calendar_event.dart';
import '../application/calendar_logic.dart';
import '../application/calendar_providers.dart';
import 'calendar_widgets.dart';
import 'day_sheet.dart';
import 'job_timeline.dart';

/// Calendar tab (`/calendar`).
class CalendarScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [today] is injectable for tests.
  const CalendarScreen({this.today, super.key});

  final DateTime Function()? today;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focused;
  late DateTime _selected;

  DateTime get _now => (widget.today ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _focused = _selected = DateHelpers.dayOnly(_now);
  }

  void _toToday() {
    final today = DateHelpers.dayOnly(_now);
    setState(() => _focused = _selected = today);
  }

  /// Selects [day], shows its sheet and, once the sheet has closed, performs
  /// the chosen action so Back returns to the calendar with the sheet closed.
  Future<void> _openDay(DateTime day) async {
    final action = await showDaySheet(context, day);
    if (!mounted || action == null) return;
    final Future<Object?> pushed;
    switch (action) {
      case OpenEventAction(:final event):
        pushed = context.push(
          Routes.applicationDetail(
            event.applicationId,
            focusInterview: event.type == CalendarEventType.interview
                ? event.interviewId
                : null,
          ),
        );
      case AddInterviewAction():
        pushed = context.push(
          '${Routes.newInterview}?date=${ApiDate.toDateOnly(day)}',
        );
      case AddApplicationAction():
        pushed = context.push(
          '${Routes.newApplication}?appliedDate='
          '${ApiDate.toDateOnly(appliedDateForTap(day, _now))}',
        );
    }
    unawaited(pushed);
  }

  Future<void> _pickJob() async {
    final picked = await showJobPicker(context);
    if (picked != null && mounted) {
      ref.read(timelineApplicationProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = ref.watch(calendarFormatProvider);
    final events = ref.watch(calendarEventsProvider);
    final job = ref.watch(timelineApplicationProvider);
    final timeline = job == null
        ? null
        : ref.watch(applicationTimelineProvider(job.id));
    final timelineData = timeline?.valueOrNull;

    final months = requiredMonths(format, _focused);
    if (!events.hasAll(months) &&
        !events.isLoadingAny(months) &&
        events.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(calendarEventsProvider.notifier).ensure(months);
      });
    }

    final byDay = groupEventsByDay(events.all);
    final highlighted = timelineData == null
        ? const <DateTime>{}
        : timelineDates(timelineData);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Several tabs stay alive at once; shared hero tags would clash.
        heroTag: null,
        onPressed: () => context.push(
          '${Routes.newInterview}?date=${ApiDate.toDateOnly(_selected)}',
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(CalendarStrings.fab),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(calendarEventsProvider.notifier).refresh(months),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              Spacing.screen,
              Spacing.lg,
              Spacing.screen,
              88,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        CalendarStrings.title,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _toToday,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, Sizes.minTouch),
                    ),
                    child: const Text(CalendarStrings.today),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              SegmentedChoice<CalendarFormat>(
                values: const [
                  CalendarFormat.month,
                  CalendarFormat.twoWeeks,
                  CalendarFormat.week,
                ],
                selected: format,
                labelOf: (f) => switch (f) {
                  CalendarFormat.month => CalendarStrings.formatMonth,
                  CalendarFormat.twoWeeks => CalendarStrings.formatTwoWeeks,
                  CalendarFormat.week => CalendarStrings.formatWeek,
                },
                onChanged: (f) =>
                    ref.read(calendarFormatProvider.notifier).set(f),
              ),
              if (events.loading.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (events.error != null) ...[
                const SizedBox(height: Spacing.md),
                NoticeBanner(
                  message: CalendarStrings.loadFailed,
                  icon: Icons.error_outline_rounded,
                  actionLabel: AppStrings.retry,
                  onAction: () =>
                      ref.read(calendarEventsProvider.notifier).refresh(months),
                ),
              ],
              const SizedBox(height: Spacing.sm),
              _Grid(
                focused: _focused,
                selected: _selected,
                format: format,
                today: DateHelpers.dayOnly(_now),
                byDay: byDay,
                highlighted: highlighted,
                onSelected: (selected, _) {
                  // The grid keeps its month when a muted day is tapped; follow
                  // the tapped day so the visible month changes to it.
                  setState(
                    () => _selected = _focused = DateHelpers.dayOnly(selected),
                  );
                  _openDay(_selected);
                },
                onPageChanged: (focused) =>
                    setState(() => _focused = DateHelpers.dayOnly(focused)),
              ),
              const SizedBox(height: Spacing.md),
              const CalendarLegend(),
              const SizedBox(height: Spacing.lg),
              _TimelinePicker(
                job: job?.companyName,
                onPick: _pickJob,
                onClear: () =>
                    ref.read(timelineApplicationProvider.notifier).state = null,
              ),
              if (job != null) ...[
                const SizedBox(height: Spacing.md),
                if (timelineData != null)
                  JobTimelineList(
                    items: timelineItems(timelineData, _now),
                    onOpenInterview: (id) =>
                        context.push(Routes.interviewDetail(id)),
                  )
                else if (timeline?.hasError ?? false)
                  const Text(CalendarStrings.loadFailed)
                else
                  const SkeletonBox(height: 96, radius: Radii.card),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.focused,
    required this.selected,
    required this.format,
    required this.today,
    required this.byDay,
    required this.highlighted,
    required this.onSelected,
    required this.onPageChanged,
  });

  final DateTime focused;
  final DateTime selected;
  final CalendarFormat format;
  final DateTime today;
  final Map<DateTime, List<CalendarEvent>> byDay;
  final Set<DateTime> highlighted;
  final void Function(DateTime selected, DateTime focused) onSelected;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TableCalendar<DayMarker>(
      firstDay: DateTime(2020),
      lastDay: DateTime(2040, 12, 31),
      focusedDay: focused,
      calendarFormat: format,
      availableCalendarFormats: const {
        CalendarFormat.month: CalendarStrings.formatMonth,
        CalendarFormat.twoWeeks: CalendarStrings.formatTwoWeeks,
        CalendarFormat.week: CalendarStrings.formatWeek,
      },
      startingDayOfWeek: StartingDayOfWeek.monday,
      selectedDayPredicate: (d) => isSameDay(d, selected),
      currentDay: today,
      onDaySelected: onSelected,
      onPageChanged: onPageChanged,
      eventLoader: (d) =>
          markersForDay(byDay[DateHelpers.dayOnly(d)] ?? const []),
      rowHeight: 54,
      daysOfWeekHeight: 28,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        leftChevronIcon: const Icon(
          Icons.chevron_left,
          semanticLabel: CalendarStrings.previous,
        ),
        rightChevronIcon: const Icon(
          Icons.chevron_right,
          semanticLabel: CalendarStrings.next,
        ),
        titleCentered: true,
        titleTextStyle: theme.textTheme.titleMedium!,
        headerPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: theme.textTheme.labelMedium!,
        weekendStyle: theme.textTheme.labelMedium!,
      ),
      calendarStyle: const CalendarStyle(outsideDaysVisible: true),
      calendarBuilders: CalendarBuilders<DayMarker>(
        // The title is tappable inside the package, so it gets a full 48dp.
        headerTitleBuilder: (context, day) => SizedBox(
          height: Sizes.minTouch,
          child: Center(
            child: Text(
              DateFormat.yMMMM().format(day),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        prioritizedBuilder: (context, day, focusedDay) => DayCell(
          day: day,
          isToday: isSameDay(day, today),
          isSelected: isSameDay(day, selected),
          isOutside:
              format == CalendarFormat.month && day.month != focusedDay.month,
          isTimeline: highlighted.contains(DateHelpers.dayOnly(day)),
        ),
        markerBuilder: (context, day, markers) => markers.isEmpty
            ? null
            : Positioned(bottom: 2, child: MarkerDots(markers: markers)),
      ),
    );
  }
}

class _TimelinePicker extends StatelessWidget {
  const _TimelinePicker({
    required this.job,
    required this.onPick,
    required this.onClear,
  });

  final String? job;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            CalendarStrings.jobTimeline,
            style: theme.textTheme.titleMedium,
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.work_outline_rounded, size: 18),
          label: Text('${job ?? CalendarStrings.pickJob} ▾'),
          onPressed: onPick,
        ),
        if (job != null)
          IconButton(
            tooltip: CalendarStrings.clearTimeline,
            icon: const Icon(Icons.close_rounded),
            onPressed: onClear,
          ),
      ],
    );
  }
}
