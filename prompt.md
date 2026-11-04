# Prompt: Build "JobTrail" – A Flutter Job Application Tracking App

## 1. Role & Goal

You are a senior Flutter engineer and mobile UX designer. Build a production-quality, cross-platform (Android + iOS) **job application tracking app** called **JobTrail**.

The app helps job seekers record every job they apply for, move each application through a hiring pipeline, schedule interviews, receive reminders, see progress on a dashboard, and view their whole job-search timeline on a calendar.

Deliver clean, runnable, well-structured code that follows Flutter best practices. Work in phases (see Section 15) and make sure the app compiles and runs after each phase.

---

## 2. Tech Stack & Constraints

| Concern | Choice |
|---|---|
| Framework | Flutter (latest stable), Dart 3+ with null safety |
| UI | Material 3, light + dark theme |
| State management | Riverpod (`flutter_riverpod`, with `riverpod_annotation` / code-gen if preferred) |
| Navigation | `go_router` (with a shell route for the bottom navigation bar) |
| Local database | Drift (SQLite) – offline-first, no backend required for v1 |
| Local notifications | `flutter_local_notifications` + `timezone` + `flutter_timezone` |
| Calendar | `table_calendar` |
| Charts | `fl_chart` |
| Links | `url_launcher` (open the job application link) |
| Date formatting | `intl` |
| Models | `freezed` + `json_serializable` (or plain immutable Dart classes) |
| Testing | `flutter_test`, `mocktail` |
| Lints | `flutter_lints` or `very_good_analysis` |

Constraints:
- Offline-first. All data is stored locally on the device. No login in v1.
- No hard-coded strings in widgets where avoidable; centralize in constants (or `l10n` ARB files for English, structured so more languages can be added).
- No business logic inside widgets. Use repositories and providers.
- Support Android 8+ (API 26) and iOS 13+.

---

## 3. Core Features

### 3.1 Job Application Management (CRUD)
The user can **add, view, edit, and delete** a job application. Each application contains:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID / auto int | auto | |
| `jobTitle` | String | Yes | e.g. "Flutter Developer" |
| `companyName` | String | Yes | |
| `location` | String | Yes | City / country, free text |
| `workArrangement` | Enum | Yes | `onsite`, `hybrid`, `remote` |
| `jobDescription` (JD) | String (long text) | No | Multi-line, supports paste of a large JD |
| `applicationLink` | String (URL) | No | URL the user applied through; validated; tap to open in browser |
| `employmentType` | Enum | No | `fullTime`, `partTime`, `contract`, `internship` |
| `salaryRange` | String | No | Free text, e.g. "RM 6,000 – 8,000" |
| `source` | Enum/String | No | LinkedIn, JobStreet, Indeed, Company site, Referral, Other |
| `appliedDate` | DateTime | Yes | Defaults to today |
| `status` | Enum | Yes | See 3.2, default `applied` |
| `notes` | String | No | Personal notes |
| `contactName` / `contactEmail` | String | No | Recruiter / hiring manager |
| `createdAt`, `updatedAt` | DateTime | auto | |

Behavior:
- List screen with **search** (title, company, location), **filter** (status, work arrangement, date range) and **sort** (newest, oldest, company A–Z, status).
- Swipe actions on a list item: swipe right → change status, swipe left → delete (with confirm + undo snackbar).
- Detail screen shows all fields, the status timeline, linked interviews, and quick actions (open link, edit, delete, add interview, change status).

### 3.2 Application Status Pipeline
Statuses (enum, in order): **Applied → Screening → Interview → Offer → Rejected**

- The user can change status at any time from the detail screen (bottom sheet / segmented selector) or via swipe on the list.
- Any status can move to any other status (e.g. Rejected can be reopened), but the UI highlights the normal forward flow.
- **Every status change is recorded** in a `status_history` table: `id, applicationId, fromStatus, toStatus, changedAt, note (optional)`. This powers the timeline on the detail screen and the calendar.
- Each status has a distinct color + icon used consistently across list chips, dashboard, and calendar:
  - Applied – blue, Screening – amber, Interview – purple, Offer – green, Rejected – red.
- Optional note when changing status (e.g. "Recruiter called, asked for expected salary").

