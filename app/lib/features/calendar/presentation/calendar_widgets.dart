import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/job_application.dart';
import '../application/calendar_logic.dart';

/// Dot color of [marker] for the current theme.
Color markerColor(DayMarker marker, Brightness brightness) =>
    switch (marker.type) {
      CalendarEventType.applied => StatusStyle.of(
        ApplicationStatus.applied,
        brightness,
      ).color,
      CalendarEventType.statusChange => StatusStyle.of(
        marker.status ?? ApplicationStatus.applied,
        brightness,
      ).color,
      CalendarEventType.interview => StatusStyle.of(
        ApplicationStatus.interview,
        brightness,
      ).color,
      CalendarEventType.followUp => StatusStyle.followUpColor,
    };

/// Row of up to three dots under a day number.
class MarkerDots extends StatelessWidget {
  /// Creates the dots.
  const MarkerDots({required this.markers, super.key});

  final List<DayMarker> markers;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in markers)
          Container(
            key: ValueKey('marker-${m.type.name}'),
            width: m.size,
            height: m.size,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: markerColor(m, brightness),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// One day cell: today ring, selected fill, muted outside days and an
/// underline while the day belongs to the shown job timeline.
class DayCell extends StatelessWidget {
  /// Creates a cell.
  const DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isOutside,
    required this.isTimeline,
    super.key,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;
  final bool isTimeline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timelineColor = StatusStyle.of(
      ApplicationStatus.interview,
      Theme.of(context).brightness,
    ).color;
    final textColor = isSelected
        ? scheme.onPrimary
        : isOutside
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : scheme.onSurface;
    return Center(
      child: Semantics(
        label: DateFormat.yMMMMEEEEd().format(day),
        selected: isSelected,
        excludeSemantics: true,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? scheme.primary : null,
            shape: BoxShape.circle,
            border: isToday && !isSelected
                ? Border.all(color: scheme.primary, width: 2)
                : isTimeline
                ? Border.all(color: timelineColor, width: 2)
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: isToday || isSelected
                    ? FontWeight.w800
                    : FontWeight.w600,
                decoration: isTimeline ? TextDecoration.underline : null,
                decorationColor: timelineColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Legend row under the grid.
class CalendarLegend extends StatelessWidget {
  /// Creates the legend.
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(DayMarker m, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: m.size,
          height: m.size,
          decoration: BoxDecoration(
            // A status-change dot takes the color of the status it moved to,
            // so its legend swatch shows all of them instead of just one.
            color: m.type == CalendarEventType.statusChange
                ? null
                : markerColor(m, theme.brightness),
            gradient: m.type == CalendarEventType.statusChange
                ? SweepGradient(
                    colors: [
                      for (final s in ApplicationStatus.values)
                        StatusStyle.of(s, theme.brightness).color,
                      StatusStyle.of(
                        ApplicationStatus.values.first,
                        theme.brightness,
                      ).color,
                    ],
                  )
                : null,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: theme.textTheme.bodySmall)),
      ],
    );
    return Wrap(
      spacing: Spacing.lg,
      runSpacing: Spacing.sm,
      children: [
        item(
          const DayMarker(CalendarEventType.applied),
          CalendarStrings.legendApplied,
        ),
        item(
          const DayMarker(
            CalendarEventType.statusChange,
            status: ApplicationStatus.screening,
          ),
          CalendarStrings.legendStatus,
        ),
        item(
          const DayMarker(CalendarEventType.interview),
          CalendarStrings.legendInterview,
        ),
        item(
          const DayMarker(CalendarEventType.followUp),
          CalendarStrings.legendFollowUp,
        ),
      ],
    );
  }
}

/// "Today" pill with a small calendar page showing today's month and day.
class TodayButton extends StatelessWidget {
  /// Creates the button.
  const TodayButton({required this.today, required this.onPressed, super.key});

  final DateTime today;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: CalendarStrings.todayTooltip(
        DateFormat.yMMMMEEEEd().format(today),
      ),
      child: Material(
        color: scheme.secondaryContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.minTouch),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CalendarPage(date: today),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    CalendarStrings.today,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny tear-off calendar page: coloured month band over the day number.
class _CalendarPage extends StatelessWidget {
  const _CalendarPage({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('today-page'),
        width: 30,
        height: 32,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.18),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 11,
              width: double.infinity,
              color: scheme.primary,
              alignment: Alignment.center,
              child: Text(
                DateFormat.MMM().format(date).toUpperCase(),
                style: TextStyle(
                  fontSize: 7.5,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: scheme.onPrimary,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the application whose journey is shown on the calendar: a dashed
/// "Choose a job" card when none is picked, otherwise a card with the
/// company, role and status, plus change and clear actions.
class JobTimelinePicker extends StatelessWidget {
  /// Creates the picker.
  const JobTimelinePicker({
    required this.job,
    required this.onPick,
    required this.onClear,
    super.key,
  });

  final JobApplication? job;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            CalendarStrings.jobTimeline,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        if (job == null)
          _EmptyJobCard(onPick: onPick)
        else
          _SelectedJobCard(job: job!, onPick: onPick, onClear: onClear),
      ],
    );
  }
}

class _EmptyJobCard extends StatelessWidget {
  const _EmptyJobCard({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DashedBorder(
      color: scheme.outline,
      radius: Radii.card,
      strokeWidth: 1.5,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('job-picker-empty'),
          onTap: onPick,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CalendarStrings.pickJob,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        CalendarStrings.pickJobHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedJobCard extends StatelessWidget {
  const _SelectedJobCard({
    required this.job,
    required this.onPick,
    required this.onClear,
  });

  final JobApplication job;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('job-picker-selected'),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.xs,
            Spacing.sm,
          ),
          child: Row(
            children: [
              CompanyMonogram(
                companyName: job.companyName,
                status: job.status,
                size: 40,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      job.jobTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    StatusChip(status: job.status),
                  ],
                ),
              ),
              IconButton(
                tooltip: CalendarStrings.changeJob,
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: onPick,
              ),
              IconButton(
                tooltip: CalendarStrings.clearTimeline,
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
