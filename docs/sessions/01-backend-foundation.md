# Session 01 — Backend Foundation

**Read first:** `docs/00-README.md`, `docs/DATABASE.md`, `docs/API.md` (Auth, Me, Settings, Misc sections).
**Owns:** everything under `backend/` except `tracker-service` (session 02). Do not touch `app/`.

## Goal
A running **Java 21 / Spring Boot 3 / Maven** stack connected to MySQL with the full schema, an API gateway, and the **user-service** (authentication, profile, settings). The Flutter app keeps talking to one base URL, `http://localhost:3000/api/v1`; the gateway routes to the services.

## Tasks

1. **Project setup** in `backend/` (Maven multi-module, parent `spring-boot-starter-parent` 3.3.x, `java.version` 21)
   - Modules: `common` (shared kernel), `user-service` (:3001), `gateway` (:3000), `seed` (dev data loader), `e2e` (session 02 fills it); `tracker-service` (:3002) is created in session 02.
   - Libraries: Spring Web, Spring JDBC (`JdbcClient`, plain SQL, no ORM), Flyway (+ `flyway-mysql`), MySQL Connector/J, jjwt 0.12 (HS256), Spring Security Crypto + BouncyCastle (argon2id, no Spring Security filter chain), Spring Cloud Gateway (gateway only), JUnit 5 / MockMvc / WebTestClient.
   - Layout per service: `config`, `<feature>/{Controller,Service,Repository,Dto}`; packages `com.jobtrail.{common,user,tracker,gateway,seed}`. Executable jars `target/<module>.jar`.
   - `dev.sh` / `dev.ps1` build and start the three services; each service reads `backend/.env` (`spring.config.import` of `.env`), real environment variables override it.
2. **Local MySQL (no Docker)**: use the developer's installed MySQL 8. Provide `docs/sql/00-create-databases.sql` that creates `jobtrail` and `jobtrail_test` (utf8mb4) and an app user with privileges on both; document running it with the `mysql` CLI. `.env.example` with `DB_URL`, `DB_USER`, `DB_PASSWORD`, `TEST_DB_*`, `JWT_SECRET` (≥ 32 chars), `INTERNAL_API_KEY`, `JWT_ACCESS_TTL=15m`, `REFRESH_TTL_DAYS=30`, `PORT=3000`, service ports/URLs, `UPLOAD_DIR`, `PUBLIC_BASE_URL`.
3. **Schema**: `common/src/main/resources/db/migration/V1__init.sql` = every table in `DATABASE.md` (exact enums, indexes, cascade FKs, `DATETIME(3)`, `DATE` for `applied_date`). Every service runs Flyway on start (locked, idempotent); `baseline-on-migrate` at version 1 adopts databases created earlier by the Prisma-based Node version. The pool runs `SET time_zone = '+00:00'` so column defaults are UTC. `DATETIME(3)` values are bound/read as `LocalDateTime` (UTC) and exposed as `Instant`.
4. **Cross-cutting (`common`)**
   - `AppException(code, status, message, fields?)` + `@RestControllerAdvice` producing the `API.md` error shape for every failure (malformed JSON, bad params, unknown routes, upload too large, anything else → generic 500).
   - `JsonBody` / `QueryParams` / `Validator`: field-level validation with the documented messages; PATCH can tell "omitted" from "null"; strings trimmed, `""` → null for optional text.
   - `JwtAuthInterceptor` (Bearer JWT; expired → 401 with `code: "TOKEN_EXPIRED"`, other failures `UNAUTHORIZED`) + `@CurrentUser long userId`; `InternalKeyInterceptor` for `/internal/**` (`X-Internal-Key`, constant-time compare, services refuse to start without a key).
   - JSON: camelCase, `Instant` as `2026-10-27T02:00:00.000Z`, ids as numbers.
   - `ProductionGuard` (profile `prod`): refuses placeholder secrets and a non-https `PUBLIC_BASE_URL`.
