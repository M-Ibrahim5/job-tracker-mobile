import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobtrail/core/constants/application_strings.dart';
import 'package:jobtrail/core/services/reminder_scheduler.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/interview.dart';
import 'package:jobtrail/domain/models/job_application.dart';
import 'package:jobtrail/features/applications/application/application_providers.dart';
import 'package:jobtrail/features/applications/presentation/application_detail_screen.dart';
import 'package:jobtrail/features/applications/presentation/detail_sections.dart';
import 'package:jobtrail/features/applications/presentation/status_change_sheet.dart';
import 'package:jobtrail/features/interviews/application/interviews_providers.dart';

import 'harness.dart';

class _RecordingScheduler extends NoopReminderScheduler {
  int resyncs = 0;

  @override
  Future<void> resync() async => resyncs++;
}

/// Opens the detail of application [id] on top of a home route, so deleting
/// has somewhere to return to.
Future<AppFixture> _pumpDetail(
  WidgetTester tester,
  int id, {
  AppFixture? fixture,
  List<Override> extra = const [],
  double textScale = 1,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  int? focusInterview,
}) async {
  final f = fixture ?? AppFixture();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routedApp(
      pushingHome('/applications/$id'),
      overrides: [...f.overrides, ...extra],
      textScale: textScale,
      brightness: brightness,
      routes: [
        GoRoute(
          path: '/applications/:id',
          builder: (_, s) => ApplicationDetailScreen(
            id: int.parse(s.pathParameters['id']!),
            focusInterviewId: focusInterview,
          ),
        ),
        GoRoute(
          path: '/applications/:id/edit',
          builder: (_, _) => const Scaffold(body: Text('EDIT-FORM')),
        ),
        GoRoute(
          path: '/applications/:id/interviews/new',
          builder: (_, _) => const Scaffold(body: Text('NEW-INTERVIEW')),
        ),
      ],
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return f;
}

Finder get _scrollable => find.byType(Scrollable).first;

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapSelector(WidgetTester tester, String label) async {
  final button = find.descendant(
    of: find.byType(StatusSelector),
    matching: find.text(label),
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}

String get _longText =>
    List.generate(40, (i) => 'Sentence number $i about the role.').join(' ');

void main() {
  group('focused interview', () {
    testWidgets('scrolls to the interview and highlights it for ~2 seconds', (
      tester,
    ) async {
      final f = AppFixture();
      final target = f.backend.interviews.values
          .firstWhere((i) => i.applicationId == 1)
          .id;
      // Do not settle: the highlight is timed.
      final futureSetup = _pumpDetail(
        tester,
        1,
        fixture: f,
        focusInterview: target,
      );
      await futureSetup;
      final row = find.byKey(const ValueKey('focused-interview'));
      expect(row, findsOneWidget);
      expect(tester.getRect(row).top, lessThan(844));

      Color? fill() => tester
          .widget<Card>(find.descendant(of: row, matching: find.byType(Card)))
          .color;
      final scheme = Theme.of(tester.element(row)).colorScheme;
      expect(fill(), scheme.primaryContainer);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(fill(), scheme.surface);
    });

    testWidgets('no highlight without a focus', (tester) async {
      await _pumpDetail(tester, 1);
      expect(find.byKey(const ValueKey('focused-interview')), findsNothing);
    });
  });

  group('content', () {
    testWidgets('shows header, details, notes and the status timeline', (
      tester,
    ) async {
      await _pumpDetail(tester, 1);

      expect(find.text('Senior Flutter Developer'), findsOneWidget);
      expect(find.text('Northwind Labs'), findsOneWidget);
      expect(find.text('Kuala Lumpur'), findsOneWidget);
      expect(find.text('Hybrid'), findsOneWidget);
      expect(find.text('Full-time'), findsOneWidget);
      expect(find.text('RM 9,000 – 12,000'), findsOneWidget);

      await _scrollTo(tester, find.text('Screening → Interview'));
      expect(find.text('Screening → Interview'), findsOneWidget);
      expect(find.text('Applied → Screening'), findsOneWidget);
      expect(find.textContaining('Applied · '), findsOneWidget);
      expect(find.text('Recruiter called'), findsOneWidget);

      await _scrollTo(tester, find.text(ApplicationStrings.detailAppliedOn));
      expect(find.text(ApplicationStrings.sectionNotes), findsOneWidget);
      expect(find.text('Recruiter was friendly.'), findsOneWidget);
    });

    testWidgets('newest timeline entry is first', (tester) async {
      await _pumpDetail(tester, 1);
      await _scrollTo(tester, find.text('Screening → Interview'));

      final newest = tester.getTopLeft(find.text('Screening → Interview')).dy;
      final older = tester.getTopLeft(find.text('Applied → Screening')).dy;
      expect(newest, lessThan(older));
    });

    testWidgets('interviews come from interviewsForApplicationProvider', (
      tester,
    ) async {
      await _pumpDetail(tester, 3); // no interviews yet
      await _scrollTo(tester, find.text(ApplicationStrings.sectionInterviews));
      expect(find.text(ApplicationStrings.noInterviews), findsOneWidget);
    });

    testWidgets('interview rows show time, type, duration and outcome', (
      tester,
    ) async {
      final soon = DateTime.now().add(const Duration(days: 2));
      await _pumpDetail(
        tester,
        1,
        extra: [
          interviewsForApplicationProvider.overrideWith(
            (ref, id) async => [
              Interview(
                id: 9,
                applicationId: id,
                title: 'Technical round',
                type: InterviewType.technical,
                scheduledAt: soon,
                durationMinutes: 45,
              ),
            ],
          ),
        ],
      );
      await _scrollTo(tester, find.text('Technical round'));
      expect(find.textContaining('Technical · 45 min'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });
  });

  group('job description', () {
    testWidgets('long text is clamped; Read more expands, Show less collapses', (
      tester,
    ) async {
      final f = AppFixture();
      final app = f.backend.applications[1]!;
      f.backend.applications[1] = app.copyWith(jobDescription: _longText);
      // A tall viewport keeps the whole page built while it grows and shrinks.
      await _pumpDetail(tester, 1, fixture: f, size: const Size(390, 3000));

      await _scrollTo(tester, find.text(ApplicationStrings.readMore));
      Text body() => tester.widget<Text>(
        find.descendant(
          of: find.byType(ExpandableText),
          matching: find.textContaining(
            'Sentence number 0',
            skipOffstage: false,
          ),
        ),
      );
      expect(body().maxLines, 3);

      await tester.tap(find.text(ApplicationStrings.readMore));
      await tester.pump();
      expect(body().maxLines, isNull);
      expect(find.text(ApplicationStrings.readLess), findsOneWidget);
      expect(find.text(ApplicationStrings.readMore), findsNothing);

      await tester.ensureVisible(find.text(ApplicationStrings.readLess));
      await tester.pump();
      await tester.tap(find.text(ApplicationStrings.readLess));
      await tester.pump();
      expect(body().maxLines, 3);
    });

    testWidgets('short text has no Read more', (tester) async {
      final f = AppFixture();
      final app = f.backend.applications[1]!;
      f.backend.applications[1] = app.copyWith(jobDescription: 'Short.');
      await _pumpDetail(tester, 1, fixture: f);

      await _scrollTo(tester, find.text('Short.'));
      expect(find.text(ApplicationStrings.readMore), findsNothing);
    });
  });

  group('quick actions', () {
    testWidgets('Open link launches the saved URL', (tester) async {
      final opened = <Uri>[];
      await _pumpDetail(
        tester,
        1,
        extra: [
          urlLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );

      await tester.tap(find.text(ApplicationStrings.actionOpenLink));
      await tester.pump();
      expect(
        opened.single.toString(),
        'https://careers.example.com/northwind-labs',
      );
    });

    testWidgets('a failed launch shows a snackbar', (tester) async {
      await _pumpDetail(
        tester,
        1,
        extra: [urlLauncherProvider.overrideWithValue((_) async => false)],
      );
      await tester.tap(find.text(ApplicationStrings.actionOpenLink));
      await tester.pump();
      expect(find.text(ApplicationStrings.linkOpenFailed), findsOneWidget);
    });

    testWidgets('without a link, Open link explains instead of launching', (
      tester,
    ) async {
      final f = AppFixture();
      final app = f.backend.applications[1]!;
      f.backend.applications[1] = _withoutLink(app);
      final opened = <Uri>[];
      await _pumpDetail(
        tester,
        1,
        fixture: f,
        extra: [
          urlLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      await tester.tap(find.text(ApplicationStrings.actionOpenLink));
      await tester.pump();
      expect(opened, isEmpty);
      expect(find.text(ApplicationStrings.noLinkSaved), findsOneWidget);
    });

    testWidgets('tapping the contact email opens a mailto link', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pumpDetail(
        tester,
        1,
        extra: [
          urlLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      final contact = find.textContaining('aisha@northwindlabs.example');
      await _scrollTo(tester, contact);
      await tester.tap(contact);
      await tester.pump();
      expect(opened.single.scheme, 'mailto');
      expect(opened.single.path, 'aisha@northwindlabs.example');
    });

    testWidgets('Interview opens the new-interview form for this application', (
      tester,
    ) async {
      await _pumpDetail(tester, 1);
      await tester.tap(
        find.descendant(
          of: find.byType(QuickActions),
          matching: find.text(ApplicationStrings.actionInterview),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NEW-INTERVIEW'), findsOneWidget);
    });

    testWidgets('Follow-up sets a date through the date picker', (
      tester,
    ) async {
      final f = await _pumpDetail(tester, 1);
      expect(f.backend.applications[1]!.followUpAt, isNull);

      await tester.tap(find.text(ApplicationStrings.actionFollowUp));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final saved = f.repo.updated.single;
      expect(saved.id, 1);
      expect(saved.followUpAt, isNotNull);
      expect(saved.followUpAt!.hour, 9);
      expect(find.text(ApplicationStrings.followUpSaved), findsOneWidget);
      expect(f.backend.applications[1]!.followUpAt, isNotNull);
    });

    testWidgets('Follow-up can be cleared when one is set', (tester) async {
      final f = await _pumpDetail(tester, 2);
      expect(f.backend.applications[2]!.followUpAt, isNotNull);

      await tester.tap(find.text(ApplicationStrings.actionFollowUp));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ApplicationStrings.followUpClear));
      await tester.pumpAndSettle();

      expect(f.repo.updated.single.followUpAt, isNull);
      expect(f.backend.applications[2]!.followUpAt, isNull);
      expect(find.text(ApplicationStrings.followUpCleared), findsOneWidget);
    });

    testWidgets('Edit opens the edit form', (tester) async {
      await _pumpDetail(tester, 1);
      await tester.tap(find.byTooltip(ApplicationStrings.detailEdit));
      await tester.pumpAndSettle();
      expect(find.text('EDIT-FORM'), findsOneWidget);
    });
  });

  group('status', () {
    testWidgets(
      'choosing a status opens the sheet preselected and applies it',
      (tester) async {
        final f = await _pumpDetail(tester, 1);

        await _scrollTo(tester, find.text(ApplicationStrings.statusHelper));
        await _tapSelector(tester, 'Offer');
        await tester.pumpAndSettle();
        expect(find.byType(StatusChangeSheet), findsOneWidget);

        await tester.enterText(
          find.descendant(
            of: find.byType(StatusChangeSheet),
            matching: find.byType(TextField),
          ),
          'Verbal offer',
        );
        await tester.tap(find.text(ApplicationStrings.statusConfirm));
        await tester.pumpAndSettle();

        expect(f.repo.statusChanges.single.status, ApplicationStatus.offer);
        expect(f.repo.statusChanges.single.note, 'Verbal offer');
        // Timeline, header chip and the helper all refresh.
        await _scrollTo(tester, find.text('Interview → Offer'));
        expect(find.text('Verbal offer'), findsOneWidget);
      },
    );

    testWidgets('a Rejected application can be reopened to any status', (
      tester,
    ) async {
      final f = AppFixture();
      final rejected = f.backend.applications.values.firstWhere(
        (a) => a.status == ApplicationStatus.rejected,
      );
      await _pumpDetail(tester, rejected.id, fixture: f);

      await _scrollTo(tester, find.text(ApplicationStrings.statusHelper));
      await _tapSelector(tester, 'Interview');
      await tester.pumpAndSettle();
      await tester.tap(find.text(ApplicationStrings.statusConfirm));
      await tester.pumpAndSettle();

      expect(
        f.backend.applications[rejected.id]!.status,
        ApplicationStatus.interview,
      );
      await _scrollTo(tester, find.text('Rejected → Interview'));
    });
  });

  group('delete', () {
    testWidgets('warns about upcoming interviews, deletes and returns', (
      tester,
    ) async {
      final scheduler = _RecordingScheduler();
      final f = await _pumpDetail(
        tester,
        1,
        extra: [reminderSchedulerProvider.overrideWithValue(scheduler)],
      );

      await tester.tap(find.byTooltip(ApplicationStrings.detailDelete));
      await tester.pumpAndSettle();
      expect(find.text(ApplicationStrings.deleteTitle), findsOneWidget);
      expect(find.textContaining('upcoming interviews'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(TextButton, ApplicationStrings.detailDelete),
      );
      await tester.pumpAndSettle();

      expect(f.repo.deleted, [1]);
      expect(f.backend.applications.containsKey(1), isFalse);
      expect(scheduler.resyncs, 1);
      expect(
        find.text('open'),
        findsOneWidget,
        reason: 'back on the home route',
      );
      expect(find.text(ApplicationStrings.deleted), findsOneWidget);
    });

    testWidgets('no warning without upcoming interviews; Cancel keeps it', (
      tester,
    ) async {
      final f = await _pumpDetail(tester, 3);
      await tester.tap(find.byTooltip(ApplicationStrings.detailDelete));
      await tester.pumpAndSettle();
      expect(find.textContaining('upcoming interviews'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(f.repo.deleted, isEmpty);
      expect(find.text('Mobile Engineer'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets(
        'no overflow at 320px and 1.5x text (${dark ? 'dark' : 'light'})',
        (tester) async {
          await _pumpDetail(
            tester,
            1,
            size: const Size(320, 640),
            textScale: 1.5,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          expect(tester.takeException(), isNull);
          await _scrollTo(tester, find.text(ApplicationStrings.statusHelper));
          expect(tester.takeException(), isNull);
          await _scrollTo(tester, find.text(ApplicationStrings.sectionNotes));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

/// Copy of [a] without a link (`copyWith` can't clear it).
JobApplication _withoutLink(JobApplication a) => JobApplication(
  id: a.id,
  jobTitle: a.jobTitle,
  companyName: a.companyName,
  location: a.location,
  workArrangement: a.workArrangement,
  appliedDate: a.appliedDate,
  status: a.status,
  createdAt: a.createdAt,
  updatedAt: a.updatedAt,
);
