import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/enums/enums.dart';
import '../constants/app_constants.dart';

/// 52×56 tonal tile with the day over the month. Uses Interview colors unless
/// [background] / [foreground] are given.
class DateBlock extends StatelessWidget {
  /// Creates a block for [date].
  const DateBlock({
    required this.date,
    this.background,
    this.foreground,
    super.key,
  });

  final DateTime date;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(
      ApplicationStatus.interview,
      Theme.of(context).brightness,
    );
    final fg = foreground ?? style.chipText;
    final month = DateFormat.MMM().format(date);
    return Semantics(
      label: DateFormat.MMMd().format(date),
      excludeSemantics: true,
      child: Container(
        width: 52,
        height: 56,
        decoration: BoxDecoration(
          color: background ?? style.chipBackground,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        // The block keeps its size; large text scales down to fit it.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: fg,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                month,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] (typically an icon) with a red unread-count badge. The badge
/// is hidden at 0 and capped at "9+".
class UnreadBadge extends StatelessWidget {
  /// Creates a badge for [count].
  const UnreadBadge({required this.count, required this.child, super.key});

  final int count;
  final Widget child;

  /// Text shown inside the badge.
  static String labelFor(int count) => count > 9 ? '9+' : '$count';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: count > 0 ? AppStrings.unreadSemantics(count) : null,
      child: Badge(
        isLabelVisible: count > 0,
        label: ExcludeSemantics(child: Text(labelFor(count))),
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        child: child,
      ),
    );
  }
}

/// Uppercase group label (13/800, letter-spacing 0.6).
class Eyebrow extends StatelessWidget {
  /// Creates a label.
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One rounded card holding [children] separated by dividers.
class GroupedCard extends StatelessWidget {
  /// Creates a grouped card.
  const GroupedCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}
