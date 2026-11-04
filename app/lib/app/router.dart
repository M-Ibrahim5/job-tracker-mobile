import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/widgets/widgets.dart';
import '../features/applications/presentation/application_detail_screen.dart';
import '../features/applications/presentation/application_form_screen.dart';
import '../features/applications/presentation/applications_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/interviews/presentation/interview_detail_screen.dart';
import '../features/interviews/presentation/interview_form_screen.dart';
import '../features/interviews/presentation/interviews_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'auth_redirect.dart';
import 'providers.dart';
import 'routes.dart';

export 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

Widget _placeholder(String title, IconData icon) =>
    PlaceholderScreen(title: title, icon: icon);

int _idOf(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

/// Parses a `YYYY-MM-DD` query value; null when absent or malformed.
DateTime? _dateParam(String? value) {
  if (value == null) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final nums = parts.map(int.tryParse).toList();
  if (nums.contains(null)) return null;
  return DateTime(nums[0]!, nums[1]!, nums[2]!);
}

GoRoute _fullScreen(String path, Widget Function(GoRouterState) builder) {
  return GoRoute(
    path: path,
    parentNavigatorKey: _rootKey,
    builder: (_, state) => builder(state),
  );
}

/// Builds the router. Feature sessions replace the placeholder builders; the
/// redirect and shell stay as they are.
GoRouter buildRouter(Ref ref, {String initialLocation = Routes.dashboard}) {
  // Re-evaluate the redirect whenever auth or onboarding state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(onboardingSeenProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      auth: ref.read(authControllerProvider).valueOrNull,
      location: state.uri.path,
      onboardingSeen: ref.read(onboardingSeenProvider),
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => _placeholder(
          AppStrings.screenOnboarding,
          Icons.waving_hand_rounded,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.applications,
                builder: (_, state) =>
                    ApplicationsScreen(query: state.uri.queryParameters),
                routes: [
                  // `new` must precede `:id`.
                  _fullScreen(
                    'new',
                    (state) => ApplicationFormScreen(
                      initialAppliedDate: _dateParam(
                        state.uri.queryParameters['appliedDate'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, state) => ApplicationDetailScreen(
                      id: _idOf(state),
                      focusInterviewId: int.tryParse(
                        state.uri.queryParameters['focusInterview'] ?? '',
                      ),
                    ),
                    routes: [
                      _fullScreen(
                        'edit',
                        (state) => ApplicationFormScreen(id: _idOf(state)),
                      ),
                      _fullScreen(
                        'interviews/new',
                        (state) =>
                            InterviewFormScreen(applicationId: _idOf(state)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (_, _) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.notifications,
                builder: (_, _) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  _fullScreen('profile', (_) => const EditProfileScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.interviews,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const InterviewsScreen(),
        routes: [
          // `new` must precede `:id`.
          _fullScreen(
            'new',
            (state) => InterviewFormScreen(
              initialDate: _dateParam(state.uri.queryParameters['date']),
            ),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => InterviewDetailScreen(id: _idOf(state)),
            routes: [
              _fullScreen(
                'edit',
                (state) => InterviewFormScreen(interviewId: _idOf(state)),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Application router.
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});
