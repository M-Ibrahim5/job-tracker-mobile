import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_filter.dart';
import '../../../domain/models/job_application.dart';
import '../../../domain/models/page.dart';
import '../../applications/application/filter_labels.dart';
import '../application/chart_drilldown.dart';

/// What the user chose in a chart pop-up. The dashboard navigates after the
/// sheet has closed, so Back returns to the dashboard, not to the sheet.
sealed class DrillAction {
  const DrillAction();
}

/// A row was tapped: open that application.
class OpenApplicationAction extends DrillAction {
  /// Creates the action.
  const OpenApplicationAction(this.id);

  final int id;
}

/// "Open in Applications": the full, filtered list.
class OpenFullListAction extends DrillAction {
  /// Creates the action.
  const OpenFullListAction();
}

Future<DrillAction?> _showSheet(BuildContext context, Widget sheet) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<DrillAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: const Color(0x801B1E2B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
    builder: (_) => sheet,
  );
}

/// Pipeline pop-up: the applications currently in [status].
Future<DrillAction?> showStatusApplicationsSheet(
  BuildContext context,
  ApplicationStatus status,
) => _showSheet(context, StatusApplicationsSheet(status: status));

/// Weekly pop-up: what was sent in the week starting [monday], day by day.
Future<DrillAction?> showWeekApplicationsSheet(
  BuildContext context, {
  required DateTime monday,
  required bool isCurrent,
}) => _showSheet(
  context,
  WeekApplicationsSheet(monday: monday, isCurrent: isCurrent),
);

/// Sheet for one pipeline status: header with the status, then one row per
/// application (title, company, status).
class StatusApplicationsSheet extends ConsumerWidget {
  /// Creates the sheet.
  const StatusApplicationsSheet({required this.status, super.key});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = statusDrillFilter(status);
    final async = ref.watch(chartDrillDownProvider(filter));
    final style = StatusStyle.of(status, Theme.of(context).brightness);
    final total = async.valueOrNull?.total;
    return _SheetFrame(
      semanticsLabel: DashboardStrings.statusSheetLabel(status.label),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: style.chipBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(style.icon, color: style.chipText, size: 22),
      ),
      title: status.label,
      subtitle: total == null ? null : DashboardStrings.applicationCount(total),
      body: _Loaded(
        async: async,
        filter: filter,
        builder: (page) => page.items.isEmpty
            ? _Empty(DashboardStrings.noStatusApplications(status.label))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: page.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
                itemBuilder: (context, i) =>
                    DrillApplicationRow(application: page.items[i]),
              ),
      ),
      footerNote: _showingNote(async.valueOrNull?.items.length, total),
    );
  }
}

/// Sheet for one week: how that week's applications are doing now, then a
/// day-by-day timeline of what was sent.
class WeekApplicationsSheet extends ConsumerWidget {
  /// Creates the sheet.
  const WeekApplicationsSheet({
    required this.monday,
    required this.isCurrent,
    super.key,
  });

  final DateTime monday;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = weekDrillFilter(monday);
    final async = ref.watch(chartDrillDownProvider(filter));
    final scheme = Theme.of(context).colorScheme;
    final range = dateRangeCaption(filter.appliedFrom, filter.appliedTo) ?? '';
    final total = async.valueOrNull?.total;
    return _SheetFrame(
      semanticsLabel: DashboardStrings.weekSheetLabel(range),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.date_range_rounded,
          color: scheme.onPrimaryContainer,
          size: 22,
        ),
      ),
      title: isCurrent
          ? DashboardStrings.thisWeekTitle
          : DashboardStrings.weekOfTitle(DateFormat('d MMM').format(monday)),
      subtitle: total == null
          ? range
          : DashboardStrings.weekSubtitle(total, range),
      body: _Loaded(
        async: async,
        filter: filter,
        builder: (page) {
          if (page.items.isEmpty) {
            return const _Empty(DashboardStrings.noWeeklyData);
          }
          final days = groupByAppliedDay(page.items);
          return ListView(
            shrinkWrap: true,
            children: [
              OutcomeStrip(breakdown: statusBreakdown(page.items)),
              const SizedBox(height: Spacing.lg),
              for (var i = 0; i < days.length; i++)
                _DayGroup(day: days[i], isLast: i == days.length - 1),
            ],
          );
        },
      ),
      footerNote: _showingNote(async.valueOrNull?.items.length, total),
    );
  }
}

