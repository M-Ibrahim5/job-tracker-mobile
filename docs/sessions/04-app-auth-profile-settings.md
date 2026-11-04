# Session 04 — App: Auth, Settings, Profile

**Depends on:** session 03. (Run live against the backend once session 01 is done; use `USE_FAKE=true` before that.)
**Read first:** `docs/00-README.md`, `docs/DESIGN.md` §4.1, §4.2, §4.10, §4.11 and §2–3, `docs/API.md` (Auth, Me, Settings, Data).
**Owns:** `app/lib/features/{auth,settings,profile}/`, plus theme-mode persistence wiring. Don't edit other features.

## Goal
Pixel-faithful Login, Register, Settings and Edit Profile screens wired to the repositories, including logout.

## Tasks

1. **Login** (`/login`) per DESIGN §4.1 — email + password, show/hide, forgot-password link (opens a simple dialog that calls `/auth/forgot-password` and shows "If that email exists, we sent a link"), inline error banner for `INVALID_CREDENTIALS`, loading state on the button, validation (email format, password required). **Do not build** social buttons or "continue without account".
2. **Register** (`/register`) per DESIGN §4.2 — name, email, password with 4-level strength meter (pure function `passwordStrength(String)` + unit tests: length, digit, symbol, mixed case), confirm password match, terms checkbox gating the button; map `EMAIL_TAKEN` and server `fields` errors onto the inputs.
3. **Controllers** (`features/auth/application`): `LoginController`, `RegisterController` (`AsyncNotifier`s) delegating to `authControllerProvider`; no logic in widgets. After success router redirect handles navigation (and `/onboarding` on first launch if the onboarding flag is unset).
4. **Settings** (`/settings`) per DESIGN §4.10:
   - Profile card (initials avatar or `Image.network` of `avatarUrl`), "Edit profile".
   - Account: Personal details (→ `/settings/profile`), Change password (bottom sheet/dialog: current, new with strength meter, confirm → `POST /auth/change-password`; success snackbar).
   - Appearance: theme segmented; persist in `shared_preferences` immediately (so it applies before network) AND `PATCH /me/settings`; `themeModeProvider` reads local first.
   - Notifications: 3 switches + default reminder offsets (multi `ChoiceChips`: 1 day/1 hour/15 min) + default follow-up (Off/3/5/7/14). Optimistic update with rollback on failure. Provide `settingsProvider` (`AsyncNotifier<Settings>`) — other sessions read it (offsets and follow-up defaults).
   - Data: Export data → bottom sheet JSON/CSV → download via Dio to temp file → `share_plus`. Delete all data → dialog 1 ("Delete everything?") → dialog 2 (type `DELETE`) → `DELETE /data` → snackbar and invalidate all data providers. **No import.**
   - About: version from `package_info_plus`.
   - Log out: confirm dialog → `authController.signOut()` (revokes refresh token, clears secure storage, calls `ReminderScheduler.cancelAll()` — if that service doesn't exist yet, define an interface `ReminderCanceller` in `core/services` with a no-op default that session 06 overrides).
5. **Edit profile** (`/settings/profile`) per DESIGN §4.11: pre-filled fields, read-only verified email, avatar via `image_picker` (compress to ≤ 1024px, jpeg) → `POST /me/avatar`, Save → `PATCH /me` (only changed fields), unsaved-changes confirm on back, Delete account (password prompt → `DELETE /me` → sign out).
6. Implement the remaining pieces of `ApiProfileRepository` / settings endpoints / `ApiDataRepository` (export, delete-all) if session 03 left them as stubs, plus matching fakes.

## Definition of Done
- Screens match mockups visually (compare side by side at 390×844; no overflow at 1.5× text scale and 320px width; light + dark OK).
- Widget tests: login validation + error banner; register validation, strength meter, password mismatch; settings renders profile, switches toggle and call repo; logout confirm flow; edit-profile unsaved-changes dialog. Unit tests: `passwordStrength`, `SettingsController` optimistic rollback.
- Manual script (in handoff notes): register → logout → login → change theme → edit name → export JSON → delete account.
- `dart format . && flutter analyze && flutter test` clean.

## Handoff notes
_(append when done)_

**Done**
- Login (inline `INVALID_CREDENTIALS` banner, network error as snackbar, forgot-password dialog), Register (4-segment strength meter, confirm match, terms gating, `EMAIL_TAKEN`/server `fields` mapped onto inputs), Settings (profile card, account, appearance, notifications, data, about, log out), Change password sheet, Edit profile (unsaved-changes confirm, avatar via `AvatarPicker`, only changed fields sent, delete account with password).
- Controllers: `LoginController`, `RegisterController`, `ChangePasswordController`, `ProfileController` (AutoDispose `AsyncNotifier<void>`), `SettingsController` (`settingsProvider`, optimistic with rollback; other sessions read `defaultReminderOffsets` / `defaultFollowUpDays` / enabled flags from it), `DataActions` (export, delete-all).
- Theme: `themeModeProvider` starts from `shared_preferences` (`kThemePrefKey`, provided via `sharedPreferencesProvider` in `main`), the settings load syncs it from the server, changing it applies + persists locally before `PATCH /me/settings`, and a failed save restores both.
- Logout calls `reminderCancellerProvider.cancelAll()` (`ReminderCanceller` in `core/services`, no-op default; **session 06 should override this provider**).
- Real `ApiDataRepository` (`data/api/api_data_repository.dart`); `AuthController.signOut` also cancels reminders.
- New: `passwordStrength()` (`core/utils`), `PasswordStrengthMeter` widget, `AccountStrings` (`core/constants/account_strings.dart`), `FileSharer` and `AvatarPicker` services, `currentUserProvider`, `appVersionProvider` (`package_info_plus`).
- Checks: `dart format` clean, `flutter analyze` clean for my files, `flutter test` 121/121 pass (strength + validators, login/register screens, settings switches/rollback/theme/logout/change password/export/delete-all, edit-profile unsaved dialog + changed-fields-only save + avatar + delete account).

**For other sessions**
- After "Delete all data" `dataRevisionProvider` is incremented; **data providers (applications, interviews, notifications, dashboard, calendar) must `ref.watch(dataRevisionProvider)`** so they reload.
- Server field errors are shown by feeding them to the field validators (a local `_server` map cleared on submit) rather than `errorText`, so a stale server error never blocks resubmitting.
- Fake mode pre-fills the demo credentials on the login screen.

**Not done / open**
- Onboarding flag persistence and the onboarding screens are not part of this brief; `onboardingSeenProvider` still defaults to true, so the redirect never sends users to `/onboarding`.
- Not run on a device/emulator and not compared visually against the mockups (no 390x844 screenshot pass); overflow was only checked in widget tests at 320px / 1.5x text for the shared kit, not for each new screen.
- Avatar `Image.network` shows initials if the URL fails; the fake backend never changes `avatarUrl`.
- No commit (no git repository in this folder).

**Manual script**: `flutter run --dart-define=USE_FAKE=true` (or against the backend) -> Create account -> Settings > Log out -> Sign in -> Appearance: Dark -> Edit profile: change name, Save -> Data > Export data > JSON (share sheet) -> Edit profile > Delete account (enter password) -> lands on login.