### 3.3 Dashboard
Home tab. Show, using local data only:
1. **Greeting + summary card**: total applications, active applications (not Rejected/Offer), response rate (% that moved past Applied).
2. **Status overview**: tiles/chips with count per status (tap → opens filtered list).
3. **Pipeline chart**: donut or bar chart of applications by status (`fl_chart`).
4. **Applications over time**: line/bar chart of applications per week for the last 8 weeks.
5. **Upcoming interviews**: next 3 interviews with date/time, company, type; tap → interview detail.
6. **Recent activity**: last 5 status changes ("Moved Acme Corp to Interview – 2h ago").
7. **Empty state** with an illustration and a "Add your first application" button when there is no data.

Support pull-to-refresh and smooth loading/skeleton states.

### 3.4 Interview Management
The user can **add, edit, delete** interviews linked to a job application.

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID / int | auto | |
| `applicationId` | FK | Yes | |
| `title` | String | Yes | e.g. "Technical interview – Round 1" |
| `type` | Enum | Yes | `phone`, `video`, `onsite`, `technical`, `hr`, `final`, `other` |
| `dateTime` | DateTime | Yes | |
| `durationMinutes` | int | No | default 60 |
| `locationOrLink` | String | No | Meeting URL or address |
| `interviewerName` | String | No | |
| `notes` | String | No | Prep notes / questions to ask |
| `reminderOffsets` | List<Duration> | No | e.g. 1 day before, 1 hour before, 15 min before |
| `outcome` | Enum | No | `pending`, `passed`, `failed`, `cancelled` |

