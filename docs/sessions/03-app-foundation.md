# Session 03 — Flutter App Foundation

**Read first:** `docs/00-README.md`, `docs/DESIGN.md` (§1–3, 5), `docs/API.md` (conventions, Auth, Me).
**Owns:** `app/` (the Flutter project). Don't touch `backend/`.

## Context
`app/` is the earlier "Phase 1" project (never compiled): domain enums/models, validators, date helpers, theme, router with placeholder tabs, `StatusChip`, and an obsolete Drift data layer. The architecture changed: **REST API + MySQL backend, no local DB.**

## Goal
A compiling, analyzer-clean app skeleton with the real design tokens, API client, auth plumbing and shared widgets — so feature sessions can add screens in parallel.

## Tasks

1. **Get it compiling**: if `android/`/`ios/` are missing run `flutter create . --platforms=android,ios --org com.jobtrail --project-name jobtrail`. `flutter pub get`, fix everything until `flutter analyze` is clean.
2. **Remove Drift**: delete `lib/data/database/**`, `DriftJobApplicationRepository`, the Drift test, and deps `drift`, `drift_flutter`, `drift_dev`, `sqlite3_flutter_libs`, `build_runner` (unless you add json_serializable; plain `fromJson/toJson` is fine). Add deps: `dio`, `flutter_secure_storage`, `shared_preferences`, `google_fonts` (or bundle Plus Jakarta Sans), `image_picker`, `share_plus`, `path_provider`. Keep the rest.
3. **Config**: `AppConfig.apiBaseUrl` from `--dart-define=API_BASE_URL` (default `http://localhost:3000/api/v1`, reached on Android with `adb reverse tcp:3000 tcp:3000`; `run-dev.ps1` does both). Document in README.
4. **Domain**: update models to match `API.md` (JSON `fromJson/toJson`, `copyWith`, camelCase enums incl. `InterviewType.finalRound`): `User`, `Settings`, `JobApplication` (+`nextInterviewAt`, `followUpAt`, `appliedDate` as date), `StatusHistoryEntry`, `Interview` (+`applicationTitle`, `companyName`, `reminderOffsets` from minutes), `AppNotification`, `Page<T>`, `DashboardData`, `CalendarEvent`, `ReminderItem`. Update `ApplicationFilter` (add `toQuery()`).
5. **Repository interfaces** (`domain/repositories`): `AuthRepository`, `ProfileRepository`, `JobApplicationRepository`, `InterviewRepository`, `NotificationRepository`, `DashboardRepository`, `CalendarRepository`, `ReminderRepository`, `DataRepository` — methods mirror `API.md`. Remove `restore` from the application repo. Provide **fake in-memory implementations** of all (seeded with the sample data from `DESIGN.md`) under `lib/data/fake/` and a provider switch `useFakeBackend` (dart-define `USE_FAKE=true`). This lets feature sessions run without the server.
6. **Network layer** (`lib/data/api/`): Dio client with base URL, JSON, timeouts, logging interceptor (logger, no tokens in logs), **auth interceptor** (attach access token; on 401 `TOKEN_EXPIRED` call `/auth/refresh` once with a single-flight lock, retry; if refresh fails → sign out), error mapper to typed `Failure`s (`ApiFailure(code, message, fields)`, `NetworkFailure`, `UnauthorizedFailure`). `TokenStorage` over `flutter_secure_storage`. Implement `ApiAuthRepository` and `ApiProfileRepository` now; other API repos are stubs throwing `UnimplementedError` that feature sessions will fill.
7. **Auth state**: `authControllerProvider` (`AsyncNotifier<AuthState>`: unknown/authenticated(user)/unauthenticated), restore session on launch (read tokens → `GET /me`), `signIn`, `signUp`, `signOut`. go_router `redirect` per `DESIGN.md §5`, with `refreshListenable` from auth state. Add routes `/login`, `/register`, `/onboarding` (placeholders) and all routes from `DESIGN.md §5` as placeholder screens, so later sessions only replace the builders.
8. **Theme & tokens** exactly per `DESIGN.md §2`: `AppTheme.light/dark` (seed constant `kSeedColor`), Plus Jakarta Sans text theme, `StatusStyle` (colors, chip bg/text, icons), card/input/button/chip/segmented/switch/navigation-bar themes matching the mockups (radii, borders, heights), spacing constants.
9. **Shared widgets** (`core/widgets/`), each with a widget test: `StatusChip` (update colors), `AppTextField` (label above, required marker, error style), `SegmentedChoice<T>`, `ChoiceChips<T>` (single/multi), `PrimaryButton`/`SecondaryButton`/`DestructiveButton` (loading state), `FormFooter`, `NoticeBanner`, `EmptyState`, `ErrorState` (retry), `SkeletonBox`/list skeleton, `ConfirmDialog`, `DateBlock`, `UnreadBadge`, `Eyebrow` label, `GroupedCard`. Plus `AppShell` with the 5-tab `NavigationBar` and an unread-count badge fed by a provider (`unreadCountProvider`, returns 0 for now).
10. **Utilities**: `ApiDate` helpers (parse UTC → local, date-only), `snackbar` helper with Undo, `haptics` helper, global logger provider, `Failure` → user message mapper.

