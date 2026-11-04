import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/interview.dart';
import '../../../domain/models/job_application.dart';
import '../../../domain/models/status_history_entry.dart';
import '../../interviews/application/interviews_providers.dart';
import '../application/status_flow.dart';
import 'application_card.dart';
import 'dashed_border.dart';

/// Title block: status chip, title, company and info chips.
class DetailHeader extends StatelessWidget {
  /// Creates the header.
  const DetailHeader({required this.application, super.key});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = application;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusChip(status: a.status),
        const SizedBox(height: Spacing.md),
        Hero(
          tag: applicationTitleHeroTag(a.id),
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              a.jobTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          a.companyName,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            _InfoChip(icon: Icons.place_outlined, text: a.location),
            _InfoChip(
              icon: Icons.apartment_rounded,
              text: a.workArrangement.label,
            ),
            if (a.employmentType != null)
              _InfoChip(
                icon: Icons.badge_outlined,
                text: a.employmentType!.label,
              ),
            if (a.salaryRange != null && a.salaryRange!.trim().isNotEmpty)
              _InfoChip(icon: Icons.payments_outlined, text: a.salaryRange!),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading (17/700) with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  /// Creates a heading.
  const SectionTitle(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Three tonal quick-action tiles.
class QuickActions extends StatelessWidget {
  /// Creates the row; a null callback disables its tile.
  const QuickActions({
    required this.onOpenLink,
    required this.onAddInterview,
    required this.onFollowUp,
    this.followUpSet = false,
    this.busy = false,
    super.key,
  });

  final VoidCallback? onOpenLink;
  final VoidCallback onAddInterview;
  final VoidCallback onFollowUp;
  final bool followUpSet;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.open_in_new_rounded,
            label: ApplicationStrings.actionOpenLink,
            onTap: onOpenLink,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _ActionTile(
            icon: Icons.event_available_rounded,
            label: ApplicationStrings.actionInterview,
            onTap: onAddInterview,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _ActionTile(
            icon: followUpSet
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            label: ApplicationStrings.actionFollowUp,
            onTap: busy ? null : onFollowUp,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: enabled ? 1 : 0.5),
        borderRadius: BorderRadius.circular(Radii.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.input),
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: scheme.onPrimaryContainer.withValues(
                    alpha: enabled ? 1 : 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer.withValues(
                        alpha: enabled ? 1 : 0.5,
                      ),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Five-button status selector; choosing one opens the status sheet.
class StatusSelector extends StatelessWidget {
  /// Creates the selector.
  const StatusSelector({
    required this.current,
    required this.onSelected,
    super.key,
  });

  final ApplicationStatus current;
  final ValueChanged<ApplicationStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final status in ApplicationStatus.values) ...[
              if (status != ApplicationStatus.values.first)
                const SizedBox(width: 6),
              Expanded(
                child: _StatusButton(
                  status: status,
                  kind: statusOptionKind(status, current),
                  onTap: () => onSelected(status),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          ApplicationStrings.statusHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.status,
    required this.kind,
    required this.onTap,
  });

  final ApplicationStatus status;
  final StatusOptionKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StatusStyle.of(status, theme.brightness);
    final isCurrent = kind == StatusOptionKind.current;
    final radius = BorderRadius.circular(Radii.input);

    final body = Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isCurrent ? style.chipBackground : theme.colorScheme.surface,
        borderRadius: radius,
        border: kind == StatusOptionKind.next
            ? null
            : Border.all(
                color: isCurrent
                    ? style.color
                    : theme.colorScheme.outlineVariant,
                width: isCurrent ? 2 : 1,
              ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            style.icon,
            size: 20,
            color: isCurrent
                ? style.chipText
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              status.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: isCurrent
                    ? style.chipText
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: isCurrent,
      enabled: !isCurrent,
      label: [status.label, ?statusKindLabel(kind)].join(', '),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: radius,
        onTap: isCurrent ? null : onTap,
        child: kind == StatusOptionKind.next
            ? DashedBorder(color: style.color, radius: Radii.input, child: body)
            : body,
      ),
    );
  }
}

/// Vertical status timeline, newest first.
class StatusTimeline extends StatelessWidget {
  /// Creates the timeline from [history] (oldest first, as the API returns).
  const StatusTimeline({required this.history, this.source, super.key});

  final List<StatusHistoryEntry> history;
  final ApplicationSource? source;

  @override
  Widget build(BuildContext context) {
    final entries = history.reversed.toList();
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            source: source,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.source,
    required this.isLast,
  });

  final StatusHistoryEntry entry;
  final ApplicationSource? source;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StatusStyle.of(entry.toStatus, theme.brightness);
    final isFirst = entry.fromStatus == null;
    final title = isFirst
        ? ApplicationStrings.timelineFirst(
            DateHelpers.formatDate(entry.changedAt),
            source?.label,
          )
        : ApplicationStrings.timelineChange(
            entry.fromStatus!.label,
            entry.toStatus.label,
          );
    final note = entry.note;
    return IntrinsicHeight(
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
                    color: style.chipBackground,
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
                  Text(title, style: theme.textTheme.titleSmall),
                  if (!isFirst)
                    Text(
                      DateHelpers.formatDateTime(entry.changedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (note != null && note.trim().isNotEmpty) ...[
                    const SizedBox(height: Spacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                      child: Text(note, style: theme.textTheme.bodyMedium),
                    ),
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

/// Interviews of an application, fed by [interviewsForApplicationProvider].
class InterviewsSection extends ConsumerWidget {
  /// Creates the section.
  const InterviewsSection({
    required this.applicationId,
    required this.onAdd,
    required this.onOpen,
    this.focusInterviewId,
    super.key,
  });

  final int applicationId;

  /// Interview to scroll to and highlight for about two seconds.
  final int? focusInterviewId;
  final VoidCallback onAdd;
  final ValueChanged<Interview> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(interviewsForApplicationProvider(applicationId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          ApplicationStrings.sectionInterviews,
          trailing: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text(ApplicationStrings.addInterview),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        async.when(
          loading: () => const SkeletonBox(height: 64, radius: Radii.card),
          error: (e, _) => ErrorBox(
            error: e,
            onRetry: () =>
                ref.invalidate(interviewsForApplicationProvider(applicationId)),
          ),
          data: (items) => items.isEmpty
              ? Text(
                  ApplicationStrings.noInterviews,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: [
                    for (final i in items) ...[
                      i.id == focusInterviewId
                          ? _FocusedInterviewRow(
                              interview: i,
                              onTap: () => onOpen(i),
                            )
                          : _InterviewRow(interview: i, onTap: () => onOpen(i)),
                      const SizedBox(height: Spacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Scrolls itself into view when first built and flashes its background for
/// about two seconds.
class _FocusedInterviewRow extends StatefulWidget {
  const _FocusedInterviewRow({required this.interview, required this.onTap});

  final Interview interview;
  final VoidCallback onTap;

  @override
  State<_FocusedInterviewRow> createState() => _FocusedInterviewRowState();
}

class _FocusedInterviewRowState extends State<_FocusedInterviewRow> {
  Timer? _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
      );
    });
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _on = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _on ? scheme.primaryContainer : scheme.surface),
      duration: const Duration(milliseconds: 400),
      builder: (context, color, _) => _InterviewRow(
        key: const ValueKey('focused-interview'),
        interview: widget.interview,
        onTap: widget.onTap,
        color: color,
      ),
    );
  }
}

class _InterviewRow extends StatelessWidget {
  const _InterviewRow({
    required this.interview,
    required this.onTap,
    this.color,
    super.key,
  });

  final Interview interview;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = interview;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Card(
      color: color,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              DateBlock(date: i.scheduledAt),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${DateFormat.jm().format(i.scheduledAt)} · '
                      '${i.type.label} · ${i.durationMinutes} min',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Big text leaves no room beside the title: go below it.
                    if (largeText) ...[
                      const SizedBox(height: Spacing.xs),
                      _OutcomePill(outcome: i.outcome),
                    ],
                  ],
                ),
              ),
              if (!largeText) ...[
                const SizedBox(width: Spacing.sm),
                _OutcomePill(outcome: i.outcome),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill({required this.outcome});

  final InterviewOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (outcome) {
      InterviewOutcome.passed => (
        StatusStyle.of(
          ApplicationStatus.offer,
          Theme.of(context).brightness,
        ).chipBackground,
        StatusStyle.of(
          ApplicationStatus.offer,
          Theme.of(context).brightness,
        ).chipText,
      ),
      InterviewOutcome.failed => (
        StatusStyle.of(
          ApplicationStatus.rejected,
          Theme.of(context).brightness,
        ).chipBackground,
        StatusStyle.of(
          ApplicationStatus.rejected,
          Theme.of(context).brightness,
        ).chipText,
      ),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        outcome.label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Job description with a 3-line clamp and Read more / Show less.
class ExpandableText extends StatefulWidget {
  /// Creates the text block.
  const ExpandableText({
    required this.text,
    this.collapsedLines = 3,
    super.key,
  });

  final String text;
  final int collapsedLines;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : widget.collapsedLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded
                      ? ApplicationStrings.readLess
                      : ApplicationStrings.readMore,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Card wrapper with the shared inner padding.
class SectionCard extends StatelessWidget {
  /// Creates a card around [child].
  const SectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(Spacing.lg), child: child),
    );
  }
}

/// One label / value row of the details list.
class DetailRow extends StatelessWidget {
  /// Creates a row; a non-null [onTap] makes the value a link.
  const DetailRow({
    required this.label,
    required this.value,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      value,
      textAlign: TextAlign.end,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: onTap == null ? null : theme.colorScheme.primary,
        decoration: onTap == null ? null : TextDecoration.underline,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sizes.minTouch),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: onTap == null
                  ? text
                  : InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: text,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact inline error with Retry for sections.
class ErrorBox extends StatelessWidget {
  /// Creates the box.
  const ErrorBox({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded),
        const SizedBox(width: Spacing.sm),
        const Expanded(child: Text(AppStrings.errGeneric)),
        TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
      ],
    );
  }
}
