import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/interview.dart';

/// Row for an interview: date block, title, "Company · time · type" and the
/// outcome pill.
class InterviewTile extends StatelessWidget {
  /// Creates a tile.
  const InterviewTile({
    required this.interview,
    required this.onTap,
    super.key,
  });

  final Interview interview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = interview;
    final company = i.companyName;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Card(
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
                      [
                        ?company,
                        DateFormat.jm().format(i.scheduledAt),
                        i.type.label,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Big text leaves no room beside the title: go below it.
                    if (largeText) ...[
                      const SizedBox(height: Spacing.xs),
                      OutcomePill(outcome: i.outcome),
                    ],
                  ],
                ),
              ),
              if (!largeText) ...[
                const SizedBox(width: Spacing.sm),
                OutcomePill(outcome: i.outcome),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill showing an interview outcome.
class OutcomePill extends StatelessWidget {
  /// Creates a pill.
  const OutcomePill({required this.outcome, super.key});

  final InterviewOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final scheme = theme.colorScheme;
    final (bg, fg) = switch (outcome) {
      InterviewOutcome.passed => (
        StatusStyle.of(ApplicationStatus.offer, b).chipBackground,
        StatusStyle.of(ApplicationStatus.offer, b).chipText,
      ),
      InterviewOutcome.failed => (
        StatusStyle.of(ApplicationStatus.rejected, b).chipBackground,
        StatusStyle.of(ApplicationStatus.rejected, b).chipText,
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