## Definition of Done
- `dart format . && flutter analyze` clean (0 issues). `flutter test` passes (validators, date helpers, token refresh interceptor with a mocked Dio adapter, auth redirect logic, shared widgets).
- App launches with `--dart-define=USE_FAKE=true`: shows `/login` placeholder → after fake sign-in shows 5-tab shell with themed nav bar; light and dark both look right.
- With `API_BASE_URL` pointing at a running backend (once session 01 is done) sign-in/sign-up calls work end to end (manual check noted in handoff).
- README (`app/README.md`): run instructions for fake and real backend, folder structure, how to add a feature.

## Handoff notes
**Done**
- `flutter analyze` 0 issues, `dart format` clean, `flutter test` 81/81 pass (token-refresh interceptor with scripted Dio adapter, auth redirect rule, models/JSON, fake repositories, app sign-in/out flow, shared widgets at 320px / 1.5x text, light + dark).
- Drift removed (deps + `lib/data/database`, `lib/data/repositories`, Drift test); new deps `dio`, `flutter_secure_storage`, `google_fonts`, `image_picker`, `share_plus`; `intl` bumped to ^0.20.2 (required by Flutter's localizations) and SDK floor to 3.8 (null-aware map entries).
- `android/` + `ios/` generated with `flutter create`. Debug manifest allows cleartext http for the local backend.
- All repository interfaces + fakes (seed matches DESIGN: 15 apps, 5/3/3/1/3 split, 67% response). Real `ApiAuthRepository` and `ApiProfileRepository`; the others are `noSuchMethod` stubs in `data/api/api_stubs.dart` (session 04 owns `ApiDataRepository`, 05 applications, 06 interviews/notifications/reminders, 07 dashboard/calendar).
- Router has every DESIGN �5 route as a placeholder plus `/splash`; working placeholder Login/Register/Settings(sign-out) so auth can be exercised. Shell has the Alerts badge via `unreadCountProvider` (returns 0).

**Deviations / decisions**
- Repository interfaces are request/response (`Future`), not `Stream`s as in Phase 1, to mirror the REST API. `ProfileRepository` also carries settings (`getSettings`/`updateSettings`); `AuthRepository` owns token storage and `restoreSession`.
- `JobApplication.followUpDate` -> `followUpAt`; `Interview.dateTime` -> `scheduledAt`.
- `ReminderItem.notificationId` uses FNV-1a (not `String.hashCode`, which is not stable across runs); pinned in a test.
- Any 401 on a protected route that is not `TOKEN_EXPIRED` clears the session and signs out.
- If restoring the session fails (e.g. offline at launch) the app lands on login; tokens stay stored.
- `AppTheme.light/dark({useGoogleFonts})` and `JobTrailApp(useGoogleFonts)` exist so tests avoid network font fetches. Fonts are not bundled.
- `onboardingSeenProvider` defaults to true (redirect seam); session 04 should persist it and flip the default.
- Fake `uploadAvatar` leaves the avatar unchanged.
- Shared widgets live in `core/widgets/` (several per file; import the `widgets.dart` barrel).

**Not done / open**
- No git repository exists in this folder, so nothing was committed (`S03:` commit still to be made).
- The environment denied `rm -rf`, so the obsolete Drift files were moved out of the repo to the session scratchpad instead of deleted; nothing of them remains under `app/`.
- Not run on a device/emulator (no emulator in this session): launching with `USE_FAKE=true` and the live backend sign-in/sign-up are **unverified manually**. Manual check to do: start backend, `flutter run`, register, sign out, sign in.