Behavior:
- Can be added from the application detail screen, from a dedicated "Add interview" FAB flow (user picks the application), or from the calendar by tapping a day.
- When the first interview is added to an application whose status is `applied` or `screening`, **offer** (don't force) to change status to `Interview`.
- Interviews list screen (upcoming / past tabs).
- Editing/deleting an interview reschedules/cancels its notifications.

### 3.5 Notifications
Two parts:

**A. Local push notifications (scheduled)**
- Interview reminders based on the user-chosen offsets (default: 1 day before and 1 hour before).
- Optional "follow-up reminder": a user can set a follow-up date on an application (e.g. "follow up in 7 days if no reply"). Setting in app settings: default follow-up days (off / 3 / 5 / 7 / 14).
- Request notification permission properly (Android 13+ `POST_NOTIFICATIONS`, exact alarm permission handling on Android 12+, iOS permission prompt) with a friendly explanation screen.
- Notifications survive device reboot (use the plugin's boot receiver) and respect the device time zone.
- Tapping a notification deep-links to the related interview or application detail screen.
- Cancel/reschedule correctly when an interview/application is edited or deleted.

**B. In-app Notification Center (a dedicated tab/section)**
- Stored in a `notifications` table: `id, type, title, body, relatedApplicationId, relatedInterviewId, createdAt, isRead`.
- Types: `interviewReminder`, `followUpReminder`, `statusChange`, `system`.
- List grouped by Today / Yesterday / Earlier, unread indicator, mark as read on tap, "Mark all as read", swipe to delete, "Clear all".
- Badge with unread count on the bottom nav icon.
- Every fired/scheduled reminder and every status change creates an in-app notification entry.

### 3.6 Calendar View
- Month calendar using `table_calendar` with a toggle for **Month / 2 weeks / Week** formats.
- Day markers (colored dots) for events:
  - Application applied date (blue)
  - Status changes (their status color)
  - Interviews (purple, emphasized)
  - Follow-up dates (orange)
- Tapping a day shows an **agenda list** below the calendar with everything that happened/is scheduled that day, grouped by type, each item tappable to its detail screen.
- A **"Job timeline" mode**: select an application and see its whole journey (applied → screening → interview → offer/reject) highlighted across the calendar, with a vertical timeline list.
- FAB on the calendar to quickly add an interview on the selected date.
- "Today" button to jump back; remember last selected format.

### 3.7 Settings
- Theme: System / Light / Dark.
- Notification preferences: default interview reminder offsets, follow-up default days, enable/disable notification types.
- Data: **Export** all data to JSON/CSV (share sheet) and **Import** from JSON backup; "Delete all data" with double confirmation.
- About / version.

---

## 4. Navigation & Screen Map

Bottom navigation (5 tabs, using `go_router` `StatefulShellRoute`):

1. **Dashboard** (`/`)
2. **Applications** (`/applications`)
   - `/applications/new`
   - `/applications/:id`
   - `/applications/:id/edit`
   - `/applications/:id/interviews/new`
3. **Calendar** (`/calendar`)
4. **Notifications** (`/notifications`) – with unread badge
5. **Settings** (`/settings`)

Additional routes:
- `/interviews` (upcoming/past), `/interviews/:id`, `/interviews/:id/edit`
- `/onboarding` (first launch: 3 short slides + notification permission request)

Use Hero animations and sensible page transitions. Provide deep links for notification taps.

---

## 5. Data Layer

### 5.1 Database tables (Drift)
- `job_applications`
- `status_history`
- `interviews`
- `app_notifications`
- `app_settings` (key/value) or use `shared_preferences` for settings

Add indexes on `status`, `appliedDate`, `interviews.dateTime`, `status_history.applicationId`.
Use foreign keys with cascade delete (deleting an application removes its interviews, history, and cancels related notifications).
Include a schema version and a migration strategy.

### 5.2 Repositories
Abstract interfaces + implementations:
- `JobApplicationRepository` (CRUD, search/filter/sort streams, change status)
- `InterviewRepository`
- `NotificationRepository` (in-app)
- `ReminderScheduler` (wraps `flutter_local_notifications`; schedule/cancel/reschedule)
- `DashboardRepository` / use-case classes for aggregate stats
- `BackupService` (export/import)

Expose data to the UI as `Stream`/`AsyncValue` so screens update reactively.

---

## 6. Architecture & Folder Structure

Feature-first clean architecture:

```
lib/
├── main.dart
├── app/
│   ├── app.dart                 # MaterialApp.router, theme
│   ├── router.dart              # go_router config
│   └── theme/                   # color schemes, text styles, status colors
├── core/
│   ├── constants/
│   ├── errors/
│   ├── utils/                   # date helpers, validators, url helpers
│   ├── widgets/                 # shared widgets (StatusChip, EmptyState, ConfirmDialog...)
│   └── services/                # notification service, timezone init
├── data/
│   ├── database/                # Drift database, tables, DAOs
│   └── repositories/            # implementations
├── domain/
│   ├── models/                  # JobApplication, Interview, StatusHistory, AppNotification
│   ├── enums/                   # ApplicationStatus, WorkArrangement, InterviewType...
│   └── repositories/            # abstract interfaces
└── features/
    ├── dashboard/
    ├── applications/
    ├── interviews/
    ├── calendar/
    ├── notifications/
    ├── settings/
    └── onboarding/
```

Each feature folder contains `presentation/` (screens, widgets), `application/` (providers/controllers), as appropriate.

---

## 7. UI / UX Requirements

- Material 3 with a calm, professional palette; seed color configurable in one place.
- Fully responsive for phones (portrait first); handle small screens and large text scale without overflow.
- Consistent spacing scale (4/8/12/16/24), rounded cards, clear typography hierarchy.
- Forms: use `Form` + `TextFormField`, inline validation, keyboard actions (next/done), date/time pickers, dropdown or segmented controls for enums, "unsaved changes" confirmation on back.
- Loading, empty, and error states for every list/screen.
- Haptic feedback on key actions, snackbars with Undo for destructive actions.
- Accessibility: semantic labels, minimum 48dp touch targets, sufficient contrast in both themes, don't rely on color alone for status (use icon + text).

---

## 8. Validation Rules

- `jobTitle`, `companyName`, `location`: required, trimmed, max 100 chars.
- `applicationLink`: must be a valid `http(s)` URL if provided.
- `appliedDate`: cannot be more than 1 day in the future.
- `interview.dateTime`: warn (not block) if in the past; block if the same application already has an interview at the exact same time.
- `contactEmail`: valid email format if provided.
- JD supports up to ~10,000 characters.

---

## 9. Edge Cases to Handle

- Notification permission denied → show an in-app banner explaining how to enable it in system settings; app still works.
- Device time-zone change → reschedule pending notifications.
- Deleting an application with upcoming interviews → confirm and cancel their notifications.
- Rescheduling an interview in the past → no notification scheduled.
- Very long titles/JD text → ellipsis in lists, expandable "Read more" in detail.
- Invalid or unreachable links → graceful snackbar if `url_launcher` fails.
- Large data sets (500+ applications) → lazy lists with pagination or efficient queries.

---

## 10. Sample / Seed Data

Provide a debug-only seeder (behind a settings toggle or `kDebugMode`) that inserts ~15 realistic applications across all statuses, several interviews (past + upcoming), and status history, so the dashboard and calendar can be demoed immediately.

---

## 11. Testing Requirements

- **Unit tests**: repositories (in-memory Drift DB), status-change logic and history recording, dashboard stat calculations, validators, reminder-offset calculation.
- **Widget tests**: application form validation, status chip rendering, empty states, notification list grouping.
- **Integration test** (one happy path): add application → change status to Interview → add interview → see it on dashboard and calendar.
- Aim for meaningful coverage of the domain and data layers (≥ 70%).

---

## 12. Platform Setup Checklist

Include the exact configuration steps/code for:
- **Android**: `AndroidManifest.xml` permissions (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` as appropriate, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`), notification receivers, desugaring (`coreLibraryDesugaring`) required by `flutter_local_notifications`, `queries` intent for `url_launcher`.
- **iOS**: `AppDelegate` notification delegate setup, `Info.plist` entries (`LSApplicationQueriesSchemes` for http/https).
- App icon, splash screen, and app name (`flutter_launcher_icons`, `flutter_native_splash`).

---

## 13. Code Quality Standards

- Follow the Dart style guide; keep files focused (< ~300 lines when possible).
- Use `const` constructors, `final` fields, immutable models, `copyWith`.
- Meaningful names, doc comments on public APIs, no dead code or unused imports.
- Handle errors with typed failures; never swallow exceptions silently.
- No `print` statements – use a logger.
- Run `dart format`, `flutter analyze` (zero warnings) before finishing each phase.

---

## 14. Acceptance Criteria

The project is complete when:
1. A user can add a job application with title, location, JD, work arrangement, and application link, and edit/delete it.
2. The user can change status among Applied, Screening, Interview, Offer, and Rejected, and see the full status history.
3. The dashboard shows accurate counts, charts, upcoming interviews, and recent activity from real stored data.
4. The user can add/edit/delete interviews linked to applications and receive local reminders at the chosen times.
5. The notification section lists reminders and status changes, supports read/unread, and shows a badge count.
6. The calendar shows applied dates, status changes, interviews, and follow-ups with per-day agenda and a per-application timeline.
7. Data persists across app restarts and reboots; scheduled notifications still fire after reboot.
8. Light and dark themes both look correct; no overflow or layout errors on small screens.
9. `flutter analyze` is clean and all tests pass.

---

## 15. Delivery Plan (build in this order)

1. **Phase 1 – Foundation**: project setup, dependencies, theme, router, folder structure, Drift database + models + enums.
2. **Phase 2 – Applications**: CRUD, list with search/filter/sort, detail screen, form with validation.
3. **Phase 3 – Status pipeline**: status change UI, status history, timeline widget, swipe actions.
4. **Phase 4 – Interviews**: CRUD, lists, link to applications, status-change suggestion.
5. **Phase 5 – Notifications**: permission flow, scheduling service, in-app notification center, deep links, badge.
6. **Phase 6 – Dashboard**: stats, charts, upcoming interviews, recent activity.
7. **Phase 7 – Calendar**: markers, agenda list, timeline mode, quick add.
8. **Phase 8 – Settings & polish**: theme, backup/export/import, onboarding, empty/error states, accessibility pass.
9. **Phase 9 – Testing & release prep**: tests, platform config, icons/splash, README.

After each phase: summarize what was built, list the files created/changed, and give the commands to run the app and tests.

---

## 16. Final Deliverables

- Complete Flutter project source code.
- `README.md` with setup, run, build (APK / IPA) instructions and architecture overview.
- `pubspec.yaml` with pinned, compatible dependency versions.
- Test suite and instructions to run it.
- A short list of "Future improvements" (cloud sync with Firebase/Supabase, resume/attachment storage, email-to-application parsing, home-screen widget, multi-language).

> Start with Phase 1 now. Ask me only if something critical is ambiguous; otherwise make sensible decisions, state your assumptions briefly, and proceed.
