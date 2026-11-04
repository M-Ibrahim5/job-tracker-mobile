# Session 08 — QA, Polish & Release Prep

**Depends on:** all previous sessions.
**Read first:** `docs/00-README.md`, `docs/DESIGN.md` (§6–7), every earlier session's *Handoff notes*.
**Owns:** cross-cutting fixes, `app/integration_test/`, `backend/e2e`, READMEs, release config.

## Tasks

1. **Reconcile**: read all handoff notes; fix deviations from `API.md`/`DATABASE.md`/`DESIGN.md` (update docs if the code is right). Run both stacks together (local MySQL + backend + app on emulator) and walk through every screen against the mockups; file fixes.
2. **Integration test (app)** `integration_test/happy_path_test.dart` against the fake backend (and a documented variant for the real one): register → add application → change status to Interview → add interview → see it on Dashboard (upcoming) and Calendar (marker + agenda) → alerts list shows the status-change entry with badge → logout.
3. **Backend e2e**: the `backend/e2e` module (`mvn -pl e2e test -De2e=true`) hitting a running stack through the gateway along the same happy path; CI-ready.
4. **Accessibility pass**: semantics labels (icon buttons, badge, charts), 48dp targets, focus order in forms, contrast check of both themes, large-text and small-screen overflow sweep (320×568, textScale 1.5 and 2.0).
5. **Error/edge cases** from the original spec: notification permission denied banner; timezone change reschedules; delete application with upcoming interviews (confirm + reminders cancelled); past-time interview reschedule → no notification; very long titles ellipsis / JD Read more; `url_launcher` failure snackbar; 500+ applications performance (list scroll, query time); token expiry mid-session; offline → friendly error + retry (no crashes).
6. **Security review (backend)**: ownership checks on every query, rate limits, helmet, password hashing params, JWT secret from env, refresh reuse detection, upload limits/types, no stack traces in responses, SQL only with bound parameters, internal API not exposed by the gateway, CORS closed, `.env` not committed.
7. **Release prep**:
   - App: app name, launcher icon and splash (`flutter_launcher_icons`, `flutter_native_splash`: primary `#3F51B5`, white briefcase mark as on the Login logo tile), Android `minSdk 26`, iOS 13 target, build instructions for APK/AAB/IPA, production `API_BASE_URL` via dart-define, release signing notes.
   - Backend: production deployment notes (Docker is optional and only for deployment, never required for local dev), env docs, migrations (Flyway, applied when a service starts), backup suggestion for MySQL, HTTPS/reverse proxy note.
8. **Docs**: root `README.md` (what it is, architecture diagram in text, setup for backend + app, running tests, build/release), "Future improvements" list (social login, cloud push via FCM, resume/attachment storage, email-to-application parsing, home-screen widget, multi-language, offline cache + sync, import backup).

## Definition of Done
- Fresh clone → follow root README → both stacks run; all test suites pass: `cd backend && mvn verify`, `cd app && dart format --set-exit-if-changed . && flutter analyze && flutter test`, integration test passes.
- Acceptance criteria from the original product brief all demonstrably met (add/edit/delete application; 5-status pipeline with history; accurate dashboard; interviews with local reminders; alerts with read/unread + badge; calendar with markers/agenda/timeline; data persists across restarts and reboots; light/dark with no overflow).
- Final summary with known issues listed.

## Handoff notes
**Update — backend migrated to Spring Boot.** After this session's QA pass the Node/TypeScript API was replaced by Java 21 / Spring Boot 3 microservices (gateway, user-service, tracker-service; see sessions 01–02 and `backend/README.md`). The `API.md` contract is unchanged, so the app needed no changes. Where the notes below mention `npm run lint`, `npm test`, `npm run e2e`, Prisma, helmet or Zod, read: `mvn verify` (92 tests), `mvn -pl e2e test -De2e=true`, Flyway, the gateway's limits and the hand-written validators. The backend security checklist now lives in `backend/README.md` (re-reviewed for the new layout).

**Final summary**

Verified in this environment: `app`: `dart format --set-exit-if-changed .`, `flutter analyze` (0 issues) and `flutter test` (414 tests) pass; `backend`: `npm run lint` passes and `npm test` (74 tests) passes against the local MySQL 8; `npm run e2e` (17 checks) passes against a real server + MySQL.
**Not verified (no emulator/Mac here):** the integration test on a device (it is run headless as `test/app/happy_path_headless_test.dart`), the Android/iOS release builds (Gradle cannot download dependencies here: SSL `PKIX` error), notification delivery, reboot persistence, and the app against the live API.

