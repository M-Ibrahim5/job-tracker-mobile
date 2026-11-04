import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../domain/enums/enums.dart';
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
