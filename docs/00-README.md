# JobTrail — Implementation Guide

Job application tracker: **Flutter** mobile app + **Java 21 / Spring Boot 4 REST API (microservices behind a gateway)** + **MySQL 8**.
Design source of truth: `DESIGN.md`. Data: `DATABASE.md`. Contract between app and server: `API.md`.

## Architecture decisions (change here first if you disagree)

| Topic | Decision |
|---|---|
| Database | MySQL 8 (server-side). The app never talks to MySQL directly. |
| Backend | **Java 21 + Spring Boot 4 + Maven**, split into microservices behind an API gateway: `gateway` (:3000, the only public URL; routing, rate limits), `user-service` (:3001; auth, profile, settings, avatars) and `tracker-service` (:3002; applications, interviews, notifications, reminders, dashboard, calendar, export). Spring Web + `JdbcClient` (plain SQL), Flyway migrations, jjwt (HS256), argon2id via Spring Security Crypto. Tests: JUnit 5 + MockMvc against the **local MySQL 8** (no Docker anywhere in the dev workflow; credentials go in `backend/.env`, never committed). `API.md` is unchanged by the split: the app still talks to one base URL. |
| Service boundaries | One MySQL schema, tables owned per service (`users`, `refresh_tokens`, `user_settings` → user-service; the rest → tracker-service). Foreign keys and their cascades stay. The tracker reads reminder preferences from the user service via a key-protected `/internal` API that the gateway does not expose. Details: `backend/README.md`. |
| Auth | Email + password. JWT access (15 min) + rotating refresh token (30 days) stored hashed. No social login in v1. |
| App | Flutter (Dart 3), Material 3, Riverpod, go_router, Dio, flutter_secure_storage, flutter_local_notifications, table_calendar, fl_chart, url_launcher, intl. |
| Offline | **Not offline-first anymore**: server is source of truth. The app shows cached last-good data only in memory; network errors show retry states. (Local DB/Drift is dropped.) |
| Reminders | Server computes reminder schedule (`GET /reminders/upcoming`); the app schedules *local* notifications from it. In-app notification rows are created server-side. |
| Repo layout | Monorepo — see below. |
| Removed from original spec | Drift, import/restore backup, Firebase. Export (JSON/CSV) kept. |

## Repo layout

```
jobtrail/
├── docs/            # this folder (DESIGN.md, API.md, DATABASE.md, sessions/)
├── backend/         # Spring Boot microservices (Maven multi-module: common, user-service, tracker-service, gateway, seed, e2e)
└── app/             # Flutter app  (move the existing generated `jobtrail` Flutter project here)
```

## Sessions (one Claude Code session each)

Each file in `sessions/` is a self-contained brief. Run them in order; the dependency graph shows what can run in parallel.

| # | File | Scope | Needs |
|---|---|---|---|
| 01 | `sessions/01-backend-foundation.md` | Maven multi-module project, gateway, local MySQL + Flyway, user-service (auth, profile, settings) | — |
| 02 | `sessions/02-backend-features.md` | tracker-service: applications, status, interviews, notifications, dashboard, calendar, export, reminders; seed | 01 |
| 03 | `sessions/03-app-foundation.md` | Refactor Phase 1 app: drop Drift, theme/tokens, Dio client, auth plumbing, router, shared widgets | — (uses `API.md`) |
| 04 | `sessions/04-app-auth-profile-settings.md` | Login, Register, Settings, Edit profile, logout | 03 (+01 to run live) |
| 05 | `sessions/05-app-applications.md` | Applications list/detail/form + status pipeline | 03 (+02 live) |
| 06 | `sessions/06-app-interviews-notifications.md` | Interviews, local reminders, alerts center, badge, deep links | 05 (+02 live) |
| 07 | `sessions/07-app-dashboard-calendar.md` | Dashboard, Calendar | 05, 06 |
| 08 | `sessions/08-qa-release.md` | Integration tests, platform config, README, polish | all |

```
01 ──► 02 ───────────────┐
03 ──► 04 ──► 05 ──► 06 ──► 07 ──► 08
        (04 and 05 can run in parallel after 03)
```
Backend (01→02) and app (03→07) tracks run **in parallel**; the app develops against `API.md` with a fake in-memory repository until the backend is ready, then switches via a single provider override / `--dart-define=API_BASE_URL=...`.

## How to start a session

From the repo root:
```
claude
> Read docs/00-README.md, docs/DESIGN.md (if UI), docs/API.md, docs/DATABASE.md (if backend),
> then docs/sessions/05-app-applications.md and implement it fully. Follow its Definition of Done.
```
Rules every session follows (also put these in a root `CLAUDE.md`):
1. `API.md` and `DATABASE.md` are the contract. If you must change them, change the doc in the same commit and say so in the summary.
2. Don't touch files owned by other sessions beyond what your brief lists.
3. Run the checks in your brief (`mvn verify` / `flutter analyze && flutter test`) before finishing; fix, don't skip.
4. Commit at the end with a message `S0N: <summary>`; leave the working tree clean.
5. At the end, append a short "Handoff notes" section to your session file (what's done, deviations, open issues).

## Suggested root CLAUDE.md

```
# JobTrail
Monorepo: backend/ (Java 21 + Spring Boot 4 + Maven microservices + MySQL), app/ (Flutter). Docs in docs/ are the source of truth.
- Contract: docs/API.md, docs/DATABASE.md. UI: docs/DESIGN.md.
- Backend checks: cd backend && mvn verify
- App checks: cd app && dart format . && flutter analyze && flutter test
- No print/System.out in committed code (use a logger). Strings in app via core/constants.
- Enum values are camelCase strings identical across DB, API and Dart.
```

## Existing code from the earlier "Phase 1"

The Flutter project generated earlier contains reusable pieces: `domain/enums`, `domain/models`, `core/utils` (validators, date helpers), `core/constants`, `core/errors`, `app/theme`, `StatusChip`, tests for validators/dates. **Keep these.** `data/database/**` (Drift) and `DriftJobApplicationRepository` are obsolete — session 03 removes them. Note Phase 1 was never compiled; session 03 starts by getting it to compile.
