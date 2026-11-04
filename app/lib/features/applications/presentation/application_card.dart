import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/job_application.dart';

/// "27 Oct" style date used on cards and hints.
String shortDate(DateTime d) => DateFormat('d MMM').format(d);

/// Hero tag shared by the list card title and the detail header title.
Object applicationTitleHeroTag(int id) => 'application-title-$id';

/// Application summary card for the list (`DESIGN.md §4.4`).
class ApplicationCard extends StatelessWidget {
  /// Creates a card; [onTap] opens the detail screen.
  const ApplicationCard({
    required this.application,
    required this.onTap,
    super.key,
  });

  final JobApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = application;
    final hint = _hint(theme.brightness);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Hero(
                      tag: applicationTitleHeroTag(a.id),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          a.jobTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    shortDate(a.appliedDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                '${a.companyName} · ${a.location}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(status: a.status),
                        _ArrangementTag(arrangement: a.workArrangement),
                      ],
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: Spacing.sm),
                    Flexible(child: hint),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _hint(Brightness brightness) {
    final a = application;
    final dark = brightness == Brightness.dark;
    final String text;
    final Color color;
    if (a.nextInterviewAt != null) {
      text = ApplicationStrings.nextInterview(shortDate(a.nextInterviewAt!));
      color = StatusStyle.of(ApplicationStatus.interview, brightness).chipText;
    } else if (a.followUpAt != null) {
      text = ApplicationStrings.followUpOn(shortDate(a.followUpAt!));
      color = dark ? StatusStyle.followUpColor : StatusStyle.followUpText;
    } else {
      return null;
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    );
  }
}

class _ArrangementTag extends StatelessWidget {
  const _ArrangementTag({required this.arrangement});

  final WorkArrangement arrangement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        arrangement.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
