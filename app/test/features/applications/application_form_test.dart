import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobtrail/core/constants/app_constants.dart';
import 'package:jobtrail/core/constants/application_strings.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/utils/date_helpers.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/settings.dart';
import 'package:jobtrail/features/applications/presentation/application_form_screen.dart';
import 'package:jobtrail/features/settings/application/settings_controller.dart';

import 'harness.dart';

Future<AppFixture> _pumpForm(
  WidgetTester tester, {
  int? editId,
  AppFixture? fixture,
  double textScale = 1,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  List<Override> extra = const [],
}) async {
  final f = fixture ?? AppFixture();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final target = editId == null
      ? '/applications/new'
      : '/applications/$editId/edit';
  await tester.pumpWidget(
    routedApp(
      pushingHome(target),
      overrides: [...f.overrides, ...extra],
      textScale: textScale,
      brightness: brightness,
      routes: [
        GoRoute(
          path: '/applications/new',
          builder: (_, _) => const ApplicationFormScreen(),
        ),
        GoRoute(
          path: '/applications/:id/edit',
          builder: (_, s) =>
              ApplicationFormScreen(id: int.parse(s.pathParameters['id']!)),
        ),
      ],
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return f;
}

/// Settings with "Default follow-up" set to Off.
class _FollowUpOffSettings extends SettingsController {
  @override
  Future<Settings> build() async =>
      const Settings().copyWith(clearFollowUpDays: true);
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

Future<void> _fillRequired(WidgetTester tester) async {
  await _enter(tester, ApplicationStrings.fieldJobTitle, 'Flutter Dev');
  await _enter(tester, ApplicationStrings.fieldCompany, 'Acme');
  await _enter(tester, ApplicationStrings.fieldLocation, 'Penang');
}

void main() {
  group('applied date prefill', () {
    Future<void> pumpWith(WidgetTester tester, DateTime? initial) async {
      final f = AppFixture();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        routedApp(
          pushingHome('/applications/new'),
          overrides: f.overrides,
          routes: [
            GoRoute(
              path: '/applications/new',
              builder: (_, _) =>
                  ApplicationFormScreen(initialAppliedDate: initial),
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a past date is used as the applied date', (tester) async {
      await pumpWith(tester, DateTime(2026, 1, 5));
      expect(
        find.text(DateHelpers.formatDate(DateTime(2026, 1, 5))),
        findsOneWidget,
      );
    });

    testWidgets('a future date falls back to today', (tester) async {
      await pumpWith(tester, DateTime.now().add(const Duration(days: 30)));
      expect(find.text(DateHelpers.formatDate(DateTime.now())), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('empty required fields show messages and nothing is sent', (
      tester,
    ) async {
      final f = await _pumpForm(tester);
      await _tapSave(tester);

      expect(find.text(AppStrings.errRequired), findsNWidgets(3));
      expect(f.repo.created, isEmpty);
      expect(find.text(ApplicationStrings.formHasErrors), findsOneWidget);
    });

    testWidgets('link, email and description limits are validated', (
      tester,
    ) async {
      final f = await _pumpForm(tester);
      await _fillRequired(tester);
      await _enter(tester, ApplicationStrings.fieldLink, 'ftp://nope');
      await _enter(
        tester,
        ApplicationStrings.fieldContactEmail,
        'not-an-email',
      );
      await _enter(tester, ApplicationStrings.fieldDescription, 'x' * 10001);
      await _tapSave(tester);

      expect(find.text(AppStrings.errInvalidUrl), findsOneWidget);
      expect(find.text(AppStrings.errInvalidEmail), findsOneWidget);
      expect(
        find.text(AppStrings.errMaxLength(Limits.jobDescription)),
        findsOneWidget,
      );
      expect(f.repo.created, isEmpty);
    });

    testWidgets('titles longer than 100 characters are rejected', (
      tester,
    ) async {
      await _pumpForm(tester);
      await _enter(tester, ApplicationStrings.fieldJobTitle, 'x' * 101);
      await _tapSave(tester);
      expect(find.text(AppStrings.errMaxLength(100)), findsOneWidget);
    });

    testWidgets('the description shows a live counter', (tester) async {
      await _pumpForm(tester);
      await _enter(tester, ApplicationStrings.fieldDescription, 'hello');
      expect(find.text('5 / 10000'), findsOneWidget);
    });
  });

  group('create', () {
    testWidgets('saves a new application and opens its detail', (tester) async {
      final f = await _pumpForm(tester);
      await _fillRequired(tester);
      await _tapSave(tester);

      final draft = f.repo.created.single;
      expect(draft.jobTitle, 'Flutter Dev');
      expect(draft.companyName, 'Acme');
      expect(draft.location, 'Penang');
      expect(draft.workArrangement, WorkArrangement.onsite);
      expect(draft.appliedDate.day, DateTime.now().day);
      expect(draft.jobDescription, isNull, reason: 'blank optionals are null');
      expect(draft.employmentType, isNull);

      final saved = f.backend.applications.values.firstWhere(
        (a) => a.jobTitle == 'Flutter Dev',
      );
      expect(saved.status, ApplicationStatus.applied);
      expect(find.text('DETAIL-${saved.id}'), findsOneWidget);
    });

    testWidgets('sends the chosen arrangement, type, source and optionals', (
      tester,
    ) async {
      final f = await _pumpForm(tester);
      await _fillRequired(tester);

      await tester.ensureVisible(find.text('Remote'));
      await tester.tap(find.text('Remote'));
      await tester.ensureVisible(find.text('Contract'));
      await tester.tap(find.text('Contract'));
      await tester.pump();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<ApplicationSource?>),
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<ApplicationSource?>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Referral').last);
      await tester.pumpAndSettle();
      await _enter(tester, ApplicationStrings.fieldSalary, ' RM 10k ');
      await _enter(
        tester,
        ApplicationStrings.fieldLink,
        'https://jobs.example.com/1',
      );
      await _enter(
        tester,
        ApplicationStrings.fieldContactEmail,
        'hr@acme.example',
      );
      await _tapSave(tester);

      final draft = f.repo.created.single;
      expect(draft.workArrangement, WorkArrangement.remote);
      expect(draft.employmentType, EmploymentType.contract);
      expect(draft.source, ApplicationSource.referral);
      expect(draft.salaryRange, 'RM 10k');
      expect(draft.applicationLink, 'https://jobs.example.com/1');
      expect(draft.contactEmail, 'hr@acme.example');
    });

    testWidgets('tapping the selected employment chip clears it', (
      tester,
    ) async {
      final f = await _pumpForm(tester);
      await _fillRequired(tester);
      await tester.ensureVisible(find.text('Contract'));
      await tester.tap(find.text('Contract'));
      await tester.pump();
      await tester.tap(find.text('Contract'));
      await tester.pump();
      await _tapSave(tester);
      expect(f.repo.created.single.employmentType, isNull);
    });

    testWidgets('server field errors appear under their inputs', (
      tester,
    ) async {
      final f = await _pumpForm(tester);
      f.repo.failNextSave = const ApiFailure(
        code: ApiCodes.validation,
        message: 'Invalid',
        fields: {'jobTitle': 'Title is not allowed', 'contactEmail': 'Bounced'},
        statusCode: 422,
      );
      await _fillRequired(tester);
      await _tapSave(tester);

      expect(find.text('Title is not allowed'), findsOneWidget);
      expect(find.text('Bounced'), findsOneWidget);
      expect(find.text('NEW-FORM'), findsNothing);

      // Editing a field clears its server error.
      await _enter(tester, ApplicationStrings.fieldJobTitle, 'Other title');
      await tester.pump();
      expect(find.text('Title is not allowed'), findsNothing);
    });

    testWidgets('a network failure keeps the form and shows a message', (
      tester,
    ) async {
      final f = await _pumpForm(tester);
      f.repo.failNextSave = const NetworkFailure();
      await _fillRequired(tester);
      await _tapSave(tester);

      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      expect(find.text(ApplicationStrings.newTitle), findsOneWidget);
      expect(find.text('Flutter Dev'), findsOneWidget);
    });
  });

  group('follow-up row', () {
    testWidgets('defaults to today + the setting and can be turned off', (
      tester,
    ) async {
      final f = await _pumpForm(tester);
      final expected = DateTime.now().add(const Duration(days: 7));
      final switchTile = find.byType(SwitchListTile);
      await tester.ensureVisible(switchTile);

      expect(tester.widget<SwitchListTile>(switchTile).value, isTrue);
      expect(find.textContaining('Remind me on'), findsOneWidget);

      await tester.tap(switchTile);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);

      await tester.tap(switchTile);
      await tester.pump();
      await _fillRequired(tester);
      await _tapSave(tester);
      final at = f.repo.created.single.followUpAt!;
      expect(at.day, expected.day);
      expect(at.hour, 9);
    });

    testWidgets('is disabled when the default follow-up setting is Off', (
      tester,
    ) async {
      final f = AppFixture();
      await _pumpForm(
        tester,
        fixture: f,
        extra: [settingsProvider.overrideWith(_FollowUpOffSettings.new)],
      );

      final switchTile = find.byType(SwitchListTile);
      await tester.ensureVisible(switchTile);
      final tile = tester.widget<SwitchListTile>(switchTile);
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
      expect(find.text(ApplicationStrings.followUpOffHint), findsOneWidget);

      await _fillRequired(tester);
      await _tapSave(tester);
      expect(f.repo.created.single.followUpAt, isNull);
    });
  });

  group('edit', () {
    testWidgets('is pre-filled and saves only through update', (tester) async {
      final f = await _pumpForm(tester, editId: 1);
      expect(find.text(ApplicationStrings.editTitle), findsOneWidget);

      final title = tester.widget<EditableText>(
        find.descendant(
          of: _field(ApplicationStrings.fieldJobTitle),
          matching: find.byType(EditableText),
        ),
      );
      expect(title.controller.text, 'Senior Flutter Developer');

      await _enter(
        tester,
        ApplicationStrings.fieldJobTitle,
        'Staff Flutter Developer',
      );
      await _tapSave(tester);

      expect(f.repo.created, isEmpty);
      final sent = f.repo.updated.single;
      expect(sent.id, 1);
      expect(sent.jobTitle, 'Staff Flutter Developer');
      expect(f.backend.applications[1]!.jobTitle, 'Staff Flutter Developer');
      expect(
        f.backend.applications[1]!.status,
        ApplicationStatus.interview,
        reason: 'editing never changes the status',
      );
      expect(find.text('open'), findsOneWidget, reason: 'popped back');
    });

    testWidgets('clearing an optional field sends null', (tester) async {
      final f = await _pumpForm(tester, editId: 1);
      await _enter(tester, ApplicationStrings.fieldSalary, '');
      await _enter(tester, ApplicationStrings.fieldNotes, '   ');
      await _tapSave(tester);

      final sent = f.repo.updated.single;
      expect(sent.salaryRange, isNull);
      expect(sent.notes, isNull);
      expect(f.backend.applications[1]!.salaryRange, isNull);
    });
  });

  group('unsaved changes', () {
    testWidgets('an untouched form closes without asking', (tester) async {
      await _pumpForm(tester);
      await tester.tap(find.byTooltip(ApplicationStrings.closeForm));
      await tester.pumpAndSettle();

      expect(find.text(ApplicationStrings.discardTitle), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a dirty form asks first; Cancel keeps editing', (
      tester,
    ) async {
      await _pumpForm(tester);
      await _enter(tester, ApplicationStrings.fieldJobTitle, 'Half typed');

      await tester.tap(find.byTooltip(ApplicationStrings.closeForm));
      await tester.pumpAndSettle();
      expect(find.text(ApplicationStrings.discardTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text(ApplicationStrings.newTitle), findsOneWidget);
      expect(find.text('Half typed'), findsOneWidget);
    });

    testWidgets('Discard leaves the form', (tester) async {
      final f = await _pumpForm(tester);
      await _enter(tester, ApplicationStrings.fieldJobTitle, 'Half typed');
      await tester.tap(find.widgetWithText(OutlinedButton, AppStrings.cancel));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, ApplicationStrings.discardConfirm),
      );
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(f.repo.created, isEmpty);
    });

    testWidgets('the system back gesture is also guarded', (tester) async {
      await _pumpForm(tester);
      await _enter(tester, ApplicationStrings.fieldNotes, 'something');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(ApplicationStrings.discardTitle), findsOneWidget);
    });

    testWidgets('undoing an edit makes the form clean again', (tester) async {
      await _pumpForm(tester);
      await _enter(tester, ApplicationStrings.fieldNotes, 'x');
      await _enter(tester, ApplicationStrings.fieldNotes, '');
      await tester.tap(find.byTooltip(ApplicationStrings.closeForm));
      await tester.pumpAndSettle();
      expect(find.text(ApplicationStrings.discardTitle), findsNothing);
    });
  });

  group('layout', () {
    for (final dark in [false, true]) {
      testWidgets(
        'no overflow at 320px and 1.5x text (${dark ? 'dark' : 'light'})',
        (tester) async {
          await _pumpForm(
            tester,
            size: const Size(320, 640),
            textScale: 1.5,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          expect(tester.takeException(), isNull);
          await tester.dragUntilVisible(
            find.byType(SwitchListTile),
            find.byType(SingleChildScrollView),
            const Offset(0, -200),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
