import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobtrail/core/constants/app_constants.dart';
import 'package:jobtrail/core/constants/interview_strings.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/features/applications/application/application_providers.dart';
import 'package:jobtrail/features/interviews/presentation/interview_form_screen.dart';
import 'package:jobtrail/features/interviews/presentation/interview_tile.dart';
import 'package:jobtrail/features/interviews/presentation/interviews_screen.dart';

import '../applications/harness.dart';
import 'interviews_harness.dart';

Future<InterviewFixture> _pump(
  WidgetTester tester,
  Widget home, {
  InterviewFixture? fixture,
  List<GoRoute> routes = const [],
  List<Override> extra = const [],
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final f = fixture ?? InterviewFixture();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routedApp(
      home,
      overrides: [...f.overrides, ...extra],
      routes: [...routes, ...interviewRoutes()],
      textScale: textScale,
      brightness: brightness,
    ),
  );
  await tester.pumpAndSettle();
  return f;
}

Future<InterviewFixture> _pumpPushed(
  WidgetTester tester,
  String target, {
  InterviewFixture? fixture,
  List<GoRoute> routes = const [],
  List<Override> extra = const [],
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final f = await _pump(
    tester,
    pushingHome(target),
    fixture: fixture,
    routes: routes,
    extra: extra,
    size: size,
    textScale: textScale,
    brightness: brightness,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return f;
}

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is AppTextField && w.label == label,
  description: 'AppTextField($label)',
);

Future<void> _enter(WidgetTester tester, String label, String text) async {
  final input = find.descendant(
    of: _field(label),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(input);
  await tester.enterText(input, text);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text, skipOffstage: false);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Route that opens the new-interview form for [applicationId] on [date].
GoRoute _formOn(int applicationId, DateTime date) => GoRoute(
  path: '/form',
  builder: (_, _) =>
      InterviewFormScreen(applicationId: applicationId, initialDate: date),
);

void main() {
  group('list', () {
    testWidgets('Upcoming lists future interviews soonest first', (
      tester,
    ) async {
      await _pump(tester, const InterviewsScreen());

      final titles = [
        'Technical interview · Round 2',
        'HR chat',
        'Final round',
      ];
      final ys = [for (final t in titles) tester.getTopLeft(find.text(t)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Screening call'), findsNothing);
      expect(find.textContaining('Northwind Labs · '), findsOneWidget);
      expect(find.text('Pending'), findsNWidgets(3));
    });

    testWidgets('Past tab lists finished interviews', (tester) async {
      await _pump(tester, const InterviewsScreen());
      await tester.tap(find.text(InterviewStrings.tabPast));
      await tester.pumpAndSettle();

      expect(find.text('Screening call'), findsOneWidget);
      expect(find.text('HR chat'), findsNothing);
    });

    testWidgets('empty tabs explain themselves', (tester) async {
      final f = InterviewFixture()..backend.interviews.clear();
      await _pump(tester, const InterviewsScreen(), fixture: f);
      expect(find.text(InterviewStrings.emptyUpcomingTitle), findsOneWidget);
      await tester.tap(find.text(InterviewStrings.tabPast));
      await tester.pumpAndSettle();
      expect(find.text(InterviewStrings.emptyPastTitle), findsOneWidget);
    });

    testWidgets('shows an error with Retry', (tester) async {
      final f = InterviewFixture()
        ..interviews.failNextList = const NetworkFailure();
      await _pump(tester, const InterviewsScreen(), fixture: f);
      expect(find.byType(ErrorState), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(InterviewTile), findsNWidgets(3));
    });

    testWidgets('tapping a row opens its detail', (tester) async {
      await _pump(tester, const InterviewsScreen());
      await tester.tap(find.text('HR chat'));
      await tester.pumpAndSettle();
      expect(find.text(InterviewStrings.detailTitle), findsOneWidget);
      expect(find.text('Helio Systems · Software Engineer'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets('shows fields and reminder offsets', (tester) async {
      await _pumpPushed(tester, '/interviews/1');
      expect(find.text('Technical interview · Round 2'), findsOneWidget);
      expect(
        find.text('Northwind Labs · Senior Flutter Developer'),
        findsOneWidget,
      );
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('Daniel Lim'), findsOneWidget);
      expect(find.text('1 day before, 1 hour before'), findsOneWidget);
    });

    testWidgets('changing the outcome saves it', (tester) async {
      final f = await _pumpPushed(tester, '/interviews/1');
      await _tapText(tester, 'Passed');

      expect(f.interviews.updated.single.outcome, InterviewOutcome.passed);
      expect(f.backend.interviews[1]!.outcome, InterviewOutcome.passed);
      expect(find.text(InterviewStrings.outcomeSaved), findsOneWidget);
    });

    testWidgets('the meeting link opens externally', (tester) async {
      final opened = <Uri>[];
      await _pumpPushed(
        tester,
        '/interviews/1',
        extra: [
          urlLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      await tester.tap(find.text(InterviewStrings.openLink));
      await tester.pump();
      expect(opened.single.toString(), 'https://meet.example.com/abc');
    });

    testWidgets('a street address has no Open link button', (tester) async {
      await _pumpPushed(tester, '/interviews/2'); // phone, address text
      expect(find.text(InterviewStrings.openLink), findsNothing);
      expect(find.text('Level 12, KL Sentral'), findsOneWidget);
    });

    testWidgets('delete confirms, removes it and returns', (tester) async {
      final f = await _pumpPushed(tester, '/interviews/1');
      await tester.tap(find.byTooltip(InterviewStrings.delete));
      await tester.pumpAndSettle();
      expect(find.text(InterviewStrings.deleteTitle), findsOneWidget);
      await tester.tap(
        find.widgetWithText(TextButton, InterviewStrings.delete),
      );
      await tester.pumpAndSettle();

      expect(f.interviews.deleted, [1]);
      expect(f.backend.interviews.containsKey(1), isFalse);
      expect(find.text('open'), findsOneWidget);
      expect(find.text(InterviewStrings.deleted), findsOneWidget);
    });

    testWidgets('Edit opens the form pre-filled', (tester) async {
      await _pumpPushed(tester, '/interviews/1');
      await tester.tap(find.byTooltip(InterviewStrings.edit));
      await tester.pumpAndSettle();
      expect(find.text(InterviewStrings.editTitle), findsOneWidget);
      final title = tester.widget<EditableText>(
        find.descendant(
          of: _field(InterviewStrings.fieldTitle),
          matching: find.byType(EditableText),
        ),
      );
      expect(title.controller.text, 'Technical interview · Round 2');
    });
  });

  group('form', () {
    testWidgets('requires a title', (tester) async {
      final f = await _pumpPushed(tester, '/applications/1/interviews/new');
      await _tapSave(tester);
      expect(find.text(AppStrings.errRequired), findsOneWidget);
      expect(f.interviews.created, isEmpty);
    });

    testWidgets('creates an interview for the locked application', (
      tester,
    ) async {
      final f = await _pumpPushed(tester, '/applications/1/interviews/new');
      expect(
        find.text('Northwind Labs · Senior Flutter Developer'),
        findsOneWidget,
      );

      await _enter(tester, InterviewStrings.fieldTitle, 'Culture chat');
      await _enter(tester, InterviewStrings.fieldInterviewer, 'Sam');
      await _tapText(tester, 'Phone');
      await _tapSave(tester);

      final made = f.interviews.created.single;
      expect(made.applicationId, 1);
      expect(made.interview.title, 'Culture chat');
      expect(made.interview.type, InterviewType.phone);
      expect(made.interview.interviewerName, 'Sam');
      expect(made.interview.durationMinutes, 60);
      expect(made.interview.scheduledAt.hour, 10);
      expect(made.interview.locationOrLink, isNull);
      expect(find.text('open'), findsOneWidget, reason: 'popped after saving');
    });

    testWidgets('reminders default to the settings and can be customised', (
      tester,
    ) async {
      final f = await _pumpPushed(tester, '/applications/1/interviews/new');

      FilterChip chip(String label) =>
          tester.widget(find.widgetWithText(FilterChip, label));
      expect(chip('1 day before').selected, isTrue);
      expect(chip('1 hour before').selected, isTrue);
      expect(chip('15 min before').selected, isFalse);

      await _tapText(tester, '15 min before');
      await _tapText(tester, '1 day before');
      await _tapText(tester, InterviewStrings.customReminder);
      await tester.enterText(find.byType(TextField).last, '30');
      await tester.tap(find.text(InterviewStrings.customReminderAdd));
      await tester.pumpAndSettle();
      expect(chip('30 min before').selected, isTrue);

      await _enter(tester, InterviewStrings.fieldTitle, 'Round 3');
      await _tapSave(tester);
      expect(f.interviews.created.single.interview.reminderOffsets, [
        const Duration(hours: 1),
        const Duration(minutes: 30),
        const Duration(minutes: 15),
      ]);
    });

    testWidgets('at most five reminders', (tester) async {
      await _pumpPushed(tester, '/applications/1/interviews/new');
      await _tapText(tester, '15 min before'); // 3 selected
      for (final m in ['30', '45']) {
        await _tapText(tester, InterviewStrings.customReminder);
        await tester.enterText(find.byType(TextField).last, m);
        await tester.tap(find.text(InterviewStrings.customReminderAdd));
        await tester.pumpAndSettle();
      }
      await _tapText(tester, InterviewStrings.customReminder);
      await tester.enterText(find.byType(TextField).last, '5');
      await tester.tap(find.text(InterviewStrings.customReminderAdd));
      await tester.pumpAndSettle();

      expect(find.text(InterviewStrings.tooManyReminders), findsOneWidget);
      expect(find.text('5 min before'), findsNothing);
    });

    testWidgets('a custom reminder over 30 days is rejected', (tester) async {
      await _pumpPushed(tester, '/applications/1/interviews/new');
      await _tapText(tester, InterviewStrings.customReminder);
      await tester.enterText(find.byType(TextField).last, '50000');
      await tester.tap(find.text(InterviewStrings.customReminderAdd));
      await tester.pump();
      expect(find.textContaining('At most 43200'), findsOneWidget);
    });

    testWidgets('a past date warns but still saves', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final f = await _pumpPushed(
        tester,
        '/form',
        routes: [_formOn(1, yesterday)],
      );
      expect(find.text(InterviewStrings.pastWarning), findsOneWidget);

      await _enter(tester, InterviewStrings.fieldTitle, 'Back-dated');
      await _tapSave(tester);
      expect(f.interviews.created, hasLength(1));
    });

    testWidgets('a future date has no warning', (tester) async {
      await _pumpPushed(tester, '/applications/1/interviews/new');
      expect(find.text(InterviewStrings.pastWarning), findsNothing);
    });

    testWidgets('the same application and time is a blocking time error', (
      tester,
    ) async {
      final f = InterviewFixture();
      final clash = f.backend.interviews[1]!.scheduledAt;
      await _pumpPushed(
        tester,
        '/form',
        fixture: f,
        routes: [_formOn(1, clash)],
      );
      await _enter(tester, InterviewStrings.fieldTitle, 'Duplicate');
      await _tapSave(tester);

      expect(find.text(AppStrings.errInterviewConflict), findsOneWidget);
      expect(
        find.text(InterviewStrings.newTitle),
        findsOneWidget,
        reason: 'stays open',
      );
      expect(f.backend.interviews.length, 4);
    });

    testWidgets('other server field errors land on their inputs', (
      tester,
    ) async {
      final f = InterviewFixture();
      f.interviews.failNextSave = const ApiFailure(
        code: ApiCodes.validation,
        message: 'Bad',
        fields: {'title': 'Title too spicy'},
        statusCode: 422,
      );
      await _pumpPushed(tester, '/applications/1/interviews/new', fixture: f);
      await _enter(tester, InterviewStrings.fieldTitle, 'x');
      await _tapSave(tester);
      expect(find.text('Title too spicy'), findsOneWidget);
    });

    testWidgets('without a locked application you pick one', (tester) async {
      final f = await _pumpPushed(tester, '/interviews/new');
      await _enter(tester, InterviewStrings.fieldTitle, 'Intro');
      await _tapSave(tester);
      expect(find.text(InterviewStrings.pickApplication), findsWidgets);
      expect(f.interviews.created, isEmpty);

      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lumen Pay · Mobile Engineer').last);
      await tester.pumpAndSettle();
      await _tapSave(tester); // answer the status suggestion
      await tester.tap(find.text(InterviewStrings.suggestNo));
      await tester.pumpAndSettle();

      expect(f.interviews.created.single.applicationId, 3);
    });

    testWidgets('the ?date= value pre-fills the date', (tester) async {
      await _pumpPushed(tester, '/interviews/new?date=2030-01-15');
      final date = tester.widget<EditableText>(
        find.descendant(
          of: _field(InterviewStrings.fieldDate),
          matching: find.byType(EditableText),
        ),
      );
      expect(date.controller.text, contains('2030'));
      expect(date.controller.text, contains('15'));
    });
  });

  group('status suggestion', () {
    // Application 3 (Lumen Pay) is Applied with no interviews.
    Future<InterviewFixture> fillAndSave(WidgetTester tester, int appId) async {
      final f = await _pumpPushed(
        tester,
        '/applications/$appId/interviews/new',
      );
      await _enter(tester, InterviewStrings.fieldTitle, 'First call');
      await _tapSave(tester);
      return f;
    }

    testWidgets('Yes creates the interview and moves the application', (
      tester,
    ) async {
      final f = await fillAndSave(tester, 3);
      expect(
        find.text(InterviewStrings.suggestMessage('Lumen Pay', 'Applied')),
        findsOneWidget,
      );
      expect(f.interviews.created, isEmpty, reason: 'asked before saving');

      await tester.tap(find.text(InterviewStrings.suggestYes));
      await tester.pumpAndSettle();

      expect(f.interviews.created, hasLength(1));
      expect(f.backend.applications[3]!.status, ApplicationStatus.interview);
      expect(
        f.backend.history.where((h) => h.applicationId == 3).last.toStatus,
        ApplicationStatus.interview,
      );
    });

    testWidgets('Not now creates the interview only', (tester) async {
      final f = await fillAndSave(tester, 3);
      await tester.tap(find.text(InterviewStrings.suggestNo));
      await tester.pumpAndSettle();

      expect(f.interviews.created, hasLength(1));
      expect(f.backend.applications[3]!.status, ApplicationStatus.applied);
    });

    testWidgets('is also offered from Screening', (tester) async {
      final f = await fillAndSave(tester, 2);
      expect(
        find.text(InterviewStrings.suggestMessage('Orbit Health', 'Screening')),
        findsOneWidget,
      );
      await tester.tap(find.text(InterviewStrings.suggestYes));
      await tester.pumpAndSettle();
      expect(f.backend.applications[2]!.status, ApplicationStatus.interview);
    });

    testWidgets('is not offered when the application is already in Interview', (
      tester,
    ) async {
      final f = await fillAndSave(tester, 1);
      expect(find.text(InterviewStrings.suggestTitle), findsNothing);
      expect(f.interviews.created, hasLength(1));
    });

    testWidgets('is only offered for the first interview', (tester) async {
      final f = InterviewFixture();
      await FakeInterviewRepositoryHelper.add(f, 3);
      await fillAndSave2(tester, f);
      expect(find.text(InterviewStrings.suggestTitle), findsNothing);
      expect(f.interviews.created, hasLength(1));
      expect(f.backend.applications[3]!.status, ApplicationStatus.applied);
    });

    testWidgets('dismissing the question counts as Not now', (tester) async {
      final f = await fillAndSave(tester, 3);
      await tester.tapAt(const Offset(5, 5)); // barrier
      await tester.pumpAndSettle();
      expect(f.interviews.created, hasLength(1));
      expect(f.backend.applications[3]!.status, ApplicationStatus.applied);
    });

    testWidgets('editing never asks', (tester) async {
      final f = await _pumpPushed(tester, '/interviews/2/edit'); // app 7
      await _enter(tester, InterviewStrings.fieldTitle, 'HR chat (moved)');
      await _tapSave(tester);
      expect(find.text(InterviewStrings.suggestTitle), findsNothing);
      expect(f.interviews.updated.single.title, 'HR chat (moved)');
    });
  });

  group('edit and unsaved changes', () {
    testWidgets('saves changes through update and keeps the outcome', (
      tester,
    ) async {
      final f = await _pumpPushed(tester, '/interviews/1/edit');
      await _enter(tester, InterviewStrings.fieldTitle, 'Renamed');
      await _tapSave(tester);

      final sent = f.interviews.updated.single;
      expect(sent.id, 1);
      expect(sent.title, 'Renamed');
      expect(sent.outcome, InterviewOutcome.pending);
      expect(f.backend.interviews[1]!.title, 'Renamed');
      expect(f.interviews.created, isEmpty);
    });

    testWidgets('a clean form closes without asking', (tester) async {
      await _pumpPushed(tester, '/applications/1/interviews/new');
      await tester.tap(find.byTooltip(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text(InterviewStrings.discardTitle), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a dirty form asks; Discard leaves, Cancel stays', (
      tester,
    ) async {
      await _pumpPushed(tester, '/applications/1/interviews/new');
      await _enter(tester, InterviewStrings.fieldTitle, 'Draft');
      await tester.tap(find.byTooltip(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text(InterviewStrings.discardTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text(InterviewStrings.newTitle), findsOneWidget);

      await tester.tap(find.byTooltip(AppStrings.cancel));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, InterviewStrings.discardConfirm),
      );
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('caches', () {
    testWidgets('saving bumps the revisions that trigger a reminder resync', (
      tester,
    ) async {
      await _pumpPushed(tester, '/applications/1/interviews/new');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterviewForm)),
      );
      final before = container.read(applicationsRevisionProvider);
      await _enter(tester, InterviewStrings.fieldTitle, 'Sync me');
      await _tapSave(tester);
      expect(container.read(applicationsRevisionProvider), greaterThan(before));
    });
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets(
        'form, list and detail fit 320px at 1.5x text (${dark ? 'dark' : 'light'})',
        (tester) async {
          final brightness = dark ? Brightness.dark : Brightness.light;
          await _pumpPushed(
            tester,
            '/applications/1/interviews/new',
            size: const Size(320, 640),
            textScale: 1.5,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          await tester.dragUntilVisible(
            find.text(InterviewStrings.fieldNotes),
            find.byType(SingleChildScrollView),
            const Offset(0, -200),
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('list and detail (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        final brightness = dark ? Brightness.dark : Brightness.light;
        await _pump(
          tester,
          const InterviewsScreen(),
          size: const Size(320, 640),
          textScale: 1.5,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('HR chat'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Adds an interview to [appId] straight in the fake backend.
abstract final class FakeInterviewRepositoryHelper {
  static Future<void> add(InterviewFixture f, int appId) async {
    final base = f.backend.interviews[1]!;
    await f.interviews.create(
      appId,
      base.copyWith(
        scheduledAt: DateTime.now().add(const Duration(days: 40)),
        title: 'Existing',
      ),
    );
    f.interviews.created.clear();
  }
}

Future<void> fillAndSave2(WidgetTester tester, InterviewFixture f) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routedApp(
      pushingHome('/applications/3/interviews/new'),
      overrides: f.overrides,
      routes: interviewRoutes(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await _enter(tester, InterviewStrings.fieldTitle, 'Second call');
  await _tapSave(tester);
}
