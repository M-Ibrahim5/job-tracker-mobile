import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/calendar_event.dart';
import '../application/calendar_logic.dart';
import '../application/calendar_providers.dart';

/// What the user chose in the day sheet. The caller navigates after the sheet
/// has closed so Back returns to the calendar, not to the sheet.
sealed class DayAction {
  const DayAction();
}

/// A row was tapped.
class OpenEventAction extends DayAction {
  /// Creates the action.
  const OpenEventAction(this.event);

  final CalendarEvent event;
}

/// "Add interview" was tapped.
class AddInterviewAction extends DayAction {
  /// Creates the action.
  const AddInterviewAction();
}

/// "Add job application" was tapped.
class AddApplicationAction extends DayAction {
  /// Creates the action.
  const AddApplicationAction();
}

/// Opens the sheet listing the events of [date]; resolves to the chosen action
/// or null when it was dismissed.
Future<DayAction?> showDaySheet(BuildContext context, DateTime date) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<DayAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: const Color(0x801B1E2B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    // Reduced motion: no slide.
    sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
    builder: (_) => DaySheet(date: date),
  );
}

/// Accent (left edge) of an event row.
Color eventEdgeColor(CalendarEventType type, Brightness brightness) =>
    switch (type) {
      CalendarEventType.interview => StatusStyle.of(
        ApplicationStatus.interview,
        brightness,
      ).color,
      CalendarEventType.followUp => StatusStyle.followUpColor,
      CalendarEventType.statusChange => StatusStyle.of(
        ApplicationStatus.screening,
        brightness,
      ).color,
      CalendarEventType.applied => StatusStyle.of(
        ApplicationStatus.applied,
        brightness,
      ).color,
    };

/// Text color of an event row's label: a darker shade of the edge colour in
/// light mode, a lighter one in dark mode.
Color eventLabelColor(CalendarEventType type, Brightness brightness) {
  if (brightness == Brightness.dark) {
    return Color.lerp(eventEdgeColor(type, brightness), Colors.white, 0.6)!;
  }
  return switch (type) {
    CalendarEventType.interview => const Color(0xFF6A1B80),
    CalendarEventType.followUp => StatusStyle.followUpText,
    CalendarEventType.statusChange => const Color(0xFF7A4B00),
    CalendarEventType.applied => const Color(0xFF0D47A1),
  };
}

String _typeName(CalendarEventType type) => switch (type) {
  CalendarEventType.interview => CalendarStrings.typeInterview,
  CalendarEventType.followUp => CalendarStrings.typeFollowUp,
  CalendarEventType.statusChange => CalendarStrings.typeStatusChange,
  CalendarEventType.applied => CalendarStrings.typeApplied,
};

/// "10:00 AM", or "All day" for untimed rows.
String eventTimeText(CalendarEvent e) => isTimedEvent(e)
    ? DateFormat.jm().format(e.at!).replaceAll(' ', ' ')
    : CalendarStrings.allDay;

/// Subtitle under an event row's title.
String eventSubtitle(CalendarEvent e) => switch (e.type) {
  CalendarEventType.interview => [
    e.companyName,
    ?e.interviewType?.label,
  ].join(' · '),
  CalendarEventType.statusChange =>
    e.status == null
        ? e.companyName
        : '${e.companyName} · ${CalendarStrings.movedTo(e.status!.label)}',
  CalendarEventType.applied || CalendarEventType.followUp => e.companyName,
};

/// Bottom sheet with the events of one day and the two add buttons.
class DaySheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [date].
  const DaySheet({required this.date, super.key});

  final DateTime date;

  @override
  ConsumerState<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<DaySheet> {
  void _ensureLoaded() {
    final key = monthKey(widget.date);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(calendarEventsProvider.notifier).ensure([key]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(calendarDayProvider(widget.date));
    final events = async.valueOrNull;
    if (async.isLoading) _ensureLoaded();

    final title = DateFormat('EEE, d MMM y').format(widget.date);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: CalendarStrings.sheetLabel(
        DateFormat.yMMMMEEEEd().format(widget.date),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (events != null)
                          Text(
                            CalendarStrings.eventCount(events.length),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: CalendarStrings.sheetClose,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: switch (async) {
                AsyncData(:final value) when value.isEmpty => const _EmptyDay(),
                AsyncData(:final value) => ListView.separated(
                  shrinkWrap: true,
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => EventRow(
                    event: value[i],
                    onTap: () =>
                        Navigator.of(context).pop(OpenEventAction(value[i])),
                  ),
                ),
                AsyncError() => _LoadError(
                  onRetry: () => ref
                      .read(calendarEventsProvider.notifier)
                      .refresh([monthKey(widget.date)]),
                ),
                _ => const Padding(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
            ),
            const SizedBox(height: Spacing.md),
            _SheetButton(
              icon: Icons.add_rounded,
              label: CalendarStrings.addInterview,
              onPressed: () =>
                  Navigator.of(context).pop(const AddInterviewAction()),
            ),
            const SizedBox(height: 10),
            _SheetButton(
              icon: Icons.work_outline_rounded,
              label: CalendarStrings.addApplication,
              onPressed: () =>
                  Navigator.of(context).pop(const AddApplicationAction()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_outlined,
              size: 28,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            CalendarStrings.sheetEmptyTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            CalendarStrings.sheetEmptyMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(CalendarStrings.loadFailed),
          const SizedBox(height: Spacing.sm),
          TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}

/// One event of the day: coloured left edge, label line, title, subtitle.
class EventRow extends StatelessWidget {
  /// Creates a row.
  const EventRow({required this.event, required this.onTap, super.key});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final e = event;
    final edge = eventEdgeColor(e.type, brightness);
    final labelColor = eventLabelColor(e.type, brightness);
    final label = '${_typeName(e.type)} · ${eventTimeText(e)}';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$label, ${e.title}, ${e.companyName}'.replaceFirst(' · ', ', '),
      onTap: onTap,
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: edge),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: labelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            eventSubtitle(e),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
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