5. **Auth** per `API.md` (user-service): register (creates default `user_settings`: offsets `[1440,60]`, follow-up 7 days), login, refresh (rotation + reuse detection: a revoked token being reused revokes all of the user's tokens), logout, forgot-password (stub: log reset link), change-password. Email stored lowercased/trimmed; `EMAIL_TAKEN` 409; `INVALID_CREDENTIALS` 401 without revealing which part was wrong (dummy hash for unknown emails). Password hashing argon2id (64 MiB, t=3, p=4) in the standard encoded format.
6. **Me**: GET/PATCH `/me` (email not editable), POST `/me/avatar` (jpeg/png ≤ 2 MB, magic bytes checked, saved under `UPLOAD_DIR/avatars`, served at `/uploads/...`, absolute `avatarUrl`), DELETE `/me` (requires password; FK cascades remove all data), GET/PATCH `/me/settings` (`defaultFollowUpDays ∈ {null,3,5,7,14}`, offsets are positive ints ≤ 43200, 0–5 items).
7. **Internal API**: `GET /internal/users/{id}/settings` (same JSON as `/me/settings`), used by the tracker service; never routed by the gateway.
8. **Gateway**: Spring Cloud Gateway routes (`/auth`, `/me`, `/uploads` → user-service; applications, interviews, notifications, reminders, dashboard, calendar, export, data → tracker-service), per-IP fixed-window rate limits (`/auth/*` 10/min, all of `/api/v1` 300/min, `Retry-After` on 429, `/health` exempt), aggregated `GET /api/v1/health` (`{status, version, services}`; 503 `degraded` when a service is down), API-shaped errors for unknown routes (404) and unreachable services (503 `INTERNAL`).
9. **Seed**: `seed` module (`java -jar seed/target/seed.jar`, dev only): one demo user `demo@jobtrail.test` / `Demo@1234`. (Applications seed comes in session 02.)

## Definition of Done
- With local MySQL running and `backend/.env` filled in, `mvn -DskipTests package` and `./dev.sh` (`dev.ps1` on Windows) work from a clean clone; `backend/README.md` explains it.
- Integration tests (JUnit 5 + MockMvc against `jobtrail_test`) cover: register/login happy path, duplicate email, wrong password, refresh rotation + reuse detection, change password, `/me` GET/PATCH (email not editable), avatar upload, settings validation, auth required (401), expired token (`TOKEN_EXPIRED`), forged token, internal-key guard, error shape. Gateway tests cover routing, header/query forwarding, `/internal` not exposed, unknown route shape, rate limits, health, and a dead downstream service.
- `mvn verify` passes. No `System.out` / `printStackTrace`.
- `curl` examples for register → login → GET /me in `backend/README.md`.

## Handoff notes
**Done:** the Node/TypeScript implementation was replaced by Spring Boot microservices (this and session 02 were migrated together). `common` (errors, validation, JWT, Flyway `V1__init.sql`), `user-service` (auth, `/me`, avatar, settings, internal settings), `gateway` (routing, rate limits, health, error shape), `seed` (demo user + 15 applications), `dev.sh`/`dev.ps1`, `backend/README.md`. Tests: 26 in `user-service`, 12 in `gateway` (plus 54 in `tracker-service`, session 02) — 92 in total, all passing with `mvn verify` against a local MySQL 8.0.36; `mvn -pl e2e test -De2e=true` also passes against a live stack.

**Deviations / decisions**
- **Microservices over a single schema**: one MySQL schema, tables owned per service (`docs/DATABASE.md`), foreign keys and cascades kept. The tracker asks the user service for reminder preferences over `/internal`; if it cannot, it logs a warning and uses the documented defaults.
- **Plain SQL with `JdbcClient`, no ORM**, and a small hand-written validation layer (`JsonBody`/`QueryParams`) instead of Bean Validation, to keep the Zod-era messages and PATCH semantics (`omitted` ≠ `null`) identical.
- Only pending interviews remind (previous: only `cancelled` was excluded in the sync step) — the documented behaviour in `API.md`.
- Env names changed: `DATABASE_URL` → `DB_URL` (JDBC) + `DB_USER` + `DB_PASSWORD`; `TEST_DATABASE_URL` → `TEST_DB_*`; new `INTERNAL_API_KEY`. `JWT_SECRET`, `JWT_ACCESS_TTL`, `REFRESH_TTL_DAYS`, `PORT` (now the gateway), `UPLOAD_DIR`, `PUBLIC_BASE_URL` are unchanged. The local `backend/.env` was converted (original kept as git-ignored `old-node.env`; delete it once you no longer need it).
- Compatible with existing data: Flyway baselines a database created by Prisma, and argon2id hashes written by other implementations verify in Java (`PasswordCompatibilityTest` checks a hash from the reference implementation with the Node parameters, so existing accounts keep working).
- Prisma-era limits no longer apply (shadow database privileges, `@map` workarounds).

**Verification note:** run against a throw-away MySQL 8.0.36 on another port because the system `MySQL80` service could not be started without admin rights; Maven needed `-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT` here (PKIX error, see `backend/README.md` → Troubleshooting). The default `java` on this machine is JDK 19; builds and runs used JDK 21.

**Open issues:** the gateway's rate limiter is per IP and in memory; JWT secret rotation is not supported (a new secret logs everyone out).
