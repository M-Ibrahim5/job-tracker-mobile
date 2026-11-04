import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/providers.dart';
import '../../../core/constants/alerts_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/reminder_scheduler.dart';
import '../../../core/widgets/widgets.dart';
import '../application/notifications_controllers.dart';

/// `shared_preferences` key set once the explanation was shown.
const kNotificationPromptedKey = 'notification_permission_prompted';

/// Opens the system settings page of the app. Replace in tests.
final appSettingsOpenerProvider = Provider<Future<bool> Function()>(
  (ref) => openAppSettings,
);

/// Explanation shown before the first system prompt. Resolves to true when the
/// user allowed notifications.
Future<bool> showNotificationPermissionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final wantsPrompt = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const NotificationPermissionSheet(),
  );
  await ref
      .read(sharedPreferencesProvider)
      ?.setBool(kNotificationPromptedKey, true);
  if (wantsPrompt != true) return false;
  final granted = await ref.read(reminderSchedulerProvider).requestPermission();
  ref.invalidate(notificationsEnabledProvider);
  return granted;
}

/// Asks for permission the first time only, and only if it isn't granted yet.
Future<void> maybeAskNotificationPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final prompted =
      ref.read(sharedPreferencesProvider)?.getBool(kNotificationPromptedKey) ??
      false;
  if (prompted) return;
  if (await ref.read(reminderSchedulerProvider).notificationsEnabled()) return;
  if (!context.mounted) return;
  await showNotificationPermissionSheet(context, ref);
}

/// "Enable" action of the Alerts banner: explain and ask the first time, then
/// send the user to system settings (the OS won't prompt again).
Future<void> enableNotifications(BuildContext context, WidgetRef ref) async {
  final prompted =
      ref.read(sharedPreferencesProvider)?.getBool(kNotificationPromptedKey) ??
      false;
  if (!prompted) {
    await showNotificationPermissionSheet(context, ref);
    if (await ref.read(reminderSchedulerProvider).notificationsEnabled()) {
      return;
    }
  }
  await ref.read(appSettingsOpenerProvider)();
}

/// Friendly explanation with Allow / Not now.
class NotificationPermissionSheet extends StatelessWidget {
  /// Creates the sheet.
  const NotificationPermissionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.screen,
        0,
        Spacing.screen,
        Spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.notifications_active_rounded,
              size: 32,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            AlertsStrings.permissionTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            AlertsStrings.permissionBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xl),
          PrimaryButton(
            label: AlertsStrings.permissionAllow,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Spacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AlertsStrings.permissionLater),
          ),
        ],
      ),
    );
  }
}
