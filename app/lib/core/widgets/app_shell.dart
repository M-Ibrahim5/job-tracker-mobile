import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../constants/app_constants.dart';
import 'small_widgets.dart';

/// Scaffold with the 5-tab floating, icon-only bottom navigation. The Alerts tab shows the unread
/// count from [unreadCountProvider].
class AppShell extends ConsumerWidget {
  /// Creates the shell around the router's [shell].
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.screen,
          0,
          Spacing.screen,
          Spacing.md,
        ),
        child: Material(
          color: theme.cardTheme.color ?? scheme.surface,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) =>
                  shell.goBranch(i, initialLocation: i == shell.currentIndex),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: AppStrings.tabDashboard,
                  tooltip: AppStrings.tabDashboard,
                ),
                const NavigationDestination(
                  icon: Icon(Icons.work_outline_rounded),
                  selectedIcon: Icon(Icons.work_rounded),
                  label: AppStrings.tabApplications,
                  tooltip: AppStrings.tabApplications,
                ),
                const NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: AppStrings.tabCalendar,
                  tooltip: AppStrings.tabCalendar,
                ),
                NavigationDestination(
                  icon: UnreadBadge(
                    count: unread,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  selectedIcon: UnreadBadge(
                    count: unread,
                    child: const Icon(Icons.notifications_rounded),
                  ),
                  label: AppStrings.tabNotifications,
                  tooltip: AppStrings.tabNotifications,
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: AppStrings.tabSettings,
                  tooltip: AppStrings.tabSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
