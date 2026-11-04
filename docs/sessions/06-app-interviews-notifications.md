# Session 06 — App: Interviews, Reminders, Alerts

**Depends on:** session 05 (detail screen hooks). Live backend: session 02.
**Read first:** `docs/00-README.md`, `docs/DESIGN.md` §4.8, §4.9, `docs/API.md` (Interviews, Notifications, Device reminders), `docs/DATABASE.md` Rules (reminder behavior).
**Owns:** `app/lib/features/{interviews,notifications}/`, `core/services/reminder_scheduler*.dart`, Android/iOS notification config.

## Goal
Interview CRUD with the status-suggestion flow, local push reminders that survive reboot/timezone change, and the in-app Alerts center with badge and deep links.

## Tasks

1. **Repositories**: `ApiInterviewRepository`, `ApiNotificationRepository`, `ApiReminderRepository` per `API.md` (+ fakes).
2. **Interviews list** (`/interviews`): Upcoming / Past tabs (paged), rows like the mockup (date block, title, "Company · time · type", outcome pill), empty/error/skeleton. `/interviews/:id` detail (all fields, outcome change to passed/failed/cancelled, open meeting link, edit, delete).
3. **Interview form** per DESIGN §4.8: routes `/applications/:id/interviews/new`, `/interviews/new?date=YYYY-MM-DD` (application picker + prefilled date; used by the calendar FAB and an "Add interview" FAB flow), `/interviews/:id/edit`. Fields/validation per spec; reminder offsets default from `settingsProvider`; past date → non-blocking warning banner; duplicate time → map `INTERVIEW_CONFLICT` to a blocking field error on the time field. **Status suggestion**: before saving a *new* interview, if the application status is `applied`/`screening` and it has no interviews yet, show the offer card/dialog ("Move {company} to Interview?"); Yes → create the interview then `changeStatus(interview)`; No → create only. Never forced.
4. **ReminderScheduler** (`core/services/reminder_scheduler.dart`) wrapping `flutter_local_notifications` + `timezone` + `flutter_timezone`:
   - `init()` (timezone setup, channels: `interview_reminders`, `follow_up_reminders`), `requestPermission()` (Android 13 `POST_NOTIFICATIONS`, exact alarm on Android 12+ via `canScheduleExactNotifications`/settings intent with fallback to inexact, iOS prompt), `resync()`: fetch `GET /reminders/upcoming`, cancel all previously scheduled ids, schedule each item at `fireAt` (tz-aware, `exactAllowWhileIdle`), payload = deep-link path (`/interviews/:id` or `/applications/:id`); id = `hash(key) & 0x7fffffff`. `cancelAll()` (also wired as the `ReminderCanceller` from session 04's logout).
   - Call `resync()` on: app start (authenticated), login, after any interview/application create/edit/delete, after settings notification changes, on app resume, and on device **timezone change** (listen with `WidgetsBindingObserver.didChangeLocales`/a periodic tz check on resume).
   - Reboot persistence: enable the plugin's boot receivers in `AndroidManifest.xml` (`ScheduledNotificationBootReceiver`, `RECEIVE_BOOT_COMPLETED`), plus the app calls `resync()` on next launch as a safety net.
   - Unit-test with a fake plugin wrapper: correct number/time of schedules, no past times, replacement on resync, tz conversion.
5. **Permission UX**: friendly explanation screen/sheet before the first system prompt (also used by onboarding). If denied: `NoticeBanner` at top of Alerts ("Phone reminders are off…") with "Enable" → `openAppSettings()`. App fully works without permission.
6. **Alerts** (`/notifications`) per DESIGN §4.9: paged list grouped Today/Yesterday/Earlier (pure function `groupNotifications(list, now)` — unit test boundaries at midnight and timezone), unread tint + dot, tap → `read` + deep link, swipe to delete, "Mark all read", "Clear all" (confirm), empty state, pull-to-refresh. `unreadCountProvider` (polls on resume, after actions, and every 60 s while the app is foreground) feeding the nav badge from session 03.
7. **Deep links**: tapping a local notification (foreground, background, and cold-start via `getNotificationAppLaunchDetails`) navigates with go_router; if unauthenticated, redirect to login then continue to the path.
8. Wire the hooks left by session 05: detail screen's interviews section (`interviewsForApplicationProvider`) and `ReminderScheduler.resync()` after application delete.
9. Platform setup: Android manifest permissions (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`), receivers, core library desugaring in `app/build.gradle`; iOS `AppDelegate` UNUserNotificationCenter delegate setup, `Info.plist` `LSApplicationQueriesSchemes` (http, https, mailto).

## Definition of Done
- Add / edit / delete interviews; first-interview status suggestion works both ways; conflicts and past-date warnings behave per spec.
- Local notifications fire at the offsets (verify by creating an interview 2 minutes ahead with a custom 1-minute offset on a real device/emulator — note result in handoff), are rescheduled on edit/delete, survive reboot, and tapping opens the right screen.
- Alerts center: grouping, read/unread, mark all, clear all, swipe delete, badge count accurate.
- Tests: scheduler (fake plugin), grouping, interview form validation/conflict mapping/status-suggestion logic, alerts list widget tests (grouping headers, unread styles), deep-link routing.
- `dart format . && flutter analyze && flutter test` clean.

## Handoff notes
**Done**
- `dart format . && flutter analyze` clean (0 issues); `flutter test` 313/313 pass (≈100 new: scheduler with a fake gateway, grouping boundaries, interview flow/validation/conflict/status-suggestion, interview list/detail/form, Alerts list + permission banner, app coordinator + deep links, REST repositories).
- REST repositories `ApiInterviewRepository`, `ApiNotificationRepository`, `ApiReminderRepository` (stubs removed). Fakes were already complete.
- **Interviews** (`features/interviews/`): `/interviews` (Upcoming/Past tabs, paged), `/interviews/:id` (all fields, outcome chips, open link, edit, delete), form on `/applications/:id/interviews/new`, `/interviews/new?date=YYYY-MM-DD` (application picker) and `/interviews/:id/edit`. Reminder chips default from `settingsProvider`, custom offsets (max 5, ≤ 30 days), past-date warning banner, `INTERVIEW_CONFLICT` → error on the Time field, server `fields` mapped, unsaved-changes guard. Status suggestion is a dialog shown on Save for a *new* interview when the app is Applied/Screening with no interviews (Yes → create then `changeStatus(interview)`, Not now/dismiss → create only).
- **Reminders** (`core/services/reminder_scheduler.dart`, `flutter_notification_gateway.dart`): `ReminderScheduler` (init, requestPermission, notificationsEnabled, resync, checkTimezone, cancelAll — also the logout `ReminderCanceller`). `LocalReminderScheduler` fetches `/reminders/upcoming`, drops non-future times, cancels all, schedules the soonest 60 with id = FNV hash of the key, payload `/interviews/:id` or `/applications/:id`, exact alarms when allowed else inexact; resyncs are coalesced. The platform is behind `NotificationGateway` (tests use a fake). `main` swaps in the real scheduler (`app/reminder_setup.dart`); the default provider is a no-op so tests never touch plugins.
- **Triggers** (`app/app_coordinator.dart`, wraps the router): sign-in/launch, `applicationsRevisionProvider`/`interviewsRevisionProvider`/`dataRevisionProvider` bumps, app resume (+ timezone check), reminder switches changed in settings (done in `SettingsController`). Reboot: boot receivers in the manifest plus the resync on next launch.
- **Alerts** (`/notifications`): Today/Yesterday/Earlier via pure `groupNotifications`, unread tint + dot + bold, tap → mark read + deep link, swipe delete, Mark all read, Clear all (confirm), pull-to-refresh, paging, empty/error states, permission banner. `unreadCountProvider` is now backed by `UnreadCountController` (refreshed on sign-in, resume, after actions and every 60 s).
- **Permission UX**: explanation sheet before the first OS prompt (`showNotificationPermissionSheet`, reusable by onboarding), shown the first time an interview with reminders is saved or via the banner's Enable; afterwards Enable opens system settings (`permission_handler` added for `openAppSettings`).
- **Deep links** (`app/deep_links.dart`): taps and the cold-start payload go to `pendingDeepLinkProvider`; opened with `router.push` once signed in (kept while signed out). Only `/interviews/:id` and `/applications/:id` are accepted.
- Platform: Android manifest (permissions, `ScheduledNotificationReceiver`, boot receiver, http/https/mailto `<queries>`), core-library desugaring in `build.gradle.kts`; iOS `AppDelegate` sets the `UNUserNotificationCenter` delegate, `Info.plist` `LSApplicationQueriesSchemes`.

**Fixes to shared code found by the tests**
- `DateBlock` overflowed at large text (now scales down inside its fixed 52×56 box); `NoticeBanner` collapsed to ~1000 px tall on narrow screens/large text (action now stacks under the message).
- `AppTextField.onTap` already existed from session 05; session 05's `interviewsForApplicationProvider` stub is replaced by the real provider (its detail test now uses an application without interviews).

**Not done / open**
- **Not verified on a device or emulator.** `flutter build apk --debug` fails in this environment (Gradle cannot download dependencies: SSL `PKIX path building failed`), so the Android manifest/Gradle changes, boot persistence, exact-alarm behavior and the "interview 2 minutes ahead with a 1-minute custom offset" check are **unverified**. Please run that check on a device/emulator and note the result here. iOS was not built either.
- The status suggestion is a dialog on Save, not an inline card in the form.
- No navigation entry to `/interviews` exists yet besides the route (session 07's dashboard "See all" should link to it).
- No git commit (working tree also holds sessions 03–05). Suggested message: `S06: interviews, local reminders, alerts center and deep links`.
- Manual script: sign in → add an interview (first one offers "Move to Interview?") → allow notifications → Alerts shows the permission banner when denied → edit the interview time and confirm reminders move → delete it → tap a delivered reminder (foreground, background, killed) and check it opens the interview.
