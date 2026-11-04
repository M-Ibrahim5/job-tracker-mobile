import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/constants/application_strings.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/features/applications/presentation/application_card.dart';
import 'package:jobtrail/features/applications/presentation/applications_screen.dart';
import 'package:jobtrail/features/applications/presentation/status_change_sheet.dart';

import 'harness.dart';

Future<AppFixture> _pumpList(
  WidgetTester tester, {
  AppFixture? fixture,
  String? initialStatus,
  double textScale = 1,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  bool settle = true,
}) async {
  final f = fixture ?? AppFixture();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routedApp(
      ApplicationsScreen(
        query: {if (initialStatus != null) 'status': initialStatus},
      ),
      overrides: f.overrides,
      textScale: textScale,
      brightness: brightness,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return f;
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Finder _card(String title) =>
    find.widgetWithText(ApplicationCard, title, skipOffstage: false);

void main() {
  group('states', () {
    testWidgets('shows applications, the total, sort caption and Add FAB', (
      tester,
    ) async {
      await _pumpList(tester);

      expect(find.text(ApplicationStrings.listTitle), findsOneWidget);
      expect(find.text('15 total'), findsOneWidget);
      expect(find.text('Sorted by newest first'), findsOneWidget);
      expect(find.text('Mobile Tech Lead'), findsOneWidget);
      expect(
        find.widgetWithText(FloatingActionButton, ApplicationStrings.addFab),
        findsOneWidget,
      );
      // Interview hint on the card with an upcoming interview.
      expect(find.textContaining('Next: '), findsWidgets);
    });

    testWidgets('shows a skeleton while the first page loads', (tester) async {
      final f = AppFixture()..repo.listGate = Completer<void>();
      await _pumpList(tester, fixture: f, settle: false);

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(ApplicationCard), findsNothing);

      f.repo.listGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.byType(ApplicationCard), findsWidgets);
    });

    testWidgets('shows an error with Retry, then the list', (tester) async {
      final f = AppFixture()..repo.failNextList = const NetworkFailure();
      await _pumpList(tester, fixture: f);

      expect(find.byType(ErrorState), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(ApplicationCard), findsWidgets);
    });

    testWidgets('empty list with no data offers to add one', (tester) async {
      final f = AppFixture()..backend.clearData();
      await _pumpList(tester, fixture: f);

      expect(find.text(ApplicationStrings.emptyTitle), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, ApplicationStrings.emptyAction),
      );
      await tester.pumpAndSettle();
      expect(find.text('NEW-FORM'), findsOneWidget);
    });

    testWidgets(
      'searching with no match shows "No results" and can be cleared',
      (tester) async {
        await _pumpList(tester);

        await tester.enterText(find.byType(TextField), 'zzzz-nothing');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text(ApplicationStrings.noResultsTitle), findsOneWidget);
        expect(find.byType(ApplicationCard), findsNothing);

        await tester.tap(find.text(ApplicationStrings.clearFilters));
        await tester.pumpAndSettle();

        expect(find.text(ApplicationStrings.noResultsTitle), findsNothing);
        expect(find.byType(ApplicationCard), findsWidgets);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets('search narrows the list after the debounce', (tester) async {
      final f = await _pumpList(tester);
      final before = f.repo.listCalls.length;

      await tester.enterText(find.byType(TextField), 'orbit');
      await tester.pump(const Duration(milliseconds: 100));
      expect(f.repo.listCalls, hasLength(before), reason: 'debounced');

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(f.repo.listCalls.last.filter.query, 'orbit');
      expect(find.byType(ApplicationCard), findsOneWidget);
      expect(find.text('Flutter Developer'), findsOneWidget);
    });
  });

  group('filtering', () {
    testWidgets('a status chip filters the list and "All" resets it', (
      tester,
    ) async {
      await _pumpList(tester);

      await _tapChip(tester, 'Rejected');
      expect(find.byType(ApplicationCard), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byType(ApplicationCard),
          matching: find.byType(StatusChip),
        ),
        findsNWidgets(3),
      );

      await _tapChip(tester, 'All');
      expect(find.byType(ApplicationCard).evaluate().length, greaterThan(3));
    });

    testWidgets('?status= deep link pre-selects that status', (tester) async {
      await _pumpList(tester, initialStatus: 'offer');

      expect(find.byType(ApplicationCard), findsOneWidget);
      expect(find.text('Flutter Engineer'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Offer'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('the filter sheet applies arrangement and sort', (
      tester,
    ) async {
      final f = await _pumpList(tester);

      await tester.tap(find.byTooltip(ApplicationStrings.filterButton));
      await tester.pumpAndSettle();
      expect(find.text(ApplicationStrings.filterTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Remote').last);
      await tester.tap(find.text('Company A–Z'));
      await tester.pump();
      await tester.ensureVisible(find.text(ApplicationStrings.filterApply));
      await tester.tap(find.text(ApplicationStrings.filterApply));
      await tester.pumpAndSettle();

      final used = f.repo.listCalls.last.filter;
      expect(used.arrangements, {WorkArrangement.remote});
      expect(used.sort, ApplicationSort.companyAZ);
      expect(find.byType(ApplicationCard), findsNWidgets(4));
      expect(find.text('Sorted by company a–z'), findsOneWidget);
      // Two active criteria are flagged on the filter button.
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('swipe actions', () {
    Future<void> swipeLeftAndConfirm(WidgetTester tester) async {
      await tester.drag(find.byType(Dismissible).first, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text(ApplicationStrings.deleteTitle), findsOneWidget);
      await tester.tap(
        find.widgetWithText(TextButton, ApplicationStrings.swipeDelete),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('swipe left → confirm → Undo restores the row, no DELETE', (
      tester,
    ) async {
      final f = await _pumpList(tester);
      expect(_card('Mobile Tech Lead'), findsOneWidget);

      await swipeLeftAndConfirm(tester);
      expect(_card('Mobile Tech Lead'), findsNothing);
      expect(find.text(ApplicationStrings.deleted), findsOneWidget);
      expect(find.text('14 total'), findsOneWidget);
      expect(
        f.repo.deleted,
        isEmpty,
        reason: 'delayed until the snackbar closes',
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));

      expect(_card('Mobile Tech Lead'), findsOneWidget);
      expect(find.text('15 total'), findsOneWidget);
      expect(f.repo.deleted, isEmpty);
    });

    testWidgets('without Undo the DELETE is sent when the snackbar closes', (
      tester,
    ) async {
      final f = await _pumpList(tester);
      final id = f.backend.applications.values
          .firstWhere((a) => a.jobTitle == 'Mobile Tech Lead')
          .id;

      await swipeLeftAndConfirm(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(f.repo.deleted, isEmpty, reason: 'still inside the Undo window');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(f.repo.deleted, [id]);
      expect(f.backend.applications.containsKey(id), isFalse);
      expect(_card('Mobile Tech Lead'), findsNothing);
      expect(find.text('14 total'), findsOneWidget);
    });

    testWidgets('cancelling the confirm dialog keeps the row', (tester) async {
      final f = await _pumpList(tester);
      await tester.drag(find.byType(Dismissible).first, const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(_card('Mobile Tech Lead'), findsOneWidget);
      expect(find.text(ApplicationStrings.deleted), findsNothing);
      expect(f.repo.deleted, isEmpty);
    });

    testWidgets('a failed DELETE brings the row back with a message', (
      tester,
    ) async {
      final f = await _pumpList(tester);
      f.repo.failNextDelete = const NetworkFailure();

      await swipeLeftAndConfirm(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(_card('Mobile Tech Lead'), findsOneWidget);
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
    });

    testWidgets('leaving the screen flushes a pending delete', (tester) async {
      final f = await _pumpList(tester);
      await swipeLeftAndConfirm(tester);
      expect(f.repo.deleted, isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(f.repo.deleted, hasLength(1));
    });

    testWidgets('swipe right opens the status sheet and keeps the row', (
      tester,
    ) async {
      final f = await _pumpList(tester);
      await tester.drag(find.byType(Dismissible).first, const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.byType(StatusChangeSheet), findsOneWidget);
      expect(_card('Mobile Tech Lead'), findsOneWidget);
      expect(f.repo.deleted, isEmpty);
    });
  });

  group('status sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.drag(find.byType(Dismissible).first, const Offset(500, 0));
      await tester.pumpAndSettle();
    }

    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(StatusChangeSheet), matching: f);

    FilledButton confirmButton(WidgetTester tester) => tester.widget(
      inSheet(
        find.widgetWithText(FilledButton, ApplicationStrings.statusConfirm),
      ),
    );

    testWidgets('marks the current and next steps; Confirm needs a choice', (
      tester,
    ) async {
      await _pumpList(tester);
      await openSheet(tester);

      // First row is "Mobile Tech Lead", currently Applied.
      expect(
        inSheet(find.text(ApplicationStrings.statusCurrent)),
        findsOneWidget,
      );
      expect(inSheet(find.text(ApplicationStrings.statusNext)), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);

      // The current status can't be chosen.
      await tester.tap(inSheet(find.text('Applied')));
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNull);

      await tester.tap(inSheet(find.text('Interview')));
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('a note over 500 characters disables Confirm', (tester) async {
      await _pumpList(tester);
      await openSheet(tester);

      await tester.tap(inSheet(find.text('Offer')));
      await tester.enterText(inSheet(find.byType(TextField)), 'x' * 501);
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(inSheet(find.byType(TextField)), 'x' * 500);
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets(
      'Confirm changes the status with the note and updates the row',
      (tester) async {
        final f = await _pumpList(tester);
        await openSheet(tester);

        await tester.tap(inSheet(find.text('Interview')));
        await tester.enterText(
          inSheet(find.byType(TextField)),
          '  Recruiter called ',
        );
        await tester.pump();
        await tester.tap(
          inSheet(
            find.widgetWithText(FilledButton, ApplicationStrings.statusConfirm),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(StatusChangeSheet), findsNothing);
        final change = f.repo.statusChanges.single;
        expect(change.status, ApplicationStatus.interview);
        expect(change.note, 'Recruiter called');
        expect(find.text('Moved to Interview'), findsOneWidget);
        final card = find.widgetWithText(ApplicationCard, 'Mobile Tech Lead');
        expect(
          find.descendant(of: card, matching: find.text('Interview')),
          findsOneWidget,
        );
      },
    );
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets(
        'no overflow at 320px and 1.5x text (${dark ? 'dark' : 'light'})',
        (tester) async {
          await _pumpList(
            tester,
            size: const Size(320, 640),
            textScale: 1.5,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(ApplicationCard), findsWidgets);
        },
      );
    }
  });
}
