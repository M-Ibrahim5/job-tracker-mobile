import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/device_timezone.dart';
import '../core/config/app_config.dart';
import '../core/services/avatar_picker.dart';
import '../core/services/biometric_service.dart';
import '../core/services/file_sharer.dart';
import '../core/services/reminder_canceller.dart';
import '../data/api/api_auth_repository.dart';
import '../data/api/api_calendar_repository.dart';
import '../data/api/api_client.dart';
import '../data/api/api_dashboard_repository.dart';
import '../data/api/api_interview_repository.dart';
import '../data/api/api_job_application_repository.dart';
import '../data/api/api_notification_repository.dart';
import '../data/api/api_profile_repository.dart';
import '../data/api/api_data_repository.dart';
import '../data/api/token_storage.dart';
import '../data/fake/fake_backend.dart';
import '../data/fake/fake_repositories.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/interview_repository.dart';
import '../domain/repositories/job_application_repository.dart';
import '../domain/repositories/misc_repositories.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/enums/enums.dart';
import '../domain/models/user.dart';
import '../core/services/reminder_scheduler.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/notifications/application/notifications_controllers.dart';

/// App-wide logger (use instead of `print`).
final loggerProvider = Provider<Logger>((ref) => Logger());

/// Whether repositories are the in-memory fakes (`--dart-define=USE_FAKE=true`).
/// Override in tests to pick either backend.
final useFakeBackendProvider = Provider<bool>(
  (ref) => AppConfig.useFakeBackend,
);

/// State shared by all fake repositories.
final fakeBackendProvider = Provider<FakeBackend>((ref) => FakeBackend());

/// Secure token persistence (in memory when using the fake backend).
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => ref.watch(useFakeBackendProvider)
      ? MemoryTokenStorage()
      : SecureTokenStorage(),
);

/// HTTP client with auth, refresh and logging interceptors.
final dioProvider = Provider<Dio>((ref) {
  final dio = createApiDio(
    tokens: ref.watch(tokenStorageProvider),
    logger: ref.watch(loggerProvider),
    timezone: ref.read(deviceTimezoneProvider),
    onSignedOut: () async =>
        ref.read(authControllerProvider.notifier).sessionExpired(),
  );
  ref.onDispose(dio.close);
  return dio;
});

T _pick<T>(Ref ref, T Function(FakeBackend) fake, T Function(Dio) api) {
  return ref.watch(useFakeBackendProvider)
      ? fake(ref.watch(fakeBackendProvider))
      : api(ref.watch(dioProvider));
}

/// Authentication and session.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => _pick<AuthRepository>(
    ref,
    FakeAuthRepository.new,
    (dio) => ApiAuthRepository(dio, ref.watch(tokenStorageProvider)),
  ),
);

/// Profile and settings.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => _pick<ProfileRepository>(
    ref,
    FakeProfileRepository.new,
    ApiProfileRepository.new,
  ),
);

/// Applications and status history.
final jobApplicationRepositoryProvider = Provider<JobApplicationRepository>(
  (ref) => _pick<JobApplicationRepository>(
    ref,
    FakeJobApplicationRepository.new,
    ApiJobApplicationRepository.new,
  ),
);

/// Interviews.
final interviewRepositoryProvider = Provider<InterviewRepository>(
  (ref) => _pick<InterviewRepository>(
    ref,
    FakeInterviewRepository.new,
    ApiInterviewRepository.new,
  ),
);

/// In-app notification center.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => _pick<NotificationRepository>(
    ref,
    FakeNotificationRepository.new,
    ApiNotificationRepository.new,
  ),
);

/// Dashboard aggregates.
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => _pick<DashboardRepository>(
    ref,
    FakeDashboardRepository.new,
    ApiDashboardRepository.new,
  ),
);

/// Calendar events.
final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => _pick<CalendarRepository>(
    ref,
    FakeCalendarRepository.new,
    ApiCalendarRepository.new,
  ),
);

/// Device reminder schedule.
final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => _pick<ReminderRepository>(
    ref,
    FakeReminderRepository.new,
    ApiReminderRepository.new,
  ),
);

/// Export and bulk delete.
final dataRepositoryProvider = Provider<DataRepository>(
  (ref) =>
      _pick<DataRepository>(ref, FakeDataRepository.new, ApiDataRepository.new),
);

/// Local key-value store, overridden in `main`. Null in tests that do not
/// need persistence.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// `shared_preferences` key for the theme (applies before any network call).
const kThemePrefKey = 'theme';

/// Maps the stored setting to Flutter's [ThemeMode].
ThemeMode themeModeOf(ThemeSetting setting) => switch (setting) {
  ThemeSetting.system => ThemeMode.system,
  ThemeSetting.light => ThemeMode.light,
  ThemeSetting.dark => ThemeMode.dark,
};

/// Current theme mode. Starts from the locally stored value so the right theme
/// shows before the settings request finishes.
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final name = ref.watch(sharedPreferencesProvider)?.getString(kThemePrefKey);
  final match = ThemeSetting.values.where((t) => t.name == name);
  return themeModeOf(match.isEmpty ? ThemeSetting.system : match.first);
});

/// The signed-in user, or null.
final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authControllerProvider).valueOrNull;
  return auth is AuthAuthenticated ? auth.user : null;
});

/// Cancels local reminders on logout.
final reminderCancellerProvider = Provider<ReminderCanceller>(
  (ref) => ref.watch(reminderSchedulerProvider),
);

/// Shares exported files.
final fileSharerProvider = Provider<FileSharer>(
  (ref) => const SystemFileSharer(),
);

/// Fingerprint / face sensor (never available with the fake backend).
final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => ref.watch(useFakeBackendProvider)
      ? const UnavailableBiometricAuthenticator()
      : LocalAuthBiometricAuthenticator(),
);

/// Saved device token for fingerprint login (in memory with the fake backend).
final deviceTokenStoreProvider = Provider<DeviceTokenStore>(
  (ref) => ref.watch(useFakeBackendProvider)
      ? MemoryDeviceTokenStore()
      : SecureDeviceTokenStore(),
);

/// Picks profile photos.
final avatarPickerProvider = Provider<AvatarPicker>(
  (ref) => const GalleryAvatarPicker(),
);

/// App version string (`x.y.z`) for the About row.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Bumped whenever all server data was wiped. Feature providers that load
/// applications, interviews, notifications, dashboard or calendar data should
/// `ref.watch(dataRevisionProvider)` so they reload.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

/// Unread notification count for the Alerts tab badge (0 until loaded).
final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(unreadCountControllerProvider).valueOrNull ?? 0,
);

/// Whether the first-launch onboarding was completed. Defaults to true so
/// the redirect never forces onboarding until session 04 wires persistence.
final onboardingSeenProvider = StateProvider<bool>((ref) => true);
