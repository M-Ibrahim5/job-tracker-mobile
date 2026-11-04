import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../constants/app_constants.dart';

/// Warning-colored banner with an icon, text and an optional action.
class NoticeBanner extends StatelessWidget {
  /// Creates the banner.
  const NoticeBanner({
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final background = isLight
        ? AppColors.warningContainer
        : theme.colorScheme.tertiaryContainer;
    final foreground = isLight
        ? AppColors.onWarningContainer
        : theme.colorScheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          // Narrow screens or large text: the action goes under the message.
          final stacked =
              actionLabel != null &&
              (constraints.maxWidth < 340 || scale > 1.2);
          final message = Text(
            this.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          );
          final button = actionLabel == null
              ? null
              : FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  ),
                  child: Text(actionLabel!),
                );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: foreground),
                    const SizedBox(width: Spacing.md),
                    Expanded(child: message),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }
          return Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: Spacing.md),
              Expanded(child: message),
              if (button != null) ...[
                const SizedBox(width: Spacing.sm),
                button,
              ],
            ],
          );
        },
      ),
    );
  }
}
