// Same flow as integration_test/happy_path_test.dart, run headless with the
// plain test binding so `flutter test` covers it without a device.
// End-to-end happy path through the real widget tree:
// register -> add application -> move to Interview -> add interview ->
// Dashboard (upcoming) -> Calendar (marker + agenda) -> Alerts (entry + badge)
// -> log out.
//
// Default: runs against the in-memory fake backend, no server needed:
//   flutter test integration_test/happy_path_test.dart
//   flutter test integration_test/happy_path_test.dart -d <device>   (on a device)
//
// Against a real server (start `../backend` first; use your emulator's URL):
//   flutter test integration_test/happy_path_test.dart -d <device> \
//     --dart-define=REAL_BACKEND=true \
//     --dart-define=API_BASE_URL=http://localhost:3000/api/v1
// Each run registers a fresh account, so it can be repeated.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/app.dart';
import 'package:jobtrail/core/constants/account_strings.dart';
import 'package:jobtrail/core/constants/alerts_strings.dart';
import 'package:jobtrail/core/constants/app_constants.dart';
import 'package:jobtrail/core/constants/application_strings.dart';
import 'package:jobtrail/core/constants/dashboard_strings.dart';
import 'package:jobtrail/core/constants/interview_strings.dart';
import 'package:jobtrail/core/widgets/widgets.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/features/applications/presentation/detail_sections.dart';
import 'package:jobtrail/features/calendar/presentation/calendar_widgets.dart';
import 'package:jobtrail/domain/enums/enums.dart';

import '../helpers/test_app.dart';
import 'package:jobtrail/features/calendar/application/calendar_logic.dart';
import 'package:table_calendar/table_calendar.dart';

const _realBackend = bool.fromEnvironment('REAL_BACKEND');

/// Waits for animations and network calls. Real servers get a longer budget.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: _realBackend ? 30 : 10),
);

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
  matching: find.byType(EditableText),
);

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _tabTo(WidgetTester tester, String label) => _tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'register → application → interview → dashboard, calendar, alerts → logout',
    (tester) async {
      final email = 'it${DateTime.now().millisecondsSinceEpoch}@jobtrail.test';
      const password = 'Passw0rd!x';

      await tester.pumpWidget(
        ProviderScope(
          overrides: _realBackend
              ? const []
              : fakeOverrides(FakeBackend(latency: Duration.zero)),
          child: const JobTrailApp(useGoogleFonts: false),
        ),
      );
      await _settle(tester);

      // 1. Register.
      await _tap(tester, find.text(AccountStrings.createAccountLink));
      await _type(tester, AccountStrings.fullName, 'Iris Tester');
      await _type(tester, AccountStrings.email, email);
      await _type(tester, AccountStrings.password, password);
      await _type(tester, AccountStrings.confirmPassword, password);
      await _tap(tester, find.byType(CheckboxListTile));
      await _tap(
        tester,
        find.widgetWithText(FilledButton, AccountStrings.createAccount),
      );
      expect(find.byType(NavigationBar), findsOneWidget, reason: 'signed in');
      expect(
        find.text('Good morning, Iris').evaluate().length +
            find.text('Good afternoon, Iris').evaluate().length +
            find.text('Good evening, Iris').evaluate().length,
        1,
      );
      expect(find.text(DashboardStrings.emptyTitle), findsOneWidget);

      // 2. Add an application.
      await _tabTo(tester, AppStrings.tabApplications);
      await _tap(
        tester,
        find.widgetWithText(FilledButton, ApplicationStrings.emptyAction),
      );
      await _type(tester, ApplicationStrings.fieldJobTitle, 'Flutter Engineer');
      await _type(tester, ApplicationStrings.fieldCompany, 'Acme Robotics');
      await _type(tester, ApplicationStrings.fieldLocation, 'Penang');
      await _tap(tester, find.widgetWithText(FilledButton, AppStrings.save));
      expect(find.text('Flutter Engineer'), findsWidgets);
      expect(find.text('Acme Robotics'), findsWidgets);

      // 3. Move it to Interview with a note.
      await _tap(
        tester,
        find.descendant(
          of: find.byType(StatusSelector),
          matching: find.text(ApplicationStatus.interview.label),
        ),
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(EditableText),
        ),
        'Recruiter called',
      );
      await _tap(
        tester,
        find.widgetWithText(FilledButton, ApplicationStrings.statusConfirm),
      );
      expect(find.text('Recruiter called'), findsOneWidget);

      // 4. Add an interview (default: tomorrow, 10:00).
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500));
      await _settle(tester);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(QuickActions),
          matching: find.text(ApplicationStrings.actionInterview),
        ),
      );
      await _type(tester, InterviewStrings.fieldTitle, 'Technical round');
      await _tap(tester, find.widgetWithText(FilledButton, AppStrings.save));
      await tester.scrollUntilVisible(
        find.text('Technical round'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Technical round'), findsOneWidget);

      // 5. Dashboard shows the upcoming interview and the new numbers.
      await _tap(tester, find.byType(BackButton));
      await _tabTo(tester, AppStrings.tabDashboard);
      await tester.scrollUntilVisible(
        find.text('Technical round'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Technical round'), findsOneWidget);

      // 6. Calendar has the interview marker and agenda on its day.
      await _tabTo(tester, AppStrings.tabCalendar);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      Finder day() => find.byWidgetPredicate(
        (w) =>
            w is DayCell &&
            w.day.day == tomorrow.day &&
            w.day.month == tomorrow.month,
      );
      if (day().evaluate().isEmpty) {
        // Tomorrow is on the next month's page.
        await _tap(tester, find.byIcon(Icons.chevron_right));
      }
      expect(
        find.byKey(const ValueKey('marker-interview')),
        findsWidgets,
        reason: 'interview dot',
      );
      // Not _tap: ensureVisible on a day cell also scrolls the calendar's
      // horizontal page view, and a cell past the middle (Thursday to
      // Sunday) snaps it to the next month.
      await tester.ensureVisible(find.byType(TableCalendar<DayMarker>));
      await _settle(tester);
      await tester.tap(day());
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.text('Technical round'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Technical round'),
        findsOneWidget,
        reason: 'agenda entry',
      );

      // 7. Alerts: the status change is listed and the badge counts it.
      await _tabTo(tester, AppStrings.tabNotifications);
      expect(find.text(AlertsStrings.title), findsWidgets);
      expect(find.text('Moved to Interview'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(Badge),
        ),
        findsWidgets,
      );

      // 8. Log out.
      await _tabTo(tester, AppStrings.tabSettings);
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, AccountStrings.logOut),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(
        tester,
        find.widgetWithText(OutlinedButton, AccountStrings.logOut),
      );
      await _tap(
        tester,
        find.widgetWithText(TextButton, AccountStrings.logOut),
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    },
  );
}
