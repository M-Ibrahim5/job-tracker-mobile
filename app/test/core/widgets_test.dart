import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/theme/app_theme.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/domain/enums/enums.dart';

import '../helpers/test_app.dart';

void main() {
  group('StatusChip', () {
    testWidgets('shows label and icon for every status in both themes', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final status in ApplicationStatus.values) {
          await tester.pumpWidget(
            testApp(StatusChip(status: status), brightness: brightness),
          );
          expect(find.text(status.label), findsOneWidget);
          expect(find.byIcon(StatusStyle.of(status).icon), findsOneWidget);
        }
      }
    });

    testWidgets('uses the chip colors from the design tokens', (tester) async {
      await tester.pumpWidget(
        testApp(const StatusChip(status: ApplicationStatus.offer)),
      );
      final box = tester.widget<Container>(find.byType(Container).first);
      expect((box.decoration! as BoxDecoration).color, const Color(0xFFE0F2E1));
      final text = tester.widget<Text>(find.text('Offer'));
      expect(text.style!.color, const Color(0xFF1B5E20));
    });
  });

  group('AppTextField', () {
    testWidgets('shows the label above with a required marker', (tester) async {
      await tester.pumpWidget(
        testApp(const AppTextField(label: 'Job title', isRequired: true)),
      );
      expect(
        find.textContaining('Job title', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('*', findRichText: true), findsOneWidget);
    });

    testWidgets('shows validator errors with an icon', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        testApp(
          Form(
            key: key,
            child: AppTextField(
              label: 'Name',
              validator: (v) => (v ?? '').isEmpty ? 'Required!' : null,
            ),
          ),
        ),
      );
      expect(find.text('Required!'), findsNothing);
      key.currentState!.validate();
      await tester.pump();
      expect(find.text('Required!'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('shows an externally supplied error', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        testApp(
          Form(
            key: key,
            child: const AppTextField(label: 'Email', errorText: 'Taken'),
          ),
        ),
      );
      key.currentState!.validate();
      await tester.pump();
      expect(find.text('Taken'), findsOneWidget);
    });

    testWidgets('password field toggles visibility', (tester) async {
      await tester.pumpWidget(
        testApp(const AppTextField(label: 'Password', isPassword: true)),
      );
      bool obscured() =>
          tester.widget<EditableText>(find.byType(EditableText)).obscureText;
      expect(obscured(), isTrue);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(obscured(), isFalse);
    });

    testWidgets('counter shows length against the maximum', (tester) async {
      await tester.pumpWidget(
        testApp(
          const AppTextField(
            label: 'About',
            maxLength: 10000,
            showCounter: true,
            initialValue: 'abc',
          ),
        ),
      );
      expect(find.text('3 / 10000'), findsOneWidget);
    });
  });

  group('SegmentedChoice', () {
    testWidgets('selects the tapped option and shows the selected check', (
      tester,
    ) async {
      var value = WorkArrangement.hybrid;
      await tester.pumpWidget(
        testApp(
          StatefulBuilder(
            builder: (context, setState) => SegmentedChoice<WorkArrangement>(
              values: WorkArrangement.values,
              selected: value,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Remote'));
      await tester.pump();
      expect(value, WorkArrangement.remote);
    });
  });

  group('ChoiceChips', () {
    testWidgets('multi-select toggles membership', (tester) async {
      var selected = <int>{60};
      await tester.pumpWidget(
        testApp(
          StatefulBuilder(
            builder: (context, setState) => ChoiceChips<int>(
              values: const [1440, 60, 15],
              selected: selected,
              labelOf: (v) => '$v min',
              multiSelect: true,
              onChanged: (s) => setState(() => selected = s),
            ),
          ),
        ),
      );
      await tester.tap(find.text('1440 min'));
      await tester.pump();
      expect(selected, {60, 1440});
      await tester.tap(find.text('60 min'));
      await tester.pump();
      expect(selected, {1440});
    });

    testWidgets('single-select replaces the selection', (tester) async {
      var selected = <int>{7};
      await tester.pumpWidget(
        testApp(
          StatefulBuilder(
            builder: (context, setState) => ChoiceChips<int>(
              values: const [3, 5, 7],
              selected: selected,
              labelOf: (v) => '$v days',
              onChanged: (s) => setState(() => selected = s),
            ),
          ),
        ),
      );
      await tester.tap(find.text('3 days'));
      await tester.pump();
      expect(selected, {3});
    });
  });

  group('buttons', () {
    testWidgets('primary button fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        testApp(PrimaryButton(label: 'Go', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('loading state shows a spinner and blocks taps', (
      tester,
    ) async {
      var taps = 0;
      for (final button in <Widget>[
        PrimaryButton(label: 'Go', onPressed: () => taps++, loading: true),
        SecondaryButton(label: 'Go', onPressed: () => taps++, loading: true),
        DestructiveButton(label: 'Go', onPressed: () => taps++, loading: true),
      ]) {
        await tester.pumpWidget(testApp(button));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Go'), findsNothing);
        await tester.tap(find.byType(CircularProgressIndicator));
        expect(taps, 0);
      }
    });

    testWidgets('destructive button uses a 2px error outline', (tester) async {
      await tester.pumpWidget(
        testApp(DestructiveButton(label: 'Log out', onPressed: () {})),
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      final side = button.style!.side!.resolve({})!;
      expect(side.width, 2);
      expect(side.color, AppColors.error);
    });
  });

  group('FormFooter', () {
    testWidgets('cancel and save call back; saving disables both', (
      tester,
    ) async {
      var cancelled = 0;
      var saved = 0;
      Widget footer({bool saving = false}) => testApp(
        FormFooter(
          onCancel: () => cancelled++,
          onSave: () => saved++,
          saving: saving,
        ),
      );

      await tester.pumpWidget(footer());
      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Save'));
      expect((cancelled, saved), (1, 1));

      await tester.pumpWidget(footer(saving: true));
      await tester.tap(find.text('Cancel'), warnIfMissed: false);
      expect(cancelled, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  testWidgets('NoticeBanner shows the message and runs its action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        NoticeBanner(
          message: 'Phone reminders are off',
          actionLabel: 'Enable',
          onAction: () => taps++,
        ),
      ),
    );
    expect(find.text('Phone reminders are off'), findsOneWidget);
    await tester.tap(find.text('Enable'));
    expect(taps, 1);
  });

  group('EmptyState / ErrorState', () {
    testWidgets('empty state shows title, message and action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        testApp(
          EmptyState(
            title: "You're all caught up",
            message: 'No alerts',
            actionLabel: 'Add',
            onAction: () => taps++,
          ),
        ),
      );
      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.text('No alerts'), findsOneWidget);
      await tester.tap(find.text('Add'));
      expect(taps, 1);
    });

    testWidgets('error state retries and explains network failures', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        testApp(
          ErrorState(error: const NetworkFailure(), onRetry: () => retries++),
        ),
      );
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });

  testWidgets('skeletons render placeholders without overflow', (tester) async {
    await tester.pumpWidget(testApp(const SkeletonList(itemCount: 3)));
    expect(find.byType(SkeletonBox), findsNWidgets(3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  group('ConfirmDialog', () {
    Future<void> open(WidgetTester tester, void Function(bool) onResult) async {
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showConfirmDialog(
                  context,
                  title: 'Delete?',
                  message: 'This cannot be undone',
                  confirmLabel: 'Delete',
                  destructive: true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('resolves true on confirm', (tester) async {
      bool? result;
      await open(tester, (r) => result = r);
      expect(find.text('Delete?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('resolves false on cancel', (tester) async {
      bool? result;
      await open(tester, (r) => result = r);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  testWidgets('DateBlock shows day over month', (tester) async {
    await tester.pumpWidget(testApp(DateBlock(date: DateTime(2026, 10, 27))));
    expect(find.text('27'), findsOneWidget);
    expect(find.text('Oct'), findsOneWidget);
    expect(tester.getSize(find.byType(DateBlock)), const Size(52, 56));
  });

  group('UnreadBadge', () {
    test('labels cap at 9+', () {
      expect(UnreadBadge.labelFor(3), '3');
      expect(UnreadBadge.labelFor(9), '9');
      expect(UnreadBadge.labelFor(10), '9+');
    });

    testWidgets('is hidden at zero and announces the count otherwise', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(const UnreadBadge(count: 0, child: Icon(Icons.notifications))),
      );
      expect(find.text('0'), findsNothing);

      await tester.pumpWidget(
        testApp(const UnreadBadge(count: 3, child: Icon(Icons.notifications))),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel('3 unread'), findsOneWidget);
    });
  });

  testWidgets('Eyebrow uppercases its text', (tester) async {
    await tester.pumpWidget(testApp(const Eyebrow('Today')));
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('GroupedCard separates rows with dividers', (tester) async {
    await tester.pumpWidget(
      testApp(const GroupedCard(children: [Text('a'), Text('b'), Text('c')])),
    );
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('widgets survive large text on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        textScale: 1.5,
        ListView(
          children: [
            const StatusChip(status: ApplicationStatus.screening),
            const AppTextField(label: 'Email', isRequired: true),
            SegmentedChoice<WorkArrangement>(
              values: WorkArrangement.values,
              selected: WorkArrangement.onsite,
              labelOf: (v) => v.label,
              onChanged: (_) {},
            ),
            NoticeBanner(
              message: 'Move Northwind Labs from Screening to Interview?',
              actionLabel: 'Yes',
              onAction: () {},
            ),
            ChoiceChips<int>(
              values: const [1, 2, 3, 4],
              selected: const {1},
              labelOf: (v) => '$v hour before',
              onChanged: (_) {},
            ),
            FormFooter(onCancel: () {}, onSave: () {}),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
