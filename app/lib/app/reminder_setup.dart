import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/flutter_notification_gateway.dart';
import '../core/services/reminder_scheduler.dart';
import 'deep_links.dart';
import 'providers.dart';

/// Overrides that switch the app from the no-op scheduler to real local
/// notifications. Applied in `main` only, so tests never touch the plugin.
List<Override> localNotificationOverrides() => [
  reminderSchedulerProvider.overrideWith((ref) {
    return LocalReminderScheduler(
      gateway: FlutterNotificationGateway(),
      repository: ref.watch(reminderRepositoryProvider),
      isSignedIn: () => ref.read(currentUserProvider) != null,
      onOpenPayload: (payload) {
        if (isSafeDeepLink(payload)) {
          ref.read(pendingDeepLinkProvider.notifier).state = payload;
        }
      },
      logger: ref.read(loggerProvider),
    );
  }),
];