String? _showingNote(int? shown, int? total) =>
    shown != null && total != null && total > shown
    ? DashboardStrings.showingOf(shown, total)
    : null;

/// Handle, header (icon, title, subtitle, close), scrolling body and the
/// pinned "Open in Applications" button.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.semanticsLabel,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.footerNote,
  });

  final String semanticsLabel;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget body;
  final String? footerNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: semanticsLabel,
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
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                leading,
                const SizedBox(width: Spacing.md),
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
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: DashboardStrings.sheetClose,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            Flexible(child: body),
            const SizedBox(height: Spacing.md),
            if (footerNote != null) ...[
              Text(
                footerNote!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
            ],
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(const OpenFullListAction()),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text(DashboardStrings.openInApplications),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading, error (with Retry) or the loaded page.
class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.async,
    required this.filter,
    required this.builder,
  });

  final AsyncValue<Page<JobApplication>> async;
  final ApplicationFilter filter;
  final Widget Function(Page<JobApplication> page) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (async) {
      AsyncData(:final value) => builder(value),
      AsyncError() => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(DashboardStrings.drillLoadFailed),
            const SizedBox(height: Spacing.sm),
            TextButton(
              onPressed: () => ref.invalidate(chartDrillDownProvider(filter)),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One application in a pop-up: monogram, job title, company and status.
/// Tapping it opens the application.
class DrillApplicationRow extends StatelessWidget {
  /// Creates a row.
  const DrillApplicationRow({required this.application, super.key});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = application;
    void open() => Navigator.of(context).pop(OpenApplicationAction(a.id));
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: DashboardStrings.drillRowSemantics(
        a.jobTitle,
        a.companyName,
        a.status.label,
      ),
      onTap: open,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              // Narrow screen or large text: the status goes under the
              // company so the title keeps its room. (Decided from the screen,
              // not a LayoutBuilder: the week timeline measures intrinsics.)
              child: Builder(
                builder: (context) {
                  final stacked =
                      MediaQuery.sizeOf(context).width < 380 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.2;
                  final chip = StatusChip(status: a.status);
                  return Row(
                    children: [
                      CompanyMonogram(
                        companyName: a.companyName,
                        status: a.status,
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.jobTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              a.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (stacked) ...[
                              const SizedBox(height: Spacing.xs),
                              chip,
                            ],
                          ],
                        ),
                      ),
                      if (!stacked) ...[
                        const SizedBox(width: Spacing.sm),
                        chip,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Where they are now": one stacked bar with the current status of the
/// week's applications, plus a legend with the counts.
class OutcomeStrip extends StatelessWidget {
  /// Creates the strip.
  const OutcomeStrip({required this.breakdown, super.key});

  final List<(ApplicationStatus, int)> breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final summary = breakdown.map((e) => '${e.$2} ${e.$1.label}').join(' · ');
    return Semantics(
      label: '${DashboardStrings.whereTheyAreNow}: $summary',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DashboardStrings.whereTheyAreNow,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final (status, count) in breakdown)
                    Expanded(
                      flex: count,
                      child: Container(
                        key: ValueKey('outcome-${status.name}'),
                        margin: const EdgeInsets.only(right: 2),
                        color: StatusStyle.of(status, brightness).color,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.xs,
            children: [
              for (final (status, count) in breakdown)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: StatusStyle.of(status, brightness).color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count ${status.label}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One day of the week timeline: a dot on a vertical rail, the day label,
/// then that day's applications.
class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.isLast});

  final AppliedDay day;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${DateFormat('EEE d MMM').format(day.day)} · '
                    '${DashboardStrings.applicationCount(day.applications.length)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  for (final a in day.applications) ...[
                    DrillApplicationRow(application: a),
                    const SizedBox(height: Spacing.sm),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
