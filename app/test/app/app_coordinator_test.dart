import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/app.dart';
import 'package:jobtrail/app/app_coordinator.dart';
import 'package:jobtrail/app/deep_links.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/core/constants/interview_strings.dart';
import 'package:jobtrail/core/services/reminder_scheduler.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/features/applications/application/application_providers.dart';
import 'package:jobtrail/features/auth/application/auth_controller.dart';
import 'package:jobtrail/features/interviews/application/interviews_providers.dart';
import 'package:jobtrail/features/settings/application/settings_controller.dart';

import '../helpers/test_app.dart';

class _Scheduler extends NoopReminderScheduler {
  _Scheduler({this.launch});

  String? launch;
  int inits = 0;
  int resyncs = 0;
  int timezoneChecks = 0;

  @override
  Future<void> init() async => inits++;

  @override
  Future<void> resync() async => resyncs++;

  @override
  Future<void> checkTimezone() async => timezoneChecks++;

  @override
  Future<String?> takeLaunchPayload() async {
    final payload = launch;
    launch = null;
    return payload;
  }
}

class _Harness {
  _Harness({String? launch})
    : backend = FakeBackend(latency: Duration.zero),
      scheduler = _Scheduler(launch: launch);

  final FakeBackend backend;
  final _Scheduler scheduler;

  List<Override> get overrides => [
    ...fakeOverrides(backend),
    reminderSchedulerProvider.overrideWithValue(scheduler),
  ];
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  _Harness h, {
  bool signIn = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: const JobTrailApp(useGoogleFonts: false),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AppCoordinator)),
  );
  if (signIn) await _signIn(tester);
  return container;
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  group('after sign-in', () {
    testWidgets('plans reminders and loads the Alerts badge', (tester) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);

      expect(h.scheduler.inits, greaterThan(0));
      expect(h.scheduler.resyncs, greaterThan(0));
      // Two seeded notifications are unread.
      expect(container.read(unreadCountProvider), 2);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nothing is planned while signed out', (tester) async {
      final h = _Harness();
      await _pumpApp(tester, h, signIn: false);
      expect(h.scheduler.resyncs, 0);
    });
  });

  group('resync triggers', () {
    testWidgets('application and interview changes re-plan reminders', (
      tester,
    ) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);

      var before = h.scheduler.resyncs;
      container.read(applicationsRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();
      expect(h.scheduler.resyncs, before + 1);

      before = h.scheduler.resyncs;
      container.read(interviewsRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();
      expect(h.scheduler.resyncs, before + 1);

      before = h.scheduler.resyncs;
      container.read(dataRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();
      expect(h.scheduler.resyncs, before + 1);
    });

    testWidgets('changing a notification setting re-plans reminders', (
      tester,
    ) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);
      await container.read(settingsProvider.future);
      await tester.pumpAndSettle();

      var before = h.scheduler.resyncs;
      await container
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(followUpRemindersEnabled: false));
      await tester.pumpAndSettle();
      expect(h.scheduler.resyncs, greaterThan(before));

      // Theme is not a reminder setting.
      before = h.scheduler.resyncs;
      await container
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(theme: ThemeSetting.dark));
      await tester.pumpAndSettle();
      expect(h.scheduler.resyncs, before);
    });

    testWidgets('returning to the app re-checks the timezone and re-plans', (
      tester,
    ) async {
      final h = _Harness();
      await _pumpApp(tester, h);
      final resyncs = h.scheduler.resyncs;
      final checks = h.scheduler.timezoneChecks;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(h.scheduler.timezoneChecks, greaterThan(checks));
      expect(h.scheduler.resyncs, greaterThan(resyncs));
    });
  });

  group('unread badge', () {
    testWidgets('refreshes every minute while the app runs', (tester) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);
      expect(container.read(unreadCountProvider), 2);

      h.backend.notify(NotificationType.system, 'New', 'Body');
      await tester.pump(kUnreadPollInterval + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(container.read(unreadCountProvider), 3);
    });

    testWidgets('refreshes when the app comes back to the foreground', (
      tester,
    ) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);

      h.backend.notify(NotificationType.system, 'New', 'Body');
      h.backend.notify(NotificationType.system, 'Newer', 'Body');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(container.read(unreadCountProvider), 4);
    });

    testWidgets('signing out resets the badge to zero', (tester) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);
      expect(container.read(unreadCountProvider), 2);

      await container.read(authControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(container.read(unreadCountProvider), 0);
    });
  });

  group('notification deep links', () {
    testWidgets('a tapped interview reminder opens that interview', (
      tester,
    ) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);

      container.read(pendingDeepLinkProvider.notifier).state = '/interviews/1';
      await tester.pumpAndSettle();

      expect(find.text(InterviewStrings.detailTitle), findsOneWidget);
      expect(find.text('Technical interview · Round 2'), findsOneWidget);
      expect(container.read(pendingDeepLinkProvider), isNull);

      // Back returns to where the user was.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a follow-up reminder opens the application', (tester) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);
      container.read(pendingDeepLinkProvider.notifier).state =
          '/applications/2';
      await tester.pumpAndSettle();
      expect(find.text('Flutter Developer'), findsWidgets);
      expect(find.text('Orbit Health'), findsOneWidget);
    });

    testWidgets('a link tapped while signed out opens after sign-in', (
      tester,
    ) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h, signIn: false);

      container.read(pendingDeepLinkProvider.notifier).state = '/interviews/2';
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(container.read(pendingDeepLinkProvider), '/interviews/2');

      await _signIn(tester);
      expect(find.text(InterviewStrings.detailTitle), findsOneWidget);
      expect(find.text('HR chat'), findsOneWidget);
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('the notification that cold-started the app is opened', (
      tester,
    ) async {
      final h = _Harness(launch: '/applications/3');
      await _pumpApp(tester, h);
      expect(find.text('Lumen Pay'), findsOneWidget);
      expect(find.text('Mobile Engineer'), findsWidgets);
    });

    testWidgets('links outside interviews and applications are ignored', (
      tester,
    ) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);
      container.read(pendingDeepLinkProvider.notifier).state =
          '/settings/profile';
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(container.read(pendingDeepLinkProvider), isNull);
    });
  });

  group('wiring', () {
    testWidgets('the logout canceller is the reminder scheduler', (
      tester,
    ) async {
      final h = _Harness();
      final container = await _pumpApp(tester, h);
      expect(container.read(reminderCancellerProvider), same(h.scheduler));
    });
  });
}
