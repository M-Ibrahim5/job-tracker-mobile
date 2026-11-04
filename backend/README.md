# JobTrail API

Java 21 + Spring Boot 4 microservices on MySQL 8, built with Maven. Contract: [`docs/API.md`](../docs/API.md),
schema: [`docs/DATABASE.md`](../docs/DATABASE.md). The Flutter app talks to one URL (`http://localhost:3000/api/v1`);
the gateway fans requests out to the services.

```
                     :3000                        :3001
 Flutter app ───▶  gateway  ───────────────▶  user-service     auth · me · settings · avatars
 (docs/API.md)    routing, rate limits,  │        ▲  GET /internal/users/{id}/settings
                  health, error shape    │        │  (shared key, never routed publicly)
                                         │     :3002
                                         └──▶  tracker-service  applications · interviews · notifications ·
                                                                reminders · dashboard · calendar · export
                       both services ──▶ MySQL 8 (one schema, Flyway migrations in common/)
```

| Module | Purpose |
|---|---|
| [`common`](common) | Shared kernel: error model (`AppException` → `{error:{code,message,fields?}}`), JWT verification, `@CurrentUser`, request validation helpers, enums, reminder texts, and the Flyway migrations (`db/migration`) |
| [`user-service`](user-service) | `/auth/*`, `/me`, `/me/settings`, `/me/avatar`, static `/uploads/**`, internal settings lookup. Owns `users`, `refresh_tokens`, `user_settings` |
| [`tracker-service`](tracker-service) | Everything else. Owns `job_applications`, `status_history`, `interviews`, `notifications`. Reads reminder preferences from the user service over HTTP |
| [`gateway`](gateway) | Spring Cloud Gateway: path routing, per-IP rate limits, aggregated `GET /health`, API-shaped errors for unknown routes and outages |
| [`seed`](seed) | Dev-only demo data loader (`demo@jobtrail.test` / `Demo@1234`, 15 applications) |
| [`e2e`](e2e) | Happy-path checks against a *running* stack |

Design decisions worth knowing:

- **One database, owned tables.** Each service only touches its own tables (the tracker never reads `user_settings`; it asks the
  user service). The foreign keys to `users` stay, so deleting an account or an application cascades in the database.
  Splitting into one schema per service would mean giving up those cascades, so it is not done in v1.
- **Only the gateway is public.** `/internal/**` is guarded by `INTERNAL_API_KEY` and is not routed by the gateway, and the
  services listen on `127.0.0.1` by default (`SERVICE_BIND_ADDRESS`). User tokens are verified by each service with the shared
  `JWT_SECRET` (HS256). The gateway also checks them, but only to rate limit signed-in traffic per user instead of per IP.
- **If the user service is down** the tracker keeps working with the documented defaults (reminders on, `[1440, 60]`, follow-up
  7 days) and logs a warning; it never fails a request because of it.
- **Plain SQL (Spring `JdbcClient`), no ORM.** The queries are reporting-heavy (pipeline-order sort, `nextInterviewAt`
  subquery, weekly buckets), and every row has to be scoped by `user_id`; explicit SQL keeps both visible.
- **Flyway** applies `common/src/main/resources/db/migration` when a service starts (locked, so concurrent starts are safe).
  A database created earlier by Prisma is adopted as version 1 (`baseline-on-migrate`).

## Run locally

Requires **JDK 21**, **Maven 3.6.3+** and a local **MySQL 8** server (no Docker).

1. Edit the user name/password in [`docs/sql/00-create-databases.sql`](../docs/sql/00-create-databases.sql), then run it once as a
   MySQL admin (creates `jobtrail`, `jobtrail_test` and an app user):
   ```bash
   mysql -u root -p < ../docs/sql/00-create-databases.sql
   ```
