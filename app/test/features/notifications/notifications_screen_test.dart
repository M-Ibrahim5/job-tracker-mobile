import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/core/constants/alerts_strings.dart';
import 'package:jobtrail/core/constants/interview_strings.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/services/reminder_scheduler.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/page.dart';
import 'package:jobtrail/domain/models/app_notification.dart';
import 'package:jobtrail/features/notifications/application/notifications_controllers.dart';
import 'package:jobtrail/features/notifications/presentation/notification_permission.dart';
import 'package:jobtrail/features/notifications/presentation/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../applications/harness.dart';
import '../interviews/interviews_harness.dart';

final _now = DateTime(2026, 10, 25, 12);

class _Scheduler extends NoopReminderScheduler {
  _Scheduler({this.enabled = true});

  bool enabled;
  int permissionRequests = 0;

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    enabled = true;
    return true;
  }
}

class _FlakyNotificationRepository extends FakeNotificationRepository {
  _FlakyNotificationRepository(super.b);

  Object? failNextList;
  Object? failNextAction;

  @override
  Future<Page<AppNotification>> list({int page = 1, int pageSize = 20}) async {
    final e = failNextList;
    if (e != null) {
      failNextList = null;
      throw e;
    }
    return super.list(page: page, pageSize: pageSize);
  }

  @override
  Future<void> delete(int id) async {
    final e = failNextAction;
    if (e != null) {
      failNextAction = null;
      throw e;
    }
    return super.delete(id);
  }
}

/// Backend with three notifications on distinct days (2 unread).
InterviewFixture _fixture() {
  final f = InterviewFixture();
  f.backend.notifications.clear();
  f.backend.notify(
    NotificationType.interviewReminder,
    'Interview tomorrow',
    'Helio Systems · 10:00 AM · Phone',
    applicationId: 7,
    interviewId: 2,
    at: DateTime(2026, 10, 25, 9),
  );
  f.backend.notify(
    NotificationType.statusChange,
    'Moved to Interview',
    'Northwind Labs · Senior Flutter Developer',
    applicationId: 1,
    at: DateTime(2026, 10, 24, 20),
  );
  f.backend.notify(
    NotificationType.system,
    'Welcome to JobTrail',
    'Add your first application.',
    at: DateTime(2026, 10, 20, 8),
    isRead: true,
  );
  return f;
}

Future<InterviewFixture> _pump(
  WidgetTester tester, {
  InterviewFixture? fixture,
  List<Override> extra = const [],
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final f = fixture ?? _fixture();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routedApp(
      NotificationsScreen(now: () => _now),
      overrides: [...f.overrides, ...extra],
      routes: interviewRoutes(),
      textScale: textScale,
      brightness: brightness,
    ),
  );
  await tester.pumpAndSettle();
  return f;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(NotificationsScreen)));

Finder get _dots => find.byKey(const ValueKey('unread-dot'));

