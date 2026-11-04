# JobTrail — Bug fixes & improvements log

Round 1 · 2026-11-01. Each entry: **symptom → cause → fix → files → how it is tested**.
The API contract changed in two places (device tokens §8, CSV export §9); `API.md` and `DESIGN.md` were updated in the same change.

| # | Item | Type |
|---|---|---|
| 1 | "Cannot update, attach JPEG/PNG only" on photo upload | Bug |
| 2 | Cancelled profile edit still saved the new photo | Bug |
| 3 | Follow-up color same as Status change (orange) in the calendar | Bug |
| 4 | Bottom nav had text labels | UI |
| 5 | Pie chart legend counts not aligned | UI |
| 6 | Interview detail rows scattered | UI |
| 7 | Congratulation / support pop-up on Offer / Rejected | Feature |
| 8 | Fingerprint login | Feature |
| 9 | CSV `createdAt` / `updatedAt` format | Bug |

---

## 1. Profile photo upload rejected ("JPEG or PNG image is required")

**Symptom.** Choosing a photo in *Edit profile* failed with the server message *A JPEG or PNG image is required*, even for photos that look like normal JPEG/PNG images.

**Cause.** The server (correctly) checks both the declared `Content-Type` **and** the file's magic bytes. The app decided the type from the **file name's extension** only: `.png` → PNG, *anything else* → JPEG. Gallery pickers regularly return files whose name does not match the content (a WebP/HEIC saved as `.jpg`, a PNG with no extension, …), so the app declared `image/jpeg` for bytes that were not JPEG and the server refused them. Photos over the 2 MB limit would fail too.

**Fix.** The app now looks at the file's *content* before uploading (`prepareAvatarImage`):
1. Read the bytes and check the signature (`89 50 4E 47` = PNG, `FF D8` = JPEG).
2. If it is a real JPEG/PNG ≤ 2 MB, send it as-is with the matching name/MIME type.
3. Otherwise (WebP/HEIC/GIF…, or too large) decode it and re-encode as PNG, shrinking (1024 → 768 → 512 → 256 px) until it fits in 2 MB.
4. If it is not an image at all, show *"Choose a JPEG or PNG image under 2 MB."* instead of a server error.

The server is unchanged — it stays strict, which is what keeps uploads safe.

**Files.** `app/lib/core/services/avatar_image.dart` (new), `app/lib/data/api/api_profile_repository.dart`, `app/lib/core/constants/account_strings.dart`.
**Tests.** `app/test/core/avatar_image_test.dart` — type is taken from content not name; non-image rejected.

---

## 2. Cancelling *Edit profile* still kept the new photo

**Symptom.** Pick a new photo, press Cancel/back → the photo was already saved.

**Cause.** `_changePhoto` called the upload endpoint immediately after picking. The photo was therefore saved on the server before the user pressed **Save**, bypassing the form's save/cancel logic.

**Fix.** The photo now follows the same rule as every other field:
- Picking only stores the local file path (`_pendingAvatar`) and **previews** it in the avatar circle (`UserAvatar.previewPath`). Nothing is sent.
- A pending photo counts as an unsaved change, so Cancel/back shows the *Discard changes?* dialog. Discarding drops the pick; the saved photo is untouched.
- **Save** uploads the photo first, then sends the changed text fields, both in one `ProfileController.save(...)` call. The *Profile saved* message replaces the old *Photo updated* one. If no text field changed, only the photo is sent (no empty `PATCH`).
- The separate `uploadAvatar` controller method was removed so a photo can only be uploaded through Save.

**Files.** `features/profile/presentation/edit_profile_screen.dart`, `features/profile/presentation/user_avatar.dart`, `features/profile/application/profile_controller.dart`.
**Tests.** `test/features/settings_profile_test.dart` — *a picked photo is not uploaded until Save is pressed*; *cancelling after picking a photo discards it*.

---

## 3. Calendar: Follow-up looked like Status change

**Symptom.** In the calendar, the *Follow-up* legend dot and the *Status change* dot were both orange.

