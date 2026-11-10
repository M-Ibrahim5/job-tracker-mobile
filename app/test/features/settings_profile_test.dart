import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/app.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/core/constants/account_strings.dart';
import 'package:jobtrail/core/constants/app_constants.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/services/avatar_picker.dart';
import 'package:jobtrail/core/services/file_sharer.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/settings.dart';
import 'package:jobtrail/domain/models/user.dart';
import 'package:jobtrail/features/auth/application/auth_controller.dart';
import 'package:jobtrail/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

class _RecordingProfileRepository extends FakeProfileRepository {
  _RecordingProfileRepository(super.b);

  final updates = <Map<String, String?>>[];
  final savedSettings = <Settings>[];
  final uploads = <String>[];
  bool failSettings = false;

  @override
  Future<User> updateMe({
    String? fullName,
    String? phone,
    String? currentRole,
    String? lookingFor,
    String? location,
  }) {
    updates.add({
      'fullName': fullName,
      'phone': phone,
      'currentRole': currentRole,
      'lookingFor': lookingFor,
      'location': location,
    });
    return super.updateMe(
      fullName: fullName,
      phone: phone,
      currentRole: currentRole,
      lookingFor: lookingFor,
      location: location,
    );
  }

  @override
  Future<Settings> updateSettings(Settings settings) {
    if (failSettings) return Future.error(const NetworkFailure());
    savedSettings.add(settings);
    return super.updateSettings(settings);
  }

  @override
  Future<User> uploadAvatar(String filePath) {
    uploads.add(filePath);
    return super.uploadAvatar(filePath);
  }
}

class _RecordingSharer implements FileSharer {
  final shared = <String>[];
  int byteCount = 0;

  @override
  Future<void> shareBytes(List<int> bytes, String fileName) async {
    shared.add(fileName);
    byteCount = bytes.length;
  }

  @override
  Future<void> deleteExports() async {}
}

class _FixedPicker implements AvatarPicker {
  @override
  Future<String?> pick() async => '/tmp/photo.jpg';
}

class _Harness {
  _Harness(this.backend, this.profile, this.sharer, this.prefs);

  final FakeBackend backend;
  final _RecordingProfileRepository profile;
  final _RecordingSharer sharer;
  final SharedPreferences prefs;
  late ProviderContainer container;
}

Future<_Harness> _pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final backend = FakeBackend(latency: Duration.zero);
  backend.currentUser = backend.usersByEmail[kFakeEmail];
  final h = _Harness(
    backend,
    _RecordingProfileRepository(backend),
    _RecordingSharer(),
    await SharedPreferences.getInstance(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeOverrides(backend),
        profileRepositoryProvider.overrideWithValue(h.profile),
        fileSharerProvider.overrideWithValue(h.sharer),
        avatarPickerProvider.overrideWithValue(_FixedPicker()),
        sharedPreferencesProvider.overrideWithValue(h.prefs),
        appVersionProvider.overrideWith((ref) async => '1.2.3'),
      ],
      child: const JobTrailApp(useGoogleFonts: false),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(AppStrings.tabSettings),
    ),
  );
  await tester.pumpAndSettle();
  h.container = ProviderScope.containerOf(
    tester.element(find.byType(NavigationBar)),
  );
  return h;
}

