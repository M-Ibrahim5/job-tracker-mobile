import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/models/job_application.dart';
import '../../interviews/application/interviews_providers.dart';
import '../application/calendar_logic.dart';

/// Bottom sheet with a search box listing applications; resolves to the chosen
/// one.
Future<JobApplication?> showJobPicker(BuildContext context) {
  return showModalBottomSheet<JobApplication>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _JobPickerSheet(),
  );
}

class _JobPickerSheet extends ConsumerStatefulWidget {
  const _JobPickerSheet();

  @override
  ConsumerState<_JobPickerSheet> createState() => _JobPickerSheetState();
}

class _JobPickerSheetState extends ConsumerState<_JobPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(applicationOptionsProvider);
    final all = async.valueOrNull ?? const <JobApplication>[];
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all
              .where(
                (a) =>
                    a.companyName.toLowerCase().contains(q) ||
                    a.jobTitle.toLowerCase().contains(q),
              )
              .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.screen),
              child: Text(
                CalendarStrings.pickJobTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.screen),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: CalendarStrings.searchJobs,
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: async.isLoading && all.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : async.hasError && all.isEmpty
                  ? ErrorState(
                      error: async.error,
                      onRetry: () => ref.invalidate(applicationOptionsProvider),
                    )
                  : shown.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: CalendarStrings.noJobs,
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final a = shown[i];
                        return ListTile(
                          minTileHeight: Sizes.minTouch,
                          title: Text(
                            a.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            a.jobTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(a),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical list Applied → Screening → Interview … with upcoming interviews
/// drawn outlined.
class JobTimelineList extends StatelessWidget {
  /// Creates the list.
  const JobTimelineList({
    required this.items,
    required this.onOpenInterview,
    super.key,
  });

  final List<TimelineItem> items;
  final ValueChanged<int> onOpenInterview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Text(
        CalendarStrings.timelineEmpty,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _Row(
            item: items[i],
            isLast: i == items.length - 1,
            onTap: items[i].interviewId == null
                ? null
                : () => onOpenInterview(items[i].interviewId!),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.isLast, this.onTap});

  final TimelineItem item;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StatusStyle.of(item.status, theme.brightness);
    final filled = !item.upcoming;
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: filled ? style.chipBackground : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: style.color, width: 2),
                    ),
                    child: Icon(style.icon, size: 16, color: style.chipText),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: theme.textTheme.titleSmall),
                    Text(
                      [
                        DateHelpers.formatDateTime(item.at),
                        if (item.upcoming) CalendarStrings.upcomingMarker,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if ((item.subtitle ?? '').isNotEmpty)
                      Text(item.subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