**Cause.** Follow-up used orange `#FB8C00`. The legend's *Status change* swatch was drawn with the *Screening* status color (amber `#FFA000`) and real status-change dots take the color of the status moved to, so Screening moves looked identical to follow-ups.

**Fix.**
- Follow-up is now **teal** `#00897B` (text `#00544C`, tonal fill `#D3F0EC`). No status uses teal, so it cannot be confused with any status. It is a single constant (`StatusStyle.followUpColor`), so the calendar dots, agenda cards, application card follow-up text and the Alerts follow-up tile all changed together.
- The *Status change* legend swatch is now a multi-color ring of all five status colors, to show that the dot takes the color of the status.
- `DESIGN.md` (color table, calendar section, notification colors) updated.

**Files.** `app/theme/app_theme.dart`, `features/calendar/presentation/calendar_widgets.dart`, `docs/DESIGN.md`.
**Tests.** `test/features/calendar/calendar_screen_test.dart` expectation updated to the new color.

---

## 4. Clean, label-free bottom navigation

**Change.** The bar is now a floating pill with icons only; the selected tab is a filled circle with a white icon (as in the reference image).
- `NavigationBar` is kept (so behavior, the unread badge and `go_router` branches are unchanged) but wrapped in a stadium-shaped, elevated `Material` with side/bottom margin (`AppShell`).
- Theme: transparent bar, circular indicator in the primary color, `labelBehavior: alwaysHide`, selected icon `onPrimary`, others `onSurfaceVariant`. Height 76 → 64.
- Accessibility is preserved: each destination keeps a `tooltip` and its label for screen readers.

**Files.** `core/widgets/app_shell.dart`, `app/theme/app_theme.dart`, `core/constants/app_constants.dart`, `docs/DESIGN.md`.
**Tests.** Existing navigation tests pass unchanged.

---

## 5. Dashboard pie chart legend

**Symptom.** Status counts sat right after each label, so the numbers sat at different x-positions.

**Fix.** The legend is a fixed-width (168 px) column: dot → label (takes remaining space, ellipsis if long) → a 36 px right-aligned count column using tabular figures, with slightly more row spacing. Counts now form one straight column regardless of label length.

**Files.** `features/dashboard/presentation/dashboard_widgets.dart` (`PipelineCard`).

---

## 6. Interview detail layout

**Symptom.** Label/value rows were laid out with proportional flex and right-aligned values, so values started at different positions and wrapped unevenly.

**Fix.** `DetailLine` now uses one fixed-width label column (104 px) and a left-aligned value column; values all start at the same x and wrap under themselves. Rows are separated by dividers and have even vertical padding; the Application row stays a tappable link.

**Files.** `features/interviews/presentation/interview_detail_screen.dart`.

---

## 7. Congratulation / support pop-up for Offer and Rejected

**Change.** After the status is saved, moving an application to:
- **Offer** → *"Congratulations! 🎉"* dialog with a trophy badge, a one-shot confetti animation and a personal message naming the company.
- **Rejected** → *"Don't be discouraged"* dialog with a heart badge and an encouraging message.

How: the status sheet now returns the new status (not just `true`); `showStatusChangeSheet` shows the dialog once the sheet is closed, for both the detail screen and the swipe action in the list. Other statuses behave as before. The animation is finite (2.4 s), so it never keeps the UI busy. Copy lives in `ApplicationStrings`.

**Files.** `features/applications/presentation/status_celebration_dialog.dart` (new), `status_change_sheet.dart`, `core/constants/application_strings.dart`.
**Tests.** `test/features/status_celebration_test.dart`.

---

## 8. Fingerprint login (device-token design)

**Behavior.**
- **Settings → Account → Fingerprint login** (switch; only shown when the phone has an enrolled fingerprint/face). Turning it on: fingerprint scan → type the account password **once** → the server verifies it and issues a *device token* for this phone.
- **Login screen:** when it is on, a *Sign in with fingerprint* button appears under *Sign in*. Scan → the app sends the device token → signed in.
- Turning it off revokes the token on the server (best effort) and deletes it from the phone. Signing out keeps it on; deleting the account removes it.

