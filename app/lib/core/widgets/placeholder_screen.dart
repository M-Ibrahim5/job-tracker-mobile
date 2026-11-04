import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Temporary body for routes whose feature lands in a later session. Feature
/// sessions replace the router builder that uses it.
class PlaceholderScreen extends StatelessWidget {
  /// Creates a placeholder titled [title]. [actions] can add demo buttons.
  const PlaceholderScreen({
    required this.title,
    required this.icon,
    this.actions = const [],
    this.showAppBar = true,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<Widget> actions;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: Spacing.lg),
                Text(title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: Spacing.sm),
                Text(
                  AppStrings.comingSoon,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                for (final a in actions) ...[
                  const SizedBox(height: Spacing.lg),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: a,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
