import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/constants/account_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/settings.dart';
import '../../../domain/models/user.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/biometric_controller.dart';
import '../../profile/presentation/user_avatar.dart';
import '../application/account_actions.dart';
import '../application/settings_controller.dart';
import 'biometric_password_dialog.dart';
import 'change_password_sheet.dart';
import 'data_dialogs.dart';

const _offsetOptions = [
  Duration(days: 1),
  Duration(hours: 1),
  Duration(minutes: 15),
];
const _followUpOptions = [0, 3, 5, 7, 14];

/// Settings tab (`DESIGN.md §4.10`).
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  /// Runs [action]; failures become a snackbar with [fallback] or the mapped
  /// message.
  static Future<void> _guard(
    BuildContext context,
    Future<void> Function() action, {
    String? fallback,
  }) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, fallback ?? failureMessage(e));
      }
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final format = await showExportSheet(context);
    if (format == null || !context.mounted) return;
    await _guard(
      context,
      () => ref.read(dataActionsProvider).export(format),
      fallback: AccountStrings.exportFailed,
    );
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    if (!await confirmDeleteAllData(context) || !context.mounted) return;
    await _guard(context, () async {
      await ref.read(dataActionsProvider).deleteAll();
      if (context.mounted) {
        showAppSnackBar(context, AccountStrings.deleteAllDone);
      }
    });
  }

  Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: AccountStrings.logOutTitle,
      message: AccountStrings.logOutBody,
      confirmLabel: AccountStrings.logOut,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _guard(
      context,
      () => ref.read(authControllerProvider.notifier).signOut(),
    );
  }

  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    User user,
    bool on,
  ) async {
    final actions = ref.read(biometricActionsProvider);
    if (!on) {
      await _guard(context, actions.disable);
      if (context.mounted) {
        showAppSnackBar(context, AccountStrings.biometricDisabled);
      }
      return;
    }
    final password = await showBiometricPasswordDialog(context);
    if (password == null || !context.mounted) return;
    await _guard(context, () async {
      final done = await actions.enable(password: password);
      if (done && context.mounted) {
        showAppSnackBar(context, AccountStrings.biometricEnabled);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final biometric = ref.watch(biometricStatusProvider).valueOrNull;
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    Future<void> change(Settings Function(Settings) f) => _guard(
      context,
      () => ref.read(settingsProvider.notifier).change(f),
      fallback: AccountStrings.settingsSaveFailed,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.screen,
            Spacing.lg,
            Spacing.screen,
            Spacing.xl,
          ),
          children: [
            Text(
              AccountStrings.settingsTitle,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: Spacing.lg),
            if (user != null) _ProfileCard(user: user),
            const SizedBox(height: Spacing.section),
            const Eyebrow(AccountStrings.sectionAccount),
            const SizedBox(height: Spacing.sm),
            GroupedCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text(AccountStrings.personalDetails),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.editProfile),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text(AccountStrings.changePassword),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showChangePasswordSheet(context),
                ),
                if (biometric != null && biometric.available && user != null)
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: const Text(AccountStrings.biometricTitle),
                    subtitle: const Text(AccountStrings.biometricSubtitle),
                    value: biometric.enabled,
                    onChanged: (v) => _toggleBiometric(context, ref, user, v),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.section),
            ...switch (settings) {
              AsyncData(:final value) => _settingsSections(
                context,
                value,
                change,
              ),
              AsyncError(:final error) => [
                SizedBox(
                  height: 220,
                  child: ErrorState(
                    error: error,
                    onRetry: () => ref.invalidate(settingsProvider),
                  ),
                ),
              ],
              _ => const [
                SkeletonBox(height: 56, radius: Radii.card),
                SizedBox(height: Spacing.md),
                SkeletonBox(height: 160, radius: Radii.card),
              ],
            },
            const SizedBox(height: Spacing.section),
            const Eyebrow(AccountStrings.sectionData),
            const SizedBox(height: Spacing.sm),
            GroupedCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text(AccountStrings.exportData),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _export(context, ref),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    AccountStrings.deleteAllData,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () => _deleteAll(context, ref),
                ),
              ],
            ),
            const SizedBox(height: Spacing.section),
            const Eyebrow(AccountStrings.sectionAbout),
            const SizedBox(height: Spacing.sm),
            GroupedCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text(AccountStrings.aboutApp),
                  subtitle: Text(
                    AccountStrings.version(
                      ref.watch(appVersionProvider).valueOrNull ?? '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.section),
            DestructiveButton(
              label: AccountStrings.logOut,
              icon: Icons.logout_rounded,
              onPressed: () => _logOut(context, ref),
            ),
            if (user != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                AccountStrings.signedInAs(user.email),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _settingsSections(
    BuildContext context,
    Settings s,
    Future<void> Function(Settings Function(Settings)) change,
  ) {
    final theme = Theme.of(context);
    final offsets = {..._offsetOptions, ...s.defaultReminderOffsets}.toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      const Eyebrow(AccountStrings.sectionAppearance),
      const SizedBox(height: Spacing.sm),
      SegmentedChoice<ThemeSetting>(
        values: ThemeSetting.values,
        selected: s.theme,
        labelOf: (t) => t.label,
        onChanged: (t) => change((cur) => cur.copyWith(theme: t)),
      ),
      const SizedBox(height: Spacing.section),
      const Eyebrow(AccountStrings.sectionNotifications),
      const SizedBox(height: Spacing.sm),
      GroupedCard(
        children: [
          SwitchListTile(
            title: const Text(AccountStrings.interviewReminders),
            value: s.interviewRemindersEnabled,
            onChanged: (v) =>
                change((cur) => cur.copyWith(interviewRemindersEnabled: v)),
          ),
          SwitchListTile(
            title: const Text(AccountStrings.followUpReminders),
            value: s.followUpRemindersEnabled,
            onChanged: (v) =>
                change((cur) => cur.copyWith(followUpRemindersEnabled: v)),
          ),
          SwitchListTile(
            title: const Text(AccountStrings.statusChanges),
            value: s.statusAlertsEnabled,
            onChanged: (v) =>
                change((cur) => cur.copyWith(statusAlertsEnabled: v)),
          ),
        ],
      ),
      const SizedBox(height: Spacing.lg),
      Text(AccountStrings.defaultReminders, style: theme.textTheme.titleSmall),
      const SizedBox(height: Spacing.sm),
      ChoiceChips<Duration>(
        values: offsets,
        selected: s.defaultReminderOffsets.toSet(),
        multiSelect: true,
        labelOf: AccountStrings.reminderOffset,
        onChanged: (set) => change(
          (cur) => cur.copyWith(
            defaultReminderOffsets: set.toList()
              ..sort((a, b) => b.compareTo(a)),
          ),
        ),
      ),
      const SizedBox(height: Spacing.lg),
      Text(AccountStrings.defaultFollowUp, style: theme.textTheme.titleSmall),
      const SizedBox(height: Spacing.sm),
      ChoiceChips<int>(
        values: _followUpOptions,
        selected: {s.defaultFollowUpDays ?? 0},
        labelOf: (d) => d == 0
            ? AccountStrings.followUpOff
            : AccountStrings.followUpDays(d),
        onChanged: (set) => change(
          (cur) => set.first == 0
              ? cur.copyWith(clearFollowUpDays: true)
              : cur.copyWith(defaultFollowUpDays: set.first),
        ),
      ),
    ];
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      user.currentRole,
      user.location,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(user: user),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => context.push(Routes.editProfile),
                child: const Text(AccountStrings.editProfile),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