Finder _switchTile(String title) => find.widgetWithText(SwitchListTile, title);

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('Settings screen', () {
    testWidgets('renders the profile card, sections and version', (
      tester,
    ) async {
      await _pumpSettings(tester);

      expect(find.text('Muhammad Ibrahim'), findsOneWidget);
      expect(find.text(kFakeEmail), findsOneWidget);
      expect(
        find.text('Software Engineer · Kuala Lumpur, Malaysia'),
        findsOneWidget,
      );
      expect(find.text('MI'), findsOneWidget);
      expect(find.text(AccountStrings.personalDetails), findsOneWidget);
      expect(find.text(AccountStrings.changePassword), findsOneWidget);
      expect(find.text(AccountStrings.version('1.2.3')), findsOneWidget);
      expect(find.text(AccountStrings.signedInAs(kFakeEmail)), findsOneWidget);
      expect(find.text(AccountStrings.exportData), findsOneWidget);
      // Import was removed from the design.
      expect(find.textContaining('Import'), findsNothing);
    });

    testWidgets('toggling a switch updates the UI and calls the repository', (
      tester,
    ) async {
      final h = await _pumpSettings(tester);
      expect(
        tester
            .widget<SwitchListTile>(
              _switchTile(AccountStrings.followUpReminders),
            )
            .value,
        isTrue,
      );

      await tester.tap(_switchTile(AccountStrings.followUpReminders));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(
              _switchTile(AccountStrings.followUpReminders),
            )
            .value,
        isFalse,
      );
      expect(h.profile.savedSettings.single.followUpRemindersEnabled, isFalse);
      expect(h.backend.settings.followUpRemindersEnabled, isFalse);
    });

    testWidgets('a failed save rolls the switch back and tells the user', (
      tester,
    ) async {
      final h = await _pumpSettings(tester);
      h.profile.failSettings = true;

      await tester.tap(_switchTile(AccountStrings.statusChanges));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(_switchTile(AccountStrings.statusChanges))
            .value,
        isTrue,
      );
      expect(find.text(AccountStrings.settingsSaveFailed), findsOneWidget);
    });

    testWidgets('default reminder and follow-up chips save their choices', (
      tester,
    ) async {
      final h = await _pumpSettings(tester);

      await _tapVisible(tester, find.text('15 min'));
      expect(h.backend.settings.defaultReminderOffsets, const [
        Duration(days: 1),
        Duration(hours: 1),
        Duration(minutes: 15),
      ]);

      await _tapVisible(tester, find.text('1 hour'));
      expect(h.backend.settings.defaultReminderOffsets, const [
        Duration(days: 1),
        Duration(minutes: 15),
      ]);

      await _tapVisible(tester, find.text('14 days'));
      expect(h.backend.settings.defaultFollowUpDays, 14);

      await _tapVisible(tester, find.text(AccountStrings.followUpOff));
      expect(h.backend.settings.defaultFollowUpDays, isNull);
    });

    testWidgets('theme applies immediately, persists locally and syncs', (
      tester,
    ) async {
      final h = await _pumpSettings(tester);

      await _tapVisible(tester, find.text('Dark'));

      expect(h.container.read(themeModeProvider), ThemeMode.dark);
      expect(h.prefs.getString(kThemePrefKey), 'dark');
      expect(h.backend.settings.theme, ThemeSetting.dark);
      expect(
        Theme.of(tester.element(find.byType(NavigationBar))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('logout asks for confirmation and can be cancelled', (
      tester,
    ) async {
      final h = await _pumpSettings(tester);
      final logOut = find.widgetWithText(OutlinedButton, AccountStrings.logOut);

      await _tapVisible(tester, logOut);
      expect(find.text(AccountStrings.logOutTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(
        h.container.read(authControllerProvider).value,
        isA<AuthAuthenticated>(),
      );

      await _tapVisible(tester, logOut);
      await tester.tap(find.widgetWithText(TextButton, AccountStrings.logOut));
      await tester.pumpAndSettle();
      expect(
        h.container.read(authControllerProvider).value,
        isA<AuthUnauthenticated>(),
      );
      expect(h.backend.currentUser, isNull);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets(
      'change password validates, reports a wrong password, then succeeds',
      (tester) async {
        final h = await _pumpSettings(tester);
        await _tapVisible(tester, find.text(AccountStrings.changePassword));

        Finder field(int i) => find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(TextFormField),
            )
            .at(i);
        final submit = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(
            FilledButton,
            AccountStrings.changePassword,
          ),
        );

        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.errRequired), findsOneWidget);

        await tester.enterText(field(0), 'WrongPass1!');
        await tester.enterText(field(1), 'Newpass1!');
        await tester.enterText(field(2), 'Newpass1!');
        await tester.pump();
        expect(find.text('Strong'), findsOneWidget);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(
          find.text(AccountStrings.errCurrentPasswordWrong),
          findsOneWidget,
        );

        await tester.enterText(field(0), kFakePassword);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text(AccountStrings.passwordChanged), findsOneWidget);
        expect(h.backend.passwords[kFakeEmail], 'Newpass1!');
      },
    );

    testWidgets('export shares a JSON file named by date', (tester) async {
      final h = await _pumpSettings(tester);
      await _tapVisible(tester, find.text(AccountStrings.exportData));
      await tester.tap(find.text(AccountStrings.exportJson));
      await tester.pumpAndSettle();

      expect(h.sharer.shared.single, startsWith('jobtrail-export-'));
      expect(h.sharer.shared.single, endsWith('.json'));
      expect(h.sharer.byteCount, greaterThan(100));
    });

    testWidgets(
      'delete all data needs two confirmations including typing DELETE',
      (tester) async {
        final h = await _pumpSettings(tester);
        await _tapVisible(tester, find.text(AccountStrings.deleteAllData));

        // Dialog 1.
        expect(find.text(AccountStrings.deleteAllTitle), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, AppStrings.delete));
        await tester.pumpAndSettle();

        // Dialog 2: the confirm button is disabled until DELETE is typed.
        final confirm = find.widgetWithText(
          TextButton,
          AccountStrings.deleteAllData,
        );
        expect(tester.widget<TextButton>(confirm).onPressed, isNull);
        await tester.enterText(find.byType(TextFormField).last, 'delete');
        await tester.pump();
        expect(tester.widget<TextButton>(confirm).onPressed, isNull);
        await tester.enterText(find.byType(TextFormField).last, 'DELETE');
        await tester.pump();
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(h.backend.applications, isEmpty);
        expect(h.container.read(dataRevisionProvider), 1);
        expect(find.text(AccountStrings.deleteAllDone), findsOneWidget);
      },
    );

    testWidgets('declining the first delete dialog deletes nothing', (
      tester,
    ) async {
      final h = await _pumpSettings(tester);
      await _tapVisible(tester, find.text(AccountStrings.deleteAllData));
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(h.backend.applications, isNotEmpty);
    });
  });

  group('SettingsController', () {
    test('rolls back an optimistic change when saving fails', () async {
      final backend = FakeBackend(latency: Duration.zero);
      backend.currentUser = backend.usersByEmail[kFakeEmail];
      final repo = _RecordingProfileRepository(backend);
      final container = ProviderContainer(
        overrides: [
          ...fakeOverrides(backend),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final controller = container.read(settingsProvider.notifier);
      expect(
        (await container.read(settingsProvider.future)).statusAlertsEnabled,
        isTrue,
      );

      repo.failSettings = true;
      final seen = <bool>[];
      container.listen(
        settingsProvider,
        (_, next) => seen.add(next.value!.statusAlertsEnabled),
      );
      await expectLater(
        controller.change((s) => s.copyWith(statusAlertsEnabled: false)),
        throwsA(isA<NetworkFailure>()),
      );

      expect(seen, [false, true]);
      expect(
        container.read(settingsProvider).value!.statusAlertsEnabled,
        isTrue,
      );
    });

    test('a theme change that fails also restores the local theme', () async {
      SharedPreferences.setMockInitialValues({kThemePrefKey: 'light'});
      final prefs = await SharedPreferences.getInstance();
      final backend = FakeBackend(latency: Duration.zero);
      backend.currentUser = backend.usersByEmail[kFakeEmail];
      backend.settings = const Settings(theme: ThemeSetting.light);
      final repo = _RecordingProfileRepository(backend);
      final container = ProviderContainer(
        overrides: [
          ...fakeOverrides(backend),
          profileRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await container.read(settingsProvider.future);
      expect(container.read(themeModeProvider), ThemeMode.light);

      repo.failSettings = true;
      await expectLater(
        container.read(settingsProvider.notifier).setTheme(ThemeSetting.dark),
        throwsA(isA<NetworkFailure>()),
      );

      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(prefs.getString(kThemePrefKey), 'light');
    });

    test('the stored theme is used before settings load', () async {
      SharedPreferences.setMockInitialValues({kThemePrefKey: 'dark'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('Edit profile', () {
    Future<_Harness> open(WidgetTester tester) async {
      final h = await _pumpSettings(tester);
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, AccountStrings.editProfile),
      );
      return h;
    }

    Finder field(String label) => find
        .ancestor(
          of: find.text(label, findRichText: true),
          matching: find.byType(Column),
        )
        .first;

    testWidgets('is pre-filled and shows the read-only verified email', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Muhammad Ibrahim'), findsWidgets);
      expect(find.text(AccountStrings.verified), findsOneWidget);
      expect(find.text(kFakeEmail), findsWidgets);
      expect(find.text(AccountStrings.emailReadOnlyHint), findsOneWidget);
      expect(field(AccountStrings.phone), findsOneWidget);
    });

    testWidgets('leaving with unsaved edits asks to discard', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Changed Name');
      await tester.pump();

      await tester.tap(find.byTooltip(AccountStrings.semBack));
      await tester.pumpAndSettle();
      expect(find.text(AccountStrings.discardTitle), findsOneWidget);

      // Keep editing: still on the form.
      await tester.tap(find.text(AccountStrings.keepEditing));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text(AccountStrings.discardTitle), findsNothing);

      // Discard: back on settings, name unchanged.
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AccountStrings.discard));
      await tester.pumpAndSettle();
      expect(
        find.text(AccountStrings.sectionAccount.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('Muhammad Ibrahim'), findsOneWidget);
    });

    testWidgets('leaving without edits does not ask', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip(AccountStrings.semBack));
      await tester.pumpAndSettle();
      expect(find.text(AccountStrings.discardTitle), findsNothing);
      expect(
        find.text(AccountStrings.sectionAccount.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets(
      'saving sends only the changed fields and updates the profile',
      (tester) async {
        final h = await open(tester);
        await tester.enterText(find.byType(TextFormField).first, 'Ibrahim M');
        await tester.enterText(find.byType(TextFormField).at(2), '555-0100');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
        await tester.pumpAndSettle();

        expect(h.profile.updates.single, {
          'fullName': 'Ibrahim M',
          'phone': '555-0100',
          'currentRole': null,
          'lookingFor': null,
          'location': null,
        });
        expect(h.backend.currentUser!.fullName, 'Ibrahim M');
        expect(find.text('Ibrahim M'), findsOneWidget);
      },
    );

    testWidgets('a blank name is rejected before any request', (tester) async {
      final h = await open(tester);
      await tester.enterText(find.byType(TextFormField).first, '   ');
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errRequired), findsOneWidget);
      expect(h.profile.updates, isEmpty);
    });

    testWidgets('a picked photo is not uploaded until Save is pressed', (
      tester,
    ) async {
      final h = await open(tester);
      await tester.tap(find.byTooltip(AccountStrings.semChangePhoto));
      await tester.pumpAndSettle();
      expect(h.profile.uploads, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();
      expect(h.profile.uploads, ['/tmp/photo.jpg']);
      expect(find.text(AccountStrings.profileSaved), findsOneWidget);
    });

    testWidgets('cancelling after picking a photo discards it', (tester) async {
      final h = await open(tester);
      await tester.tap(find.byTooltip(AccountStrings.semChangePhoto));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text(AccountStrings.discardTitle), findsOneWidget);
      await tester.tap(find.text(AccountStrings.discard));
      await tester.pumpAndSettle();

      expect(h.profile.uploads, isEmpty);
      expect(h.profile.updates, isEmpty);
    });

    testWidgets('deleting the account needs the password and signs out', (
      tester,
    ) async {
      final h = await open(tester);
      await _tapVisible(tester, find.text(AccountStrings.deleteAccount));

      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, AccountStrings.deleteAccount),
      );
      expect(tester.widget<TextButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextFormField).last, kFakePassword);
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(h.backend.usersByEmail, isEmpty);
      expect(
        h.container.read(authControllerProvider).value,
        isA<AuthUnauthenticated>(),
      );
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
