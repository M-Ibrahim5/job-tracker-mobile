import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/reminder_scheduler.dart';
import '../features/applications/application/application_providers.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/interviews/application/interviews_providers.dart';
import '../features/notifications/application/notifications_controllers.dart';
import 'deep_links.dart';
import 'providers.dart';
import 'router.dart';

/// How often the Alerts badge is refreshed while the app is in the foreground.
const Duration kUnreadPollInterval = Duration(seconds: 60);

/// Keeps device reminders, the Alerts badge and notification deep links in
/// step with the app: wraps the router and reacts to sign-in, data changes,
/// app resume and timezone changes.
class AppCoordinator extends ConsumerStatefulWidget {
  /// Wraps [child] (the routed app).
  const AppCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppCoordinator> createState() => _AppCoordinatorState();
}

class _AppCoordinatorState extends ConsumerState<AppCoordinator>
    with WidgetsBindingObserver {
  Timer? _poll;
  bool _launchPayloadRead = false;

  ReminderScheduler get _scheduler => ref.read(reminderSchedulerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(kUnreadPollInterval, (_) => _onTick());

    // Signed in (launch restore or login): plan reminders, read the badge and
    // open the notification that launched the app.
    ref.listenManual(currentUserProvider.select((u) => u?.id), (prev, next) {
      if (next != null) _onSignedIn();
    }, fireImmediately: true);

    // Anything that changes what reminders should exist.
    for (final p in [
      applicationsRevisionProvider,
      interviewsRevisionProvider,
      dataRevisionProvider,
    ]) {
      ref.listenManual(p, (_, _) {
        if (ref.read(currentUserProvider) == null) return;
        _safe(_scheduler.resync);
        _refreshUnread();
      });
    }
    ref.listenManual(pendingDeepLinkProvider, (_, _) => _openPendingLink());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  void _safe(Future<void> Function() action) {
    unawaited(
      action().catchError((Object e) {
        ref.read(loggerProvider).w('Background task failed: $e');
      }),
    );
  }

  void _refreshUnread() {
    if (ref.read(currentUserProvider) == null) return;
    _safe(ref.read(unreadCountControllerProvider.notifier).refresh);
  }

  Future<void> _onSignedIn() async {
    _safe(() async {
      await _scheduler.init();
      await _scheduler.resync();
      if (!_launchPayloadRead) {
        _launchPayloadRead = true;
        final payload = await _scheduler.takeLaunchPayload();
        if (isSafeDeepLink(payload)) {
          ref.read(pendingDeepLinkProvider.notifier).state = payload;
        }
      }
    });
    _refreshUnread();
    _openPendingLink();
  }

  void _onTick() {
    if (ref.read(currentUserProvider) == null) return;
    _refreshUnread();
    _safe(_scheduler.checkTimezone);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (ref.read(currentUserProvider) == null) return;
    _refreshUnread();
    ref.invalidate(notificationsEnabledProvider);
    _safe(() async {
      await _scheduler.checkTimezone();
      await _scheduler.resync();
    });
  }

  void _openPendingLink() {
    final path = ref.read(pendingDeepLinkProvider);
    if (path == null) return;
    if (!isSafeDeepLink(path)) {
      ref.read(pendingDeepLinkProvider.notifier).state = null;
      return;
    }
    // Wait for sign-in: the router sends signed-out users to login and the
    // link is opened as soon as a session exists.
    if (ref.read(authControllerProvider).valueOrNull is! AuthAuthenticated) {
      return;
    }
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(routerProvider).push(path);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