2. Configure, build, seed and start:
   ```bash
   cd backend
   cp .env.example .env          # set DB_PASSWORD and generate JWT_SECRET + INTERNAL_API_KEY; plain KEY=value, no quotes
   mvn -DskipTests package       # builds the four jars and the seed; Flyway runs on first start
   java -jar seed/target/seed.jar          # optional demo data: demo@jobtrail.test / Demo@1234
   ./dev.sh                      # Windows: ./dev.ps1   -> http://localhost:3000/api/v1/health
   ```
   `dev.sh` / `dev.ps1` rebuild and start gateway (:3000), user-service (:3001) and tracker-service (:3002); Ctrl+C stops them.
   To run one service on its own: `java -jar user-service/target/user-service.jar` (all read `backend/.env`; real environment
   variables override it).

Configuration lives in [`.env.example`](.env.example). `INTERNAL_API_KEY` and `JWT_SECRET` must be identical for the user and
tracker services (and the gateway gets the same `JWT_SECRET`). The services refuse to start without them, or with the example
values from `.env.example` (generate your own with `openssl rand -base64 48`).

## Commands

| Command | What it does |
|---|---|
| `mvn -DskipTests package` | Build `gateway.jar`, `user-service.jar`, `tracker-service.jar`, `seed.jar` (executable, in each `target/`) |
| `mvn verify` | Compile and run every test (needs MySQL, see below). **This is the backend check** |
| `mvn -pl tracker-service -am test` | Tests of one module (`-am` also builds `common`) |
| `java -jar seed/target/seed.jar` | Demo user + 15 applications (re-running replaces the demo data; dev only) |
| `mvn -pl e2e test -De2e=true` | End-to-end happy path against a **running** stack (`-Dbase.url=http://host:3000/api/v1`) |

Tests use `TEST_DB_URL` / `TEST_DB_USER` / `TEST_DB_PASSWORD` from `.env` (default `jobtrail_test` on localhost). They wipe that
database and apply the Flyway migrations to it automatically. The e2e test creates and deletes its own accounts; the gateway
allows 10 `/auth` requests per minute per IP, so start the gateway with `AUTH_RATE_LIMIT=1000` if you run it repeatedly.

## Example: register → login → GET /me

```bash
B=http://localhost:3000/api/v1

curl -s -X POST $B/auth/register -H 'Content-Type: application/json' \
  -d '{"fullName":"Muhammad Ibrahim","email":"ibrahim@example.com","password":"Passw0rd!"}'

curl -s -X POST $B/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"ibrahim@example.com","password":"Passw0rd!"}'
# => {"accessToken":"...","refreshToken":"...","user":{...}}

curl -s $B/me -H "Authorization: Bearer <accessToken>"
```

## Endpoints

All paths are under `/api/v1`; everything except `/health` and `/auth/*` (except `change-password`) needs
`Authorization: Bearer <accessToken>`. Full contract: [`docs/API.md`](../docs/API.md). A ready-to-run request per endpoint is in
[`requests.http`](requests.http) (VS Code REST Client / JetBrains HTTP Client).

| Method | Path | Service | Notes |
|---|---|---|---|
| GET | `/health` | gateway | `{status, version, services}`; 503 `degraded` when a service is down |
| POST | `/auth/register` `/auth/login` `/auth/forgot-password` `/auth/change-password` | user | strict per-IP limit; wrong passwords also lock the account briefly |
| POST | `/auth/refresh` `/auth/device-login` `/auth/logout` | user | token endpoints: higher per-IP limit |
| GET / PATCH / DELETE | `/me` | user | profile; DELETE needs `{password}` |
| POST | `/me/avatar` | user | multipart `file` (jpeg/png, 2 MB) |
| GET / PATCH | `/me/settings` | user | |
| GET / POST | `/applications` | tracker | list filters: `q`, `status`, `arrangement`, `from`, `to`, `sort`, `page`, `pageSize` |
| GET / PATCH / DELETE | `/applications/{id}` | tracker | PATCH ignores `status` |
| POST | `/applications/{id}/status` | tracker | `{status, note?}`; no-op if unchanged |
| GET | `/applications/{id}/history` `/applications/{id}/timeline` | tracker | |
| POST | `/applications/{id}/interviews` | tracker | 409 `INTERVIEW_CONFLICT` on the same slot |
| GET | `/interviews` | tracker | `scope=upcoming\|past`, `applicationId`, `from`, `to`, paging |
| GET / PATCH / DELETE | `/interviews/{id}` | tracker | |
| GET | `/notifications` `/notifications/unread-count` | tracker | only rows with `visible_at <= now` |
| POST | `/notifications/{id}/read` `/notifications/read-all` | tracker | |
| DELETE | `/notifications/{id}` `/notifications` | tracker | clear-all keeps reminders that have not fired yet |
| GET | `/reminders/upcoming` | tracker | next 60 days; honours `X-Timezone` |
| GET | `/dashboard?tz=` | tracker | |
| GET | `/calendar?from&to&tz` | tracker | range <= 70 days |
| GET | `/export?format=json\|csv` | tracker | streamed attachment |
| DELETE | `/data` | tracker | body `{"confirm":"DELETE"}`; keeps the account |
| GET | `/uploads/avatars/{file}` | user | public, unguessable file names; served from the database |