**Why a device token (and not the password).** The first version stored the email + password on the phone. Now the password is never stored: the phone keeps a long random token that the server can revoke at any time. A stolen token can be killed; a stolen password cannot.

**Contract** (`API.md` → Auth, `DATABASE.md` → `device_tokens`, migration `V2__device_tokens.sql`):
- `POST /auth/device-token {password, deviceName?}` (signed in) → `{deviceToken}`; wrong password → `INVALID_CREDENTIALS`.
- `POST /auth/device-login {deviceToken}` (public, rate limited) → `AuthResponse`; unknown/revoked/expired → `UNAUTHORIZED`.
- `DELETE /auth/device-token {deviceToken}` → 204.
- Server stores only the SHA-256; valid 90 days from last use (sliding); max 5 live tokens per user (oldest revoked); **changing the password revokes all of them** (the app silently re-enrols this phone with the new password it just received); deleting the account cascades.
- If a token is rejected (revoked/expired) the app forgets it and says *Fingerprint login expired…*, so the user signs in with the password and turns it on again.

**Remaining limitation.** The token sits in the OS keystore/keychain (`flutter_secure_storage`) and the fingerprint is checked by the app (`local_auth`, `biometricOnly`) before it is used; the keystore key itself is not bound to the fingerprint. That is acceptable because the token is revocable and password-free; binding it at OS level (e.g. a `biometric_storage` key) is a possible hardening step.

**Platform setup.** `local_auth`; Android: `USE_BIOMETRIC`, `MainActivity` → `FlutterFragmentActivity`, `LaunchTheme` parent → `Theme.AppCompat.*`; iOS: `NSFaceIDUsageDescription`. With the fake backend the sensor is reported unavailable.

**Files.**
- Backend: `V2__device_tokens.sql`, `auth/DeviceTokenRepository.java`, `AuthService`, `AuthController`, `CommonWebConfig` (public `device-login`).
- App: `core/services/biometric_service.dart` (sensor + token store), `features/auth/application/biometric_controller.dart`, `auth_controller.dart`, `AuthRepository` + API/fake implementations, login and settings screens, `biometric_password_dialog.dart`.

**Tests.** Backend `DeviceTokenTest` (sign-in, hash-only storage, wrong password, revoked, expired, password-change revocation + re-enrol, 5-token cap, account deletion). App `test/core/biometric_actions_test.dart` (scan required, password never kept, rejected token forgotten, disable revokes, re-enrol after password change).
**Needs a real device to verify** the system fingerprint prompt (emulators need an enrolled fingerprint).

---

## 9. CSV export timestamps

**Symptom.** `createdAt` / `updatedAt` were ISO strings (`2026-11-01T02:35:12.534Z`), unreadable in Excel.

**Fix.** The CSV now prints them as `dd/MM/yyyy | hh:mm AM/PM`, e.g. `01/11/2026 | 10:35 AM`.
- Time zone: the app sends `X-Timezone` (device zone, same convention as reminders) with the export request; the server converts to that zone (UTC if the header is missing/unknown), so the times match what the user sees on the phone.
- Only the two requested columns changed. `followUpAt` and the JSON export keep ISO format (API contract). `API.md` updated.

**Files.** `backend/tracker-service/.../data/DataController.java`, `app/lib/data/api/api_data_repository.dart`, `app/lib/domain/repositories/misc_repositories.dart`, `app/lib/features/settings/application/account_actions.dart`, `docs/API.md`.
**Tests.** `InsightsDataTest.csvExportFormatsCreatedAndUpdatedInTheRequestedZone`.

---

## Verification

- App: `flutter analyze` clean; `flutter test` all passing (incl. new tests above).
- Backend: `tracker-service` 55 tests and `user-service` 33 tests (incl. 7 new device-token tests), 0 failures, against a throw-away local MySQL.
- Not verifiable here: real-device fingerprint prompt, gallery pick of HEIC/WebP, visual check of the new nav bar/dialogs on hardware.