void main() {
  group('list', () {
    testWidgets('groups rows under Today, Yesterday and Earlier', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('EARLIER'), findsOneWidget);

      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('TODAY'), lessThan(y('Interview tomorrow')));
      expect(y('Interview tomorrow'), lessThan(y('YESTERDAY')));
      expect(y('YESTERDAY'), lessThan(y('Moved to Interview')));
      expect(y('Moved to Interview'), lessThan(y('EARLIER')));
      expect(y('EARLIER'), lessThan(y('Welcome to JobTrail')));
    });

    testWidgets('unread rows have a dot and bold title; read rows do not', (
      tester,
    ) async {
      await _pump(tester);

      expect(_dots, findsNWidgets(2));
      FontWeight? weight(String title) =>
          tester.widget<Text>(find.text(title)).style?.fontWeight;
      expect(weight('Interview tomorrow'), FontWeight.w800);
      expect(weight('Welcome to JobTrail'), FontWeight.w600);

      // The read row sits in a plain surface, unread ones are tinted.
      Color? tint(String title) => tester
          .widget<Material>(
            find
                .ancestor(of: find.text(title), matching: find.byType(Material))
                .first,
          )
          .color;
      expect(tint('Interview tomorrow'), isNot(tint('Welcome to JobTrail')));
    });

    testWidgets('captions show time and type', (tester) async {
      await _pump(tester);
      expect(find.textContaining('Interview reminder'), findsOneWidget);
      expect(find.textContaining('Status change'), findsOneWidget);
      expect(find.textContaining('9:00'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      final f = _fixture()..backend.notifications.clear();
      await _pump(tester, fixture: f);
      expect(find.text(AlertsStrings.emptyTitle), findsOneWidget);
      final markAll = tester.widget<TextButton>(
        find.widgetWithText(TextButton, AlertsStrings.markAllRead),
      );
      expect(markAll.onPressed, isNull);
    });

    testWidgets('error state with Retry', (tester) async {
      final f = _fixture();
      final repo = _FlakyNotificationRepository(f.backend)
        ..failNextList = const NetworkFailure();
      await _pump(
        tester,
        fixture: f,
        extra: [notificationRepositoryProvider.overrideWithValue(repo)],
      );
      expect(find.byType(ErrorState), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Interview tomorrow'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets(
      'tapping an unread alert marks it read and opens the interview',
      (tester) async {
        final f = await _pump(tester);
        await tester.tap(find.text('Interview tomorrow'));
        await tester.pumpAndSettle();

        expect(
          f.backend.notifications
              .firstWhere((n) => n.title == 'Interview tomorrow')
              .isRead,
          isTrue,
        );
        expect(find.text(InterviewStrings.detailTitle), findsOneWidget);
        expect(find.text('Helio Systems · Software Engineer'), findsOneWidget);
      },
    );

    testWidgets('an application alert opens the application', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Moved to Interview'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL-1'), findsOneWidget);
    });

    testWidgets('an alert without a target just stays on the list', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.text('Welcome to JobTrail'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('marking one read updates dots and the badge count', (
      tester,
    ) async {
      await _pump(tester);
      final container = _container(tester);
      await container.read(unreadCountControllerProvider.future);
      container.read(unreadCountControllerProvider.notifier).setLocal(2);
      expect(container.read(unreadCountProvider), 2);

      await tester.tap(find.text('Moved to Interview'));
      await tester.pumpAndSettle();
      expect(container.read(unreadCountProvider), 1);
    });

    testWidgets('swipe left deletes an alert', (tester) async {
      final f = await _pump(tester);
      await tester.drag(
        find.text('Welcome to JobTrail'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to JobTrail'), findsNothing);
      expect(
        f.backend.notifications.map((n) => n.title),
        isNot(contains('Welcome to JobTrail')),
      );
      expect(
        find.text('EARLIER'),
        findsNothing,
        reason: 'empty group vanishes',
      );
    });

    testWidgets('a failed delete is rolled back with a message', (
      tester,
    ) async {
      final f = _fixture();
      final repo = _FlakyNotificationRepository(f.backend)
        ..failNextAction = const NetworkFailure();
      await _pump(
        tester,
        fixture: f,
        extra: [notificationRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.drag(
        find.text('Welcome to JobTrail'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to JobTrail'), findsOneWidget);
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
    });

    testWidgets('Mark all read clears every dot', (tester) async {
      final f = await _pump(tester);
      await tester.tap(find.text(AlertsStrings.markAllRead));
      await tester.pumpAndSettle();

      expect(_dots, findsNothing);
      expect(f.backend.notifications.every((n) => n.isRead), isTrue);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, AlertsStrings.markAllRead),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('Clear all asks first, then empties the list', (tester) async {
      final f = await _pump(tester);
      await tester.tap(find.text(AlertsStrings.clearAll));
      await tester.pumpAndSettle();
      expect(find.text(AlertsStrings.clearTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(f.backend.notifications, hasLength(3));

      await tester.tap(find.text(AlertsStrings.clearAll));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(AlertsStrings.clearAll),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.backend.notifications, isEmpty);
      expect(find.text(AlertsStrings.emptyTitle), findsOneWidget);
    });

    testWidgets('pull to refresh reloads the list', (tester) async {
      final f = await _pump(tester);
      f.backend.notify(
        NotificationType.system,
        'Brand new',
        'Just arrived',
        at: DateTime(2026, 10, 25, 11),
      );
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Brand new'), findsOneWidget);
    });
  });

  group('phone reminders permission', () {
    Future<SharedPreferences> prefs([Map<String, Object> values = const {}]) {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    testWidgets('no banner while notifications are allowed', (tester) async {
      await _pump(
        tester,
        extra: [reminderSchedulerProvider.overrideWithValue(_Scheduler())],
      );
      expect(find.text(AlertsStrings.bannerAction), findsNothing);
    });

    testWidgets('banner → explanation → system prompt the first time', (
      tester,
    ) async {
      final scheduler = _Scheduler(enabled: false);
      var settingsOpened = 0;
      await _pump(
        tester,
        extra: [
          reminderSchedulerProvider.overrideWithValue(scheduler),
          sharedPreferencesProvider.overrideWithValue(await prefs()),
          appSettingsOpenerProvider.overrideWithValue(() async {
            settingsOpened++;
            return true;
          }),
        ],
      );
      expect(find.byType(NoticeBanner), findsOneWidget);
      expect(find.textContaining('Phone reminders are off'), findsOneWidget);

      await tester.tap(find.text(AlertsStrings.bannerAction));
      await tester.pumpAndSettle();
      expect(find.text(AlertsStrings.permissionTitle), findsOneWidget);
      expect(scheduler.permissionRequests, 0, reason: 'explained first');

      await tester.tap(find.text(AlertsStrings.permissionAllow));
      await tester.pumpAndSettle();
      expect(scheduler.permissionRequests, 1);
      expect(settingsOpened, 0);
      expect(find.byType(NoticeBanner), findsNothing);
    });

    testWidgets('declining the explanation does not prompt the OS', (
      tester,
    ) async {
      final scheduler = _Scheduler(enabled: false);
      var settingsOpened = 0;
      await _pump(
        tester,
        extra: [
          reminderSchedulerProvider.overrideWithValue(scheduler),
          sharedPreferencesProvider.overrideWithValue(await prefs()),
          appSettingsOpenerProvider.overrideWithValue(() async {
            settingsOpened++;
            return true;
          }),
        ],
      );
      await tester.tap(find.text(AlertsStrings.bannerAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AlertsStrings.permissionLater));
      await tester.pumpAndSettle();

      expect(scheduler.permissionRequests, 0);
      expect(settingsOpened, 1, reason: 'falls back to system settings');
    });

    testWidgets('after the first time Enable opens the system settings', (
      tester,
    ) async {
      final scheduler = _Scheduler(enabled: false);
      var settingsOpened = 0;
      await _pump(
        tester,
        extra: [
          reminderSchedulerProvider.overrideWithValue(scheduler),
          sharedPreferencesProvider.overrideWithValue(
            await prefs({kNotificationPromptedKey: true}),
          ),
          appSettingsOpenerProvider.overrideWithValue(() async {
            settingsOpened++;
            return true;
          }),
        ],
      );
      await tester.tap(find.text(AlertsStrings.bannerAction));
      await tester.pumpAndSettle();

      expect(find.text(AlertsStrings.permissionTitle), findsNothing);
      expect(settingsOpened, 1);
    });

    testWidgets('saving an interview with reminders asks once', (tester) async {
      final scheduler = _Scheduler(enabled: false);
      final f = InterviewFixture();
      final preferences = await prefs();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        routedApp(
          pushingHome('/applications/1/interviews/new'),
          overrides: [
            ...f.overrides,
            reminderSchedulerProvider.overrideWithValue(scheduler),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          routes: interviewRoutes(),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> create(String title) async {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final input = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is AppTextField && w.label == InterviewStrings.fieldTitle,
          ),
          matching: find.byType(EditableText),
        );
        await tester.enterText(input, title);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
      }

      await create('First');
      expect(find.text(AlertsStrings.permissionTitle), findsOneWidget);
      await tester.tap(find.text(AlertsStrings.permissionAllow));
      await tester.pumpAndSettle();
      expect(scheduler.permissionRequests, 1);
      expect(preferences.getBool(kNotificationPromptedKey), isTrue);

      await create('Second');
      expect(find.text(AlertsStrings.permissionTitle), findsNothing);
    });
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets('fits 320px at 1.5x text (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        await _pump(
          tester,
          size: const Size(320, 640),
          textScale: 1.5,
          brightness: dark ? Brightness.dark : Brightness.light,
          extra: [
            reminderSchedulerProvider.overrideWithValue(
              _Scheduler(enabled: false),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