**Done**
1. **Reconcile.** Handoffs read; code deviations that are right were written into the docs (`docs/API.md` → *Implementation notes*, `docs/DESIGN.md` → §8 *As built*). Cross-cutting bugs found by the new end-to-end/sweep tests and fixed:
   - *Crash on tab switches during route transitions*: the FABs of Applications / Calendar / Interviews shared the default Hero tag (`heroTag: null` now).
   - *Release builds had no network*: `INTERNET` was only in the debug manifest; now in the main manifest.
   - Applications list: post-frame callback read `maxScrollExtent` before layout (null-check crash when re-entering the screen).
   - Layout fixes at large text: dashboard donut centre/legend and weekly axis, summary stat labels, interview rows (detail + list), application detail rows, calendar legend, auth logo, status chips row, `NoticeBanner`/`DateBlock` (session 06/07 notes), segmented control (check icon dropped when text is large).
2. **Integration test** `app/integration_test/happy_path_test.dart` (fake backend by default; `--dart-define=REAL_BACKEND=true` for a live server; documented in the file and `app/README.md`). The same flow runs headless in `flutter test` as `test/app/happy_path_headless_test.dart` and passes.
3. **Backend e2e** (`backend/e2e`, `mvn -pl e2e test -De2e=true -Dbase.url=...`, non-zero exit on failure): isolation, conflict, reminders, dashboard, calendar, alerts, export, refresh-reuse, delete-all; it deletes both throw-away accounts it creates. *(Originally `npm run e2e`.)*
4. **Accessibility.** `test/app/accessibility_test.dart` runs Flutter's `labeledTapTarget`, `androidTapTarget` (48dp) and `textContrast` guidelines on 10 screens in both themes; fixed the calendar header (title 48dp, chevron labels). `test/app/overflow_sweep_test.dart`: every screen at 320×568 with text ×1.5 and ×2.0, light and dark, scrolled to the end.
5. **Edge cases** (`test/app/edge_cases_test.dart` + earlier sessions' tests): permission-denied banner, timezone change re-sync, delete with upcoming interviews → reminder re-sync, past-time interviews → no reminders (scheduler + backend tests), very long titles / JD *Read more*, `url_launcher` failure snackbar, 620-application paging (+ search 600 < 500 ms), token refresh/expiry (interceptor tests), offline → Retry states.
6. **Security review (backend).** Findings and state are in `backend/README.md` → *Security checklist*. Changes: production refuses weak/placeholder `JWT_SECRET` and non-https `PUBLIC_BASE_URL`; added a global 300 req/min/IP limiter (auth stays 10/min); avatar file names are random. Verified OK: ownership scoping everywhere (404s), argon2id, hashed + rotating refresh tokens with reuse detection, no CORS, validation on every body/query, bound SQL parameters only, upload type/size/magic-byte checks, generic 500s, `.env` ignored.
7. **Release prep.** App name *JobTrail*, `minSdk 26`, iOS target 13.0, launcher icon + native splash generated from `app/assets/branding/` (`flutter_launcher_icons`, `flutter_native_splash`), release signing via git-ignored `android/key.properties` (debug-key fallback for local `--release`), build commands for APK / AAB / IPA with `--dart-define=API_BASE_URL`. Backend deployment notes (env table, Flyway on start, HTTPS proxy in front of the gateway, `mysqldump` backups, optional Docker) in `backend/README.md`.
8. **Docs.** Root `README.md` (architecture diagram, setup, tests, release, known issues, future improvements).

**Known issues / open**
- Everything under *Not verified* above must be exercised on a device before shipping (checklist in `app/README.md`).
- Rate limit is per IP and in memory; forgot-password is a stub; interview reminder bodies aren't rewritten when the company/title changes; (`q` wildcard escaping and the `npm audit` advisories listed here were resolved by the Spring Boot migration).
- Acceptance criterion “data persists across restarts and reboots” relies on server persistence (verified by the e2e) and on the boot receiver + resync-on-launch (not run on a device).
- No git commit has been made (the repository has no commits yet; the tree holds sessions 01–08). Suggested: one initial commit, `S08: QA, accessibility, e2e, release prep and docs`.
