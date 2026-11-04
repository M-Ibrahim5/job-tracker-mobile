import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/reminder_scheduler.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/settings.dart';

/// The user's server-side settings with optimistic updates. Other features read
/// the defaults from here (reminder offsets, follow-up days).
///
/// Every change is applied immediately; if the request fails the previous value
/// is restored and the error rethrown for the caller to report.
class SettingsController extends AsyncNotifier<Settings> {
  @override
  Future<Settings> build() async {
    final userId = ref.watch(currentUserProvider.select((u) => u?.id));
    if (userId == null) return const Settings();
    final settings = await ref.read(profileRepositoryProvider).getSettings();
    await _applyTheme(settings.theme);
    return settings;
  }

  Future<void> _applyTheme(ThemeSetting theme) async {
    ref.read(themeModeProvider.notifier).state = themeModeOf(theme);
    await ref
        .read(sharedPreferencesProvider)
        ?.setString(kThemePrefKey, theme.name);
  }

  /// Applies [change] optimistically and saves it.
  Future<void> change(Settings Function(Settings current) change) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    final next = change(previous);
    if (next == previous) return;
    state = AsyncData(next);
    if (next.theme != previous.theme) await _applyTheme(next.theme);
    try {
      final saved = await ref
          .read(profileRepositoryProvider)
          .updateSettings(next);
      state = AsyncData(saved);
      if (_remindersChanged(previous, saved)) {
        // Which reminders exist depends on these switches.
        unawaited(ref.read(reminderSchedulerProvider).resync());
      }
    } catch (_) {
      state = AsyncData(previous);
      if (next.theme != previous.theme) await _applyTheme(previous.theme);
      rethrow;
    }
  }

  static bool _remindersChanged(Settings a, Settings b) =>
      a.interviewRemindersEnabled != b.interviewRemindersEnabled ||
      a.followUpRemindersEnabled != b.followUpRemindersEnabled ||
      a.statusAlertsEnabled != b.statusAlertsEnabled;

  /// Applies the theme locally first, then saves it on the server.
  Future<void> setTheme(ThemeSetting theme) =>
      change((s) => s.copyWith(theme: theme));
}

/// Settings for the signed-in user.
final settingsProvider = AsyncNotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);
