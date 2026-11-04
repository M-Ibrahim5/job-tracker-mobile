# JobTrail

A job-application tracker. Add the jobs you apply for, move them through a five-step pipeline
(Applied → Screening → Interview → Offer / Rejected) with a full history, schedule interviews with phone reminders,
and see everything on a dashboard and a calendar.

| | |
|---|---|
| **App** | Flutter (Android + iOS), Material 3, light/dark, Riverpod, go_router, Dio |
| **API** | Java 21 + Spring Boot 4 microservices (gateway, user-service, tracker-service), Maven, Flyway |
| **Database** | MySQL 8 (local install; Docker is never required) |
| **Reminders** | Local notifications scheduled on the phone from the server's `GET /reminders/upcoming`; works offline once scheduled |

## Architecture

```
                         HTTPS / JSON  (docs/API.md)
  ┌──────────────────────────┐        ┌───────────────────────────┐
  │  Flutter app  (app/)     │ ─────▶ │  gateway :3000 (backend/) │   routing · rate limits
  │                          │ ◀───── └──────┬─────────────┬──────┘
  │  features/ (UI+state)    │  JWT          │             │
  │  domain/   (models, repo │ access  ┌─────▼──────┐ ┌────▼────────────┐        ┌───────────┐
  │            interfaces)   │ + rot-  │ user-      │ │ tracker-service │ ─────▶ │  MySQL 8  │
  │  data/     (api | fake)  │ ating   │ service    │ │ applications ·  │ ◀───── │ (DATABASE │
  │                          │ refresh │ auth · me ·│ │ interviews ·    │        │   .md)    │
  │  local notifications ◀───┼─        │ settings   │ │ alerts · remind-│        └───────────┘
  │   (60-day reminder       │         │ :3001      │ │ ers · dashboard │
  │    schedule from API)    │         └─────▲──────┘ │ · calendar ·    │
  └──────────────────────────┘               └─ prefs ─│ export  :3002   │
                                                       └─────────────────┘
```

* The **server is the source of truth**; the app keeps no local database (only the last good data in memory, plus
  `shared_preferences` for theme / calendar format and the token store in secure storage).
* `docs/` is the contract: [`API.md`](docs/API.md) (REST), [`DATABASE.md`](docs/DATABASE.md) (schema and rules),
  [`DESIGN.md`](docs/DESIGN.md) (UI). Change the doc first if you change the contract.
* The app can run **without a server** against an in-memory fake backend (`--dart-define=USE_FAKE=true`), which is also what the tests use.

```
jobtrail/
├── app/        Flutter client           → app/README.md
├── backend/    Spring Boot microservices → backend/README.md
└── docs/       API, DATABASE, DESIGN, SQL setup, per-session briefs (docs/sessions/)
```

## Quick start

Prerequisites: Flutter 3.32+ (Dart 3.8+), JDK 21, Maven 3.6.3+, MySQL 8.

### 1. Database and API

```bash
# once: create the databases and an app user (edit the user/password in the file first)
mysql -u root -p < docs/sql/00-create-databases.sql

cd backend
cp .env.example .env              # DB_PASSWORD, JWT_SECRET, INTERNAL_API_KEY (see backend/README.md)
mvn -DskipTests package           # tables are created by Flyway on first start
java -jar seed/target/seed.jar    # optional demo data: demo@jobtrail.test / Demo@1234
./dev.sh                          # Windows: ./dev.ps1  -> http://localhost:3000/api/v1  (GET /health to check)
```

### 2. App

```bash
cd app
flutter pub get

flutter run --dart-define=USE_FAKE=true                                  # no server: demo@jobtrail.app / Password1!
./run-dev.ps1                                                            # adb reverse + flutter run → http://localhost:3000/api/v1
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1   # phone / iOS simulator on your LAN
```

## Tests

```bash
# backend (needs the local MySQL and backend/.env; uses the jobtrail_test database)
cd backend && mvn verify

# backend end-to-end against a running stack (./dev.sh in another terminal)
mvn -pl e2e test -De2e=true

# app
cd app && dart format --set-exit-if-changed . && flutter analyze && flutter test
flutter test integration_test/happy_path_test.dart -d <device>           # on an emulator / phone
```

What is covered: API integration tests (auth, isolation between users, status history, reminders, dashboard, calendar,
export), the app's unit and widget tests for every screen, a headless happy-path run
(register → application → Interview → interview → dashboard / calendar / alerts → logout), an overflow sweep of every screen at
320×568 with text ×1.5 and ×2.0 in both themes, accessibility guidelines (labels, 48dp targets, contrast), and edge cases
(600 applications, very long text, offline).

## Build and release

* **App** – icons, splash, signing and `flutter build apk | appbundle | ipa` with a production `API_BASE_URL`: see [`app/README.md`](app/README.md#release).
* **Backend** – environment, Flyway migrations, HTTPS reverse proxy, backups and the security checklist: see
  [`backend/README.md`](backend/README.md#deploying-production-notes).

## Features at a glance

Accounts (email + password, rotating refresh tokens) · applications with search, filters, sort, swipe actions and Undo-delete ·
five-status pipeline with notes and a full timeline · interviews (7 types, outcomes, conflict detection, status suggestion) ·
local reminders that survive reboots and timezone changes · alerts center with unread badge and deep links · dashboard
(summary, donut, weekly bars, upcoming, activity) · calendar (month / 2 weeks / week, markers, agenda, job timeline) ·
JSON / CSV export · light and dark themes · large-text and small-screen safe.

## Known issues

* Forgot-password is a stub (the reset link is logged, no email is sent).
* The API rate limiter is per IP and in memory (one gateway instance).
* Reminder texts of interviews are not rewritten when the company or job title is edited afterwards.
* The Android and iOS release builds, boot-time reminder persistence and exact-alarm behaviour were **not exercised on a device** in the development environment
  (no emulator or Mac was available) – run the pre-release checklist in `app/README.md` before shipping.

## Future improvements

Social login (Google / Apple) · cloud push via FCM (reminders without the phone having to schedule them) ·
resume / attachment storage per application · email-to-application parsing · home-screen widget · multi-language (l10n) ·
offline cache with sync · import from a backup file · email delivery for password reset · shared / team job boards.