Notes:
- Another user's ids always return `404 NOT_FOUND` (never 403); ids that are not positive integers are 404 as well.
- `X-Timezone: <IANA name>` formats times inside reminder titles/bodies (UTC if omitted).
- Creating an application without `followUpAt` uses the user's default follow-up days (`appliedDate + N days, 09:00 UTC`);
  send `followUpAt: null` to opt out.
- Only *pending* interviews produce reminders and count towards `nextInterviewAt` / the dashboard's upcoming list.
- Dashboard weekly buckets group `applied_date` by Monday in SQL; `tz` only decides which week is "current".
- `q` search matches title, company and location case-insensitively; `%` and `_` are literal characters.
- Query performance: the test suite lists 1,000 applications (`pageSize=50`, filter + pipeline sort) in well under 200 ms and
  asserts via `EXPLAIN` that the `user_id + status/applied_date` filter uses an `idx_app_user_*` index.

## Conventions

- Packages: `com.jobtrail.common`, `.user`, `.tracker`, `.gateway`, `.seed`. Controllers parse and validate bodies with
  `JsonBody` / `QueryParams` (field-level messages exactly as in the Node version), services hold the rules, `*Repository`
  classes hold SQL.
- Enum constants are camelCase on purpose (`fullTime`, `linkedIn`, `finalRound`): the same strings are stored in MySQL ENUM
  columns, sent over the API and used by the Dart enums.
- Timestamps are `Instant`s, stored as UTC `DATETIME(3)` and sent as `2026-10-27T02:00:00.000Z`. The connection pool sets
  `time_zone = '+00:00'` so database defaults are UTC too.
- No `System.out` / `printStackTrace`: use SLF4J. Never edit an applied Flyway migration; add `V2__...sql`.
- Forgot-password is a stub: only the request is logged, nothing is emailed and no reset token is created.

## Security checklist

