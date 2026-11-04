# Session 05 — App: Applications & Status Pipeline

**Depends on:** session 03. (Live against backend session 02; use fakes before.)
**Read first:** `docs/00-README.md`, `docs/DESIGN.md` §4.3 (status tiles only), §4.4, §4.5, §4.6, `docs/API.md` (Applications).
**Owns:** `app/lib/features/applications/`, `data/api/api_job_application_repository.dart`. Interview parts of the detail screen use a provider that session 06 fills — render the section from `interviewsForApplicationProvider` (stub returning an empty list/loading until session 06).

## Goal
Complete application management: list with search/filter/sort/swipe, detail with status timeline, add/edit form with validation, and the status change flow.

## Tasks

1. **Repository**: implement `ApiJobApplicationRepository` against `API.md` (list with paging, get, create, update, delete, changeStatus, history, timeline). Keep the fake in sync.
2. **Providers** (`application/`): `applicationFilterProvider` (StateProvider<ApplicationFilter>), `applicationListProvider` (paged `AsyncNotifier` with `loadMore`, refresh; resets when filter changes; debounce search 300 ms), `applicationDetailProvider(id)`, `statusHistoryProvider(id)`, `applicationFormController`, `statusChangeController`.
3. **List** (`/applications`) per DESIGN §4.4: search, filter/sort bottom sheet (status multi, work arrangement, date range, sort radio), status filter chips (single quick filter synced with sheet), cards with `StatusChip`, arrangement tag, "Next: …" / "Follow up …" hints, infinite scroll (page 20), pull-to-refresh, skeleton, empty (no data vs no results), error with retry. Deep-link filter: `/applications?status=interview` (used by the dashboard tiles).
   - `Dismissible` swipes: right → open status sheet (don't actually dismiss the item), left → confirm dialog, then remove from UI with **Undo snackbar**; the real `DELETE` fires only when the snackbar closes without Undo (also flush on screen dispose/app pause).
4. **Status sheet** (`StatusChangeSheet`): 5 options with status styling, current disabled/marked, next-in-flow highlighted dashed, optional note (≤ 500), Confirm → `changeStatus`. Used by list swipe and detail. Haptic feedback on success; update list + detail + history caches.
5. **Detail** (`/applications/:id`) per DESIGN §4.5: header, quick actions (Open link via `url_launcher` with snackbar on failure; Add interview → `/applications/:id/interviews/new`; Follow-up → date picker setting `followUpAt` via PATCH, or clear), status selector, timeline, interviews section (via stub provider), JD with Read more (expand/collapse), details list (tap email → `mailto:`), notes, delete with confirm (and warning if it has upcoming interviews → after delete call `ReminderScheduler.resync()` hook from `core/services`, no-op until session 06), Hero animation title between list card and detail.
6. **Form** (`/applications/new`, `/applications/:id/edit`) per DESIGN §4.6: all fields, validators from `core/utils/validators.dart` (add `jobDescription` ≤ 10,000, link, email, appliedDate), server `fields` errors mapped onto inputs, default `appliedDate` today, source dropdown, follow-up switch row (default date = today + `settings.defaultFollowUpDays`, hidden/disabled if the setting is Off), unsaved-changes `PopScope` confirm, loading state on Save, on success pop to detail (edit) or detail of new item.

## Definition of Done
- Matches mockups (list, detail, form; light+dark; 320px width; 1.5× text scale without overflow).
- Tests: unit — filter→query mapping, list notifier paging/reset/debounce, undo-delete timing (fake async), status sheet logic; widget — form validation messages, list empty/error/skeleton states, swipe delete → undo restores, status sheet selection, detail read-more.
- Acceptance: user can add, edit, delete an application; change among all 5 statuses (including reopening Rejected); see full history with notes.
- `dart format . && flutter analyze && flutter test` clean.

## Handoff notes
**Done**
- `dart format . && flutter analyze` clean (0 issues); `flutter test` 206/206 pass (new: 25 unit + 61 widget tests under `test/features/applications/`).
- `ApiJobApplicationRepository` (list with paging/filter query, get, create, update, delete, changeStatus, history, timeline) in `data/api/`; stub removed from `api_stubs.dart`; the fake needed no changes.
- Providers in `features/applications/application/`: `applicationFilterProvider`, `applicationListProvider` (paged, debounced search via `searchDebounceProvider`, `loadMore`/`refresh`/`applyUpdated`/`removeById`), `applicationDetailProvider(id)`, `statusHistoryProvider(id)`, `applicationFormControllerProvider`, `statusChangeControllerProvider`, `pendingDeleteProvider` (Undo window), `deleteApplicationProvider`, pure `status_flow.dart`.
- Screens: list (`/applications`, supports `?status=`), filter/sort sheet, status sheet, detail (Hero title, quick actions, status selector with dashed next step, timeline, interviews section, Read more, mailto), add/edit form (server `fields` errors, unsaved-changes `PopScope`, default follow-up).
- Strings live in `core/constants/application_strings.dart` (kept separate from `app_constants.dart` to avoid clashes with parallel sessions).

**Deviations / decisions**
- Fixed a shared bug in `core/utils/snackbar.dart`: Flutter snackbars with an action persist by default, so `showUndoSnackBar` never closed and the delayed DELETE would never fire. It now sets `persist: false`.
- `AppTextField` gained an optional `onTap` (used by the read-only date field). `Validators` gained `jobDescription` and `applicationLink` (+ `Limits.linkLength`, `Limits.note`).
- Swipe-delete only hides the row (`pendingDeleteProvider`); the DELETE is sent when the snackbar closes without Undo, and flushed when the screen is disposed or the app is paused. Detail-screen delete is immediate (confirm dialog, no Undo).
- `interviewsForApplicationProvider` (`features/interviews/application/interviews_providers.dart`) is a stub returning an empty list; session 06 fills the body and keeps the signature.
- `core/services/reminder_scheduler.dart` defines `ReminderScheduler.resync()` + `reminderSchedulerProvider` (no-op). It is called after save/delete; session 06 overrides the provider.
- `applicationsRevisionProvider` is bumped after every successful create/update/delete/status change; dashboard/calendar (session 07) should `ref.watch` it. The list patches itself instead of refetching. The list and detail also reload on `dataRevisionProvider` (delete-all data).
- New applications start with follow-up ON at today + `settings.defaultFollowUpDays` (09:00); when the setting is Off the switch is disabled with a hint (an existing follow-up can still be toggled). Tapping the selected employment-type chip clears it.
- Edit sends every editable field via `PATCH` (blank optionals as `null` clear them).

**Not done / open**
- Not run on a device/emulator; Hero list→detail animation, haptics and `url_launcher` on a real device are unverified manually.
- No git commit was made (working tree also holds sessions 03/04 uncommitted work). Suggested message: `S05: applications list, detail, form and status pipeline`.
- Manual script: sign in (`USE_FAKE=true`) → Applications → search, filter, swipe right to change status, swipe left to delete + Undo → open one, change status with a note, set a follow-up, edit, delete.
