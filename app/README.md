# JobTrail app

Flutter client for the JobTrail REST API (`../backend`). The server is the source of truth; the app keeps no local database.
Contract: `../docs/API.md` · UI: `../docs/DESIGN.md`.

## Run

```bash
cd app
flutter pub get

# 1. No server needed: in-memory fake backend with the DESIGN.md sample data
flutter run --dart-define=USE_FAKE=true
#    Demo account (prefilled on the sign-in screen):
#    demo@jobtrail.app / Password1!

# 2. Real backend (start it first: see ../backend/README.md)
./run-dev.ps1                                            # sets up `adb reverse`, then flutter run -> http://localhost:3000/api/v1
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1   # physical device / iOS simulator on LAN
```

| `--dart-define` | Default | Meaning |
|---|---|---|
| `API_BASE_URL` | `http://localhost:3000/api/v1` | REST API root (reached via `adb reverse tcp:3000 tcp:3000`; use `http://<PC-LAN-IP>:3000/api/v1` for Wi-Fi) |
| `USE_FAKE` | `false` | Use the in-memory repositories in `lib/data/fake/` |

Debug builds allow cleartext `http` (see `android/app/src/debug/AndroidManifest.xml`); release builds must use https.
Plus Jakarta Sans is fetched by `google_fonts` on first use and cached; offline first launches fall back to the system font.

## Checks

```bash
dart format . && flutter analyze && flutter test
```

## Folder structure

```
lib/
  main.dart                 entry point (ProviderScope)
  app/
    app.dart                MaterialApp.router, theme mode
    providers.dart          logger, config switch, Dio, ALL repository providers
    router.dart / routes.dart   go_router config + route path constants
    auth_redirect.dart      pure redirect rule (DESIGN §5), unit tested
    theme/app_theme.dart    kSeedColor, AppColors, AppTheme.light/dark, StatusStyle
  core/
    config/                 AppConfig (dart-defines)
    constants/              AppStrings (all UI text), Spacing, Radii, Sizes, Limits
    errors/failures.dart    Failure types: ApiFailure, NetworkFailure, UnauthorizedFailure...
    utils/                  ApiDate, DateHelpers, Validators, snackbar (+Undo), Haptics, failureMessage
    widgets/                shared kit; import 'core/widgets/widgets.dart'
  domain/
    enums/                  camelCase enums identical to API/DB
    models/                 immutable models with fromJson/toJson/copyWith
    repositories/           interfaces mirroring API.md
  data/
    api/                    Dio client, auth interceptor (refresh), TokenStorage, Api*Repository
    fake/                   FakeBackend (shared state) + Fake*Repository
  features/<feature>/
    application/            controllers (Riverpod notifiers)
    presentation/           screens and feature widgets
```

## How it fits together

- **Repositories** are chosen in `app/providers.dart`: fake when `USE_FAKE=true`, otherwise the Dio-backed `Api*Repository`. Screens only talk to the interfaces in `domain/repositories`.
- **Errors**: repositories throw a `Failure`. Show it with `failureMessage(error)` or `ErrorState(error: e, onRetry: ...)`.
- **Auth**: `authControllerProvider` (`AsyncNotifier<AuthState>`) restores the session on launch and exposes `signIn`, `signUp`, `signOut`. The router redirects on its changes. The Dio `AuthInterceptor` attaches the access token, refreshes once on `TOKEN_EXPIRED` (single-flight), retries, and signs out if the refresh token is rejected. Network errors during refresh keep the session.
- **Tokens** live in `flutter_secure_storage` (`SecureTokenStorage`), never in logs (the logging interceptor prints method, path and status only).

## Adding a feature

1. Implement the real repository: replace the stub in `data/api/api_stubs.dart` with `data/api/api_<name>_repository.dart` (use `guardApi(() => dio.get(...))` so errors become `Failure`s), then point its provider in `app/providers.dart` at the new class. Extend the matching `Fake*Repository` if the contract grows.
2. Add controllers in `features/<feature>/application/` as `AsyncNotifier`/`FutureProvider`s that read the repository provider.
3. Build screens in `features/<feature>/presentation/` using `core/widgets`, `Theme.of(context)` and the `Spacing`/`Radii` constants. Put every user-facing string in `AppStrings`.
4. Replace the placeholder builder for the route in `app/router.dart` (paths are in `routes.dart`).
5. Test with `testApp(...)` and `fakeOverrides()` from `test/helpers/test_app.dart` (fake backend, no network fonts).

## Tests

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test   # unit + widget + headless happy path
flutter test integration_test/happy_path_test.dart -d <device-id>         # same flow on an emulator/device, fake backend
# against a real server (backend running, emulator URL shown):
flutter test integration_test/happy_path_test.dart -d <device-id> \
  --dart-define=REAL_BACKEND=true --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

`test/app/` also holds the cross-cutting checks: `overflow_sweep_test` (every screen at 320×568, text ×1.5 and ×2.0, light and dark),
`accessibility_test` (labelled tap targets, 48dp targets, text contrast), `edge_cases_test` (600 applications, very long text, offline).

## Release

**Identity.** App name *JobTrail*, Android `minSdk 26`, iOS deployment target 13.0. Version comes from `pubspec.yaml` (`version: 1.0.0+1` → name + build number).
Launcher icon and splash (white briefcase on `#3F51B5`) are generated from `assets/branding/`:

```bash
dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

**Production API.** Release builds must talk to https. Bake the URL in at build time:

```bash
--dart-define=API_BASE_URL=https://api.example.com/api/v1
```

**Android signing.** Create a keystore once and keep it (and its passwords) safe; losing it means you can no longer update the app:

```bash
keytool -genkey -v -keystore ~/jobtrail-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (git-ignored):

```
storeFile=/absolute/path/to/jobtrail-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without that file a release build falls back to the debug key (fine for `flutter run --release`, **not** for the store).

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1      # sideload / testers
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com/api/v1 # Play Store (AAB)
```

**iOS.** Needs macOS + Xcode: open `ios/Runner.xcworkspace`, set the bundle id and team under *Signing & Capabilities*
(no *Push Notifications* capability is needed: reminders are local notifications). Then

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

and upload the `.ipa` with Transporter / `xcrun altool`.

**Pre-release checklist**: all test suites green · backend `mvn -pl e2e test -De2e=true -Dbase.url=<production URL>` · run the happy path on a real device with notifications
allowed · set an interview 2 minutes ahead with a 1-minute custom reminder and confirm the notification fires and opens the interview ·
reboot the phone and check reminders survive · airplane-mode check (friendly errors, Retry works) · light/dark + large-text spot check.