| Area | State |
|---|---|
| Ownership | Every application / interview / notification query is scoped by `user_id`; foreign ids → 404, never 403. Covered by isolation tests and the e2e test. |
| Passwords | argon2id, OWASP baseline for new hashes (19 MiB, 2 passes, 1 lane). Hashes keep their own parameters, so hashes written by the old Node API (64 MiB, t=3, p=4) still verify. At most one hash per CPU core runs at once (`ARGON2_MAX_CONCURRENT`); callers that wait over 5 s get 503 `SERVER_BUSY`, so a login burst cannot exhaust memory. Login hashes a dummy value for unknown emails and returns the same `INVALID_CREDENTIALS`. |
| Password guessing | Per account (`login_throttle`, also for unknown e-mails): after 5 wrong passwords in 15 min the account is locked for 1 min, doubling up to 15 min; a correct password clears it. Applies to login, change-password, device enrolment and account deletion. |
| Tokens | Access JWT (HS256) 15 min, signed with `JWT_SECRET` (env only; ≥ 32 chars, and with the `prod` profile no placeholder words). Refresh tokens are random 48 bytes, stored only as SHA-256, rotated on use. Reuse of a revoked token revokes all of the user's tokens, except a retry within 30 s of a rotation whose replacement was never used (a lost response): that gets a fresh pair and the unused replacement is retired. |
| Service-to-service | `/internal/**` needs `X-Internal-Key` (≥ 16 chars, compared in constant time), is not routed by the gateway, and the services refuse to start without a key. |
| Rate limits | Gateway: everything under `/api/v1` 300/min **per user** when a valid token is sent, otherwise per IP; password endpoints 10/min/IP; refresh, device login and logout 120/min/IP (`TOKEN_RATE_LIMIT`). Counted in Redis when `REDIS_URL` is set, so several gateways share one budget; in memory otherwise, and also as the fallback while Redis is unreachable (a Redis outage never blocks traffic). `/health` is unlimited but its probe result is shared and cached for 3 s. `TRUST_FORWARDED_FOR=true` only behind a proxy you control. |
| Headers / CORS | No CORS configuration (the mobile app needs none; browsers are blocked cross-origin). Every service response has `X-Content-Type-Options: nosniff`. Put TLS and other security headers on the reverse proxy. |
| Input | Every body and query parameter is validated field by field; SQL only with bound parameters (column names in dynamic `UPDATE`s come from code, never from requests). Request bodies must be JSON objects of at most 1 MB (`MAX_BODY_SIZE`): the gateway refuses larger ones with 413 by `Content-Length`, and the services stop reading streamed bodies past the limit. `page` is capped at 10,000. |
| Uploads | Avatar only: jpeg/png ≤ 2 MB, magic bytes checked (not just the declared type), random file names. The server decodes the image and stores a fresh copy of at most 512 px in the database (`user_avatars`, so every user-service instance can serve it), so metadata (EXIF/GPS) and appended data are dropped. Avatars uploaded before V4 are still served from `UPLOAD_DIR`. |
| Errors | Typed `AppException` → `{ error: { code, message, fields? } }`; anything else is logged and returned as a generic 500 (no stack traces). |
| Secrets | `.env` is git-ignored (`*.env` in `.gitignore`); `.env.example` only has placeholders, and the services refuse to start with them in any profile. With the `prod` profile they also refuse placeholder words, a non-https `PUBLIC_BASE_URL` and an unencrypted connection to a remote database. |
| Cleanup | Nightly jobs (03:30 UTC) delete expired refresh tokens, expired or long-revoked device tokens, old login-throttle rows, and read notifications older than `NOTIFICATION_RETENTION_DAYS` (365). Revoked refresh tokens are kept until they expire, because reuse detection needs them; unread notifications are never deleted. |
| Dependencies | Spring Boot 4.1 / Spring Framework 7 / Spring Cloud 2025.1, Jackson 3. Checked against OSV.dev on 3 Nov 2026: no known vulnerabilities in the runtime dependencies. Re-check before each release. |

Known limits: forgot-password is a stub; registration reveals whether an e-mail is registered (rate limited; see the report);
interview reminder bodies are not rewritten when the company or job title changes afterwards.
See [`docs/SECURITY-AND-LOAD-REPORT.md`](../docs/SECURITY-AND-LOAD-REPORT.md) for the load test and the remaining items.

## Deploying (production notes)

Docker is **optional** and only for deployment – nothing in local development needs it.

1. **Servers**: JDK 21, MySQL 8 (managed or self-hosted) and, when running more than one gateway, Redis 7 for shared rate
   limits. Avatars live in the database; `UPLOAD_DIR` only matters for avatars uploaded before V4. The three jars can run on one host or separately (set `USER_SERVICE_URL` / `TRACKER_SERVICE_URL`
   for the gateway and `USER_SERVICE_URL` for the tracker).
2. **Environment** (never commit; set in the process manager / secret store). Start every service with
   `SPRING_PROFILES_ACTIVE=prod` so placeholder secrets and non-https `PUBLIC_BASE_URL` are refused.

   | Variable | Production value |
   |---|---|
   | `DB_URL` / `DB_USER` / `DB_PASSWORD` | `jdbc:mysql://HOST:3306/jobtrail?sslMode=REQUIRED` and a least-privilege user |
   | `JWT_SECRET` | 48+ random bytes, e.g. `openssl rand -base64 48` (same for user + tracker) |
   | `INTERNAL_API_KEY` | 32+ random characters (same for user + tracker) |
   | `JWT_ACCESS_TTL` / `REFRESH_TTL_DAYS` | `15m` / `30` |
   | `PORT` / `USER_SERVICE_PORT` / `TRACKER_SERVICE_PORT` | `3000` (public, behind the proxy) / `3001` / `3002` (private network only) |
   | `SERVICE_BIND_ADDRESS` | `127.0.0.1` (default) when all three run on one host; otherwise the private-network address of that host |
   | `API_RATE_LIMIT` / `AUTH_RATE_LIMIT` / `TOKEN_RATE_LIMIT` | `300` / `10` / `120` per minute |
   | `MAX_BODY_SIZE` | `1MB` (largest JSON body; gateway and services) |
   | `ARGON2_MAX_CONCURRENT` | `0` = one hash per CPU core; give user-service at least that many × 19 MiB of heap headroom |
   | `REDIS_URL` | `redis://:PASSWORD@HOST:6379/0` (or `rediss://` for TLS) when several gateways run; empty = per-process limits |
   | `NOTIFICATION_RETENTION_DAYS` | `365` (read notifications older than this are deleted nightly) |
   | JVM | `java -Xmx512m -jar ...` per service in a 1 GB container was load-tested on Linux (2 CPUs each): 1,100 reads/s at p95 460 ms, and 128 parallel logins stayed under 400 MB |
   | `USER_SERVICE_URL` / `TRACKER_SERVICE_URL` | where the gateway and tracker reach the services |
   | `UPLOAD_DIR` | absolute path, backed up |
   | `PUBLIC_BASE_URL` | public **https** origin, used to build avatar URLs |
   | `LOG_LEVEL` | `info` |

3. **Build and migrate**: `mvn -DskipTests package`, copy the three jars, start them under a supervisor (systemd, a container
   orchestrator) with restart-on-failure. Flyway migrates automatically when the first service starts (the migration is
   locked, so starting all of them at once is safe). Never run the seed jar in production: it creates a demo account.
4. **HTTPS**: terminate TLS at a reverse proxy (nginx, Caddy, a cloud load balancer) in front of the gateway only; keep
   :3001 and :3002 on a private network. Release builds of the app refuse cleartext HTTP on Android and iOS, so TLS is required.
5. **Backups**: schedule `mysqldump --single-transaction --routines jobtrail | gzip > jobtrail-$(date +%F).sql.gz` daily
   (keep ≥ 7 days, test a restore); avatars are in the database dump. Back up `UPLOAD_DIR` only if it holds pre-V4 avatars. Managed MySQL point-in-time recovery is even better.
6. **Smoke test** after each deploy: `curl https://api.example.com/api/v1/health` (must say `"status":"ok"`, all services `up`)
   and `mvn -pl e2e test -De2e=true -Dbase.url=https://api.example.com/api/v1` (creates and deletes its own accounts).

## Troubleshooting

- `UnsupportedClassVersionError ... class file version 65.0`: `java` on the PATH is older than 21. Point `JAVA_HOME` / `PATH` at
  a JDK 21.
- `PKIX path building failed` while Maven downloads dependencies (corporate proxy or antivirus re-signing HTTPS): trust the
  Windows certificate store for Maven only, e.g. `set MAVEN_OPTS=-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT`.
- `jobtrail.jwt.secret ... must be set` / `jobtrail.internal.key ... must be set`: fill `JWT_SECRET` and `INTERNAL_API_KEY` in
  `backend/.env` (no quotes).
- `JWT_SECRET is the public example value`: you copied `.env.example` unchanged; generate both secrets
  (`openssl rand -base64 48`).
- A script or another machine cannot reach :3001 / :3002: the services listen on `127.0.0.1` only. Go through the gateway on
  :3000, or set `SERVICE_BIND_ADDRESS` (private network only).
- Tracker responses ignore a user's settings and the log says "Could not load settings ... using defaults": the user service
  is not running or `INTERNAL_API_KEY` differs between the two services.
- `Access denied for user`: `DB_USER` / `DB_PASSWORD` in `.env`; the Node-era `DATABASE_URL` is no longer read.
