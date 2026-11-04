# JobTrail: load and security review

Date: 2 Nov 2026; fixes applied 2–3 Nov 2026 (see [Fixes applied](#fixes-applied)). Scope: `backend/` (gateway, user-service, tracker-service, common) and the security-relevant parts of `app/` (token handling, networking, Android build). Method: code review plus a local load test of the real services.

## Summary

The code is careful in most places that matter for security. SQL is parameterised, every query is scoped to the signed-in user, passwords use Argon2id, refresh tokens are hashed and rotated with reuse detection, and secrets stay out of git. I found no injection, no cross-user data access and no authentication bypass.

The weak points are capacity and abuse resistance. Under concurrent use, three problems stand out:

1. **Login is the bottleneck and the main memory risk.** Each login costs about 400 ms of CPU and 64 MiB of RAM, and nothing caps how many run at once. With 64 logins in parallel, user-service grew to **4.3 GB**, and the median login took **6 s**. On a 2–4 GB server, a login wave or a credential-stuffing attack would crash it.
2. **Per-IP rate limits log real users out.** `/auth/refresh` shares the 10 requests/min/IP auth limit with login. The app treats a 429 on refresh as an invalid session and signs the user out. Users behind one IP (mobile carrier NAT, an office, a campus) will be logged out in batches.
3. **Request bodies have no size limit.** A 150 MB JSON body was accepted and fully parsed (tracker heap +250 MB) before validation rejected it. A few parallel requests like that can exhaust memory.

Ordinary reads and writes scale reasonably. On one laptop running everything (3 JVMs, MySQL and the load generator on 12 cores), the gateway served about **300 authenticated reads/s at p95 276 ms** and **112 writes/s at p95 445 ms**, with no errors.

**Can it handle thousands of users?** Thousands of *registered* users, yes: the data model and indexes are fine for that. Thousands of *concurrent* users, not as configured. Fix findings L1–L4 first, then plan to run more than one instance of each service (see L5).

## How the load test was run

- Real jars from `mvn package`, a throwaway MySQL 8.0.36 on port 3307, and default service settings (Tomcat 200 threads, HikariCP 10 connections per service).
- All traffic came from 127.0.0.1, so per-IP limits apply to the whole test. Capacity runs raised `API_RATE_LIMIT` and `AUTH_RATE_LIMIT` to 10,000,000 to measure the services rather than the limiter.
- Each client thread keeps one keep-alive connection. Connections ramped up at 50 ms each. Bursts of more than about 20 *simultaneous new* connections stalled for 20–100 s on this Windows 11 machine, both directly against Tomcat and through the gateway. I treat that as a property of the test host's TCP stack, not of the app, and excluded it. It should be re-checked on Linux.
- The load generator used only the Python standard library (`loadtest.py`). It is not committed.

| Scenario | Concurrency | Throughput | p50 | p95 | p99 | Errors |
|---|---|---|---|---|---|---|
| Read mix via gateway (dashboard, list, calendar, notifications) | 10 | 162 req/s | 57 ms | 102 ms | 141 ms | 0 |
| Read mix via gateway | 50 | 297 req/s | 149 ms | 276 ms | 379 ms | 0 |
| Create application via gateway | 25 | 112 req/s | 176 ms | 445 ms | 817 ms | 0 |
| Login (Argon2id) | 4 | 9.8 logins/s | 400 ms | 471 ms | 615 ms | 0 |
| Login | 16 | 13.4 logins/s | 1.1 s | 1.5 s | 1.6 s | 0 |
| Login | 64 | 10.4 logins/s | 6.1 s | 8.3 s | 9.4 s | 0 (user-service at 4.3 GB) |
| `GET /health` direct to tracker | 50 | 720 req/s | 57 ms | 115 ms | 148 ms | 0 |
| `GET /health` via gateway | 50 | 1.5 req/s | — | — | — | 37 × 503, 12 timeouts |
| Read mix, **default limits** (300/min/IP) | 20 | 300 OK, then 429 | 67 ms | 126 ms | — | 426 × 429 (as designed) |
| Login, **default limits** (10/min/IP) | 5 | 0 OK in 10 s | — | — | — | 3,637 × 429 (window already used) |

## Findings

Severity is my assessment for a public deployment. "Load" findings affect availability under stress. "Security" findings can be abused.

| ID | Severity | Area | Finding | Status |
|---|---|---|---|---|
| L1 | High | Load | Argon2 has no concurrency cap: each hash takes 64 MiB, and 64 parallel logins took the process to 4.3 GB | **Fixed** |
| L2 | High | Load / UX | A 429 on `/auth/refresh` signs the user out, and refresh shares the 10/min/IP auth limit | **Fixed** |
| L3 | Medium | Load / DoS | No request body size limit; a 150 MB JSON body is fully parsed | **Fixed** |
| L4 | Medium | Load / DoS | `GET /health` is public, unlimited and calls both services on every request | **Fixed** |
| L5 | Medium | Scale-out | Rate limits are in memory per gateway instance and keyed by IP only | **Fixed** (per user, shared through Redis; avatars in the database) |
| L6 | Low | Load | Token and notification tables are never purged | **Fixed** |
| L7 | Low | Robustness | `page=2147483647` overflows the offset and returns 500 | **Fixed** |
| L8 | High | Load | Gateway reused pooled connections that Tomcat was closing: 500s and hangs of 60 s or more at 50 connections | **Fixed** (found while verifying) |
| S1 | High (deployment-dependent) | Security | user-service and tracker-service listen on every interface, so callers can bypass the gateway and its rate limits | **Fixed** |
| S2 | Medium | Security | Password guessing is limited only per IP; there is no per-account throttle or lockout | **Fixed** |
| S3 | Medium | Security / robustness | Access tokens stay valid for 15 min after account deletion; writes with them return 500 | **Fixed** (now 401) |
| S4 | Low | Privacy | Avatars are stored and served as uploaded, including EXIF data such as GPS, without `nosniff` | **Fixed** |
| S5 | Low | Security | `ProductionGuard` only runs with the `prod` profile; without it, placeholder secrets are accepted | **Fixed** |
| S6 | Low | Security | Registration reveals whether an e-mail is registered (`EMAIL_TAKEN`) | **Accepted risk** (decision of 4 Nov 2026) |
| S7 | Low | Security | The DB connection defaults to `useSSL=false&allowPublicKeyRetrieval=true` | **Fixed** for production |
| S8 | Low | Client | Release builds fall back to debug signing, and an `http://` API URL is not rejected at build time | **Fixed** |
| S9 | Info | Security | Refresh-token reuse detection logs out every device if one refresh response is lost | **Fixed** (30 s retry grace) |
| D1 | High | Dependencies | Spring Boot 3.3.5 / Spring Framework 6.2: 30+ known advisories (Tomcat, Netty, Jackson, Spring; several critical) | **Fixed** (Spring Boot 4.1.2; 0 known) |
| S10 | Info | Feature gap | Forgot-password is a stub that writes a link with an unusable token to the log | **Fixed** (log line); feature still missing |

What changed for each item is in [Fixes applied](#fixes-applied) at the end. The analysis below describes the code as it was during the review.

### L1 — Argon2 has no concurrency cap (High)

`UserConfig.passwordEncoder()` uses Argon2id with `memoryKb=65536`, `iterations=3` and `parallelism=4`. The encoder runs on login, registration, password change, device-token creation and account deletion. Nothing limits how many hashes run at once: up to Tomcat's 200 request threads can each allocate 64 MiB.

Evidence: at 64 concurrent logins, user-service's working set reached **4,298 MB**, and throughput fell from about 13 to 10 logins/s as requests queued. In theory, 200 concurrent logins need about 12.5 GB.

Fix:
- Put a `Semaphore` around `encoder.matches`/`encode`, sized to about the CPU core count. Return 429 or 503 when no permit frees up within a second or two, so excess logins fail fast instead of piling up.
- Consider OWASP's lighter Argon2id setting (19 MiB, t=2, p=1). It cuts memory per hash by 70% with acceptable strength, and existing hashes still verify because the parameters are stored in each hash.
- Set an explicit `-Xmx` and container memory limit for user-service, sized as permits × hash memory plus headroom.

### L2 — A 429 on refresh signs the user out (High)

`RateLimitFilter` applies the auth limit (10/min/IP) to everything under `/api/v1/auth/`, including `/auth/refresh` and `/auth/device-login`. Access tokens last 15 minutes, so every active user refreshes about 4 times an hour. In the app, `AuthInterceptor._doRefresh()` (`app/lib/data/api/auth_interceptor.dart:126-127`) returns `null` for *any* 4xx, and that ends the session.

Result: once more than about 10 users behind one public IP refresh in the same minute, the rest get 429 and are signed out. Shared IPs are common: carrier-grade NAT, office Wi-Fi, universities. The general 300/min/IP limit also means that 50 users on one IP share about 6 requests per minute each.

Fix:
- **App:** treat 429 (and 5xx) on refresh as transient. Keep the tokens, honour `Retry-After` and retry. Only 401 means the refresh token is gone.
- **Gateway:** give `/auth/refresh` its own, much higher limit, or exempt it. It requires a 48-byte random secret and cannot be brute-forced. Keep the strict limit for `/auth/login`, `/auth/register` and `/auth/forgot-password`.
- **Gateway:** key the general API limit by user (the JWT `sub`) when a valid token is present, and fall back to IP otherwise.

### L3 — No request body size limit (Medium)

Neither the gateway nor Tomcat limits JSON body size. Only multipart uploads are capped, at 2–3 MB. Field limits in `JsonBody` apply only after Jackson has read the whole body into a `JsonNode`. Jackson's default 20 MB per-string limit rejects one giant string, but not many 1 MB strings.

Evidence: a 150 MB body of 150 × 1 MB strings was parsed, then rejected with 400 after 1.2 s. Tracker memory went from 291 MB to 540 MB.

Fix: add Spring Cloud Gateway's `RequestSize` filter as a `default-filter` (for example 1 MB, or 3 MB for `/api/v1/me/avatar`), and reject on `Content-Length` before proxying. As defence in depth, add a servlet filter in the services that rejects bodies over 1 MB.

### L4 — `/health` amplifies load (Medium)

`HealthController` is exempt from rate limiting, needs no authentication, and makes two outbound HTTP calls per request with a 2 s timeout each. At 50 concurrent clients through the gateway it returned 37 × 503 and 12 timeouts. The same endpoint called directly on tracker-service handled 720 req/s. A health-check storm, or an attacker, can therefore make the gateway report the system as down and tie up its outbound connection pool.

Fix: cache the combined result for 2–5 s and share one in-flight probe. Keep a cheap liveness endpoint that touches nothing, and only expose the deep check to the load balancer or internally.

### L5 — Rate limits are per instance and IP-only (Medium)

`FixedWindowLimiter` is an in-memory map. With N gateway instances behind a load balancer, the effective limit becomes N × the limit, and counters reset when an instance restarts. Fixed windows also allow 2× the limit across a window boundary.

Fix for scale-out: use Spring Cloud Gateway's `RequestRateLimiter` with Redis (a token bucket shared by all instances). User-service and tracker-service are stateless, apart from avatar files on local disk (see the note below), so they can run multiple instances once the limiter is shared.

Other scale-out notes:
- Avatars are written to the local `UPLOAD_DIR`, so a second user-service instance will not see them. Use shared storage or object storage.
- Each service uses HikariCP's default pool of 10 connections against one MySQL. That was enough in this test. Size pools so that instances × pool size stays under MySQL's `max_connections` (default 151).

### L6 — Tables grow without limit (Low)

Nothing deletes old rows. There is no `@Scheduled` job.
- `refresh_tokens`: every refresh inserts a row and marks the old one revoked. That is about 96 rows per user per active day, or about 35 million rows a year for 1,000 daily users.
- `device_tokens` keeps revoked and expired rows, and fired `notifications` are kept forever.

Lookups use unique or indexed columns, so this is a storage and backup problem first, a speed problem later. Fix: a nightly job that deletes refresh and device tokens that expired or were revoked more than about 30 days ago.

### L7 — Page offset overflow (Low)

`QueryParams.page()` accepts values up to `Integer.MAX_VALUE`, and `PageResponse.offset()` computes `(page - 1) * pageSize` as an `int`. `GET /applications?page=2147483647&pageSize=100` overflows to a negative OFFSET, and MySQL returns an error (reproduced: **500**). Fix: cap `page` (for example at 10,000) or compute the offset as a `long` clamped to a sane maximum.

### L8 — Gateway reused connections Tomcat was closing (High, found while verifying the fixes)

At 50 concurrent connections through the gateway, 19 requests failed with 500. The gateway log showed *"Connection prematurely closed BEFORE response"*. Other requests hung for 60–110 s.

Two settings caused this:
- Tomcat closes a keep-alive connection after 100 requests (`max-keep-alive-requests`), while Spring Cloud Gateway's pool kept handing that connection out.
- The gateway's HTTP client had no response timeout, so a stuck upstream request was never ended.

This was already present before the other fixes; the first test round happened to stay below the point where it shows.

Fix (applied):
- Tomcat keep-alive set to 60 s, with no per-connection request limit.
- The gateway pool drops idle connections after 45 s (before Tomcat does) and recycles them after 5 min.
- Connect timeout 2 s, response timeout 30 s, so a stuck call becomes 504.
- Tomcat's listen backlog raised from 100 to 1024 for connection bursts.

After the fix, the *prematurely closed* error no longer appears.

### S1 — Internal services reachable directly (High, depends on deployment)

No `server.address` is set, so user-service (3001) and tracker-service (3002) listen on all interfaces (observed: `::`). Anyone who can reach those ports skips the gateway's rate limits. That allows unlimited password guessing at `/api/v1/auth/login` on 3001, and lets the L3 and L4 issues hit the services directly. `/internal/**` is still protected by the shared key (compared in constant time), so it is not an authentication bypass on its own.

Fix: bind the services to `127.0.0.1` or a private network (`server.address`), and firewall 3001/3002 so only the gateway can reach them. Document this in `backend/README.md`.

### S2 — No per-account login throttling (Medium)

The only brute-force protection is 10 auth requests/min per IP. An attacker with many IPs (a botnet or proxies) can try passwords against one account without limit, and credential stuffing across many accounts is not slowed at all. Login timing is equalised with a dummy hash, so it does not reveal which e-mails exist, but registration does (S6).

Fix: add a per-account failure counter with exponential backoff, for example after 5 failures in 15 min (stored in Redis or a DB table). Optionally add a global failed-login rate alarm.

### S3 — Tokens outlive deleted accounts (Medium)

`JwtService.verify` checks only the signature and expiry. After `DELETE /me`, the deleted user's access token keeps working for up to 15 minutes:
- Reads return empty results (200).
- Writes fail with a foreign-key violation, which surfaces as **500 INTERNAL** (reproduced with `POST /applications`).

This leaks nothing, but it is a confusing failure, and it fills the error log with stack traces.

Fix: map `DataIntegrityViolationException` on `user_id` to 401, or check that the user exists on writes. Optionally keep a short-lived deny-list of deleted user ids.

### S4 — Avatars are stored and served as uploaded (Low)

`MeController.avatar` checks the declared content type and the magic bytes, which is good. But it stores the file byte-for-byte:
- EXIF data, which can include GPS location, is kept, and the file is served publicly under `/uploads/avatars/...`.
- Files that are both a valid image and something else (polyglots) are accepted, and the response has no `X-Content-Type-Options: nosniff` header.

Fix: decode and re-encode the image server-side (which strips metadata and normalises the format), cap its dimensions, and add `nosniff` plus `Content-Disposition: inline` to `/uploads/**` responses.

### S5 — Production checks depend on a profile (Low)

`ProductionGuard` rejects placeholder secrets and non-https URLs, but only when the `prod` Spring profile is active. Without that profile, the `.env.example` values start fine: the example JWT secret is long enough to pass the 32-character check. A deployment that forgets `SPRING_PROFILES_ACTIVE=prod` would run with publicly known secrets, and anyone could forge tokens for any user.

Fix: run the guard by default and add an explicit opt-out for local development, or at least refuse the exact `.env.example` values in every profile.

### S6 — Account enumeration on register (Low)

`POST /auth/register` returns 409 `EMAIL_TAKEN`, which reveals whether an e-mail is registered. It is rate limited, and it is a common UX trade-off. If enumeration matters, return the same response either way and send a "you already have an account" e-mail instead (needs a mailer, see S10).

### S7 — Unencrypted DB connection by default (Low)

The default `DB_URL` uses `useSSL=false&allowPublicKeyRetrieval=true`. That is acceptable when MySQL is on the same host. If the database is ever remote, credentials and data cross the network in clear, and `allowPublicKeyRetrieval` enables a man-in-the-middle on authentication. Fix: for any remote database, use `sslMode=VERIFY_IDENTITY`, and have `ProductionGuard` reject `useSSL=false` in production.

### S8 — Client build safeguards (Low)

- `android/app/build.gradle.kts` signs release builds with the debug key when no keystore is configured, so a release APK can be built and shared unintentionally with an insecure key. Fail the release build instead.
- `AppConfig.apiBaseUrl` defaults to `http://localhost:3000` and accepts any `--dart-define`. Android 9+ blocks cleartext traffic by default, but nothing prevents shipping an `http://` production URL. Assert `https://` in release mode.
- What is already good: tokens and device tokens are kept in `flutter_secure_storage`; refreshes are single-flight; there are no automatic retry loops that could cause retry storms; tokens are not logged.

### S9 — Reuse detection can log out every device (Info)

If the server rotates a refresh token but the response never reaches the phone (timeout, app killed), the phone later presents the old token. That counts as reuse, and `revokeAll` signs the user out on **every** device. This is the intended protection against stolen tokens. If it causes support issues, accept the previous token for a short grace period (about 30 s) after rotation.

### S10 — Forgot-password is a stub (Info)

`AuthService.forgotPassword` writes a reset link with a random token to the INFO log, but never stores the token, so the link cannot work. That is safe (the token is useless), but users cannot reset their password. When it is implemented, store only a hash of the reset token, make it expire within an hour and single-use, and never log it.

## What is done well

- **SQL injection:** all values are bound parameters. Dynamic SQL pieces (`ORDER BY`, column names in `UpdateBuilder`) come from fixed code, never from the request. `LIKE` search escapes `%` and `_`.
- **Cross-user access:** every repository query filters on `user_id`, and other users' ids return 404, never 403.
- **Passwords:** Argon2id. Login takes the same time whether or not the e-mail exists (dummy hash). Passwords need at least 8 characters with a digit and a symbol, and are capped at 128.
- **Tokens:** access tokens last 15 minutes and use HS256 with a secret length check. Refresh and device tokens are 48 random bytes stored only as SHA-256 hashes. Refresh is claimed atomically (no double use) and rotated with reuse detection. Changing the password revokes other sessions and device tokens.
- **Service-to-service calls:** `/internal/**` is not routed by the gateway, and its key is compared in constant time. The internal HTTP client has 2 s connect and 3 s read timeouts and is called outside DB transactions, so a slow user-service cannot hold tracker DB connections.
- **Exports:** the CSV export neutralises spreadsheet formulas, and exports stream in keyset pages instead of loading everything.
- **Uploads:** magic-byte check, 2 MB limit, unguessable file names, path-normalised deletes.
- **Error responses:** errors return generic messages; stack traces only go to the server log.
- **Indexes:** the indexes match the query patterns (`user_id` plus status, applied date, follow-up, scheduled time, visible-at).
- **Secrets:** `.env` files are git-ignored, and `ProductionGuard` exists.
- **Path traversal:** an encoded traversal attempt through the gateway (`/api/v1/auth/%2e%2e/.../internal/...`) was rejected with 401.

## Remaining work

Nothing is open. Every finding is either fixed and verified (see [Fixes applied](#fixes-applied)) or an accepted risk:

- **S6, account enumeration on register: accepted (4 Nov 2026).** Registration still answers 409 `EMAIL_TAKEN` for a registered address. The only real fix is a "check your e-mail" flow with e-mail verification, which needs a mail service and changes the sign-up flow in the app. Enumeration is limited to 10 tries per minute per IP, counted across all gateways. Revisit when a mailer exists (forgot-password needs one too, see S10).
- **Keep it patched:** re-run the dependency check (see [Dependencies](#dependencies)) before each release.

## Fixes applied

All backend checks pass on Spring Boot 4.1 (`mvn verify`): common 2, gateway 22, user-service 45 and tracker-service 59 tests, with the Redis tests run against a real Redis 7; the e2e test is opt-in and skipped as before. All app checks pass (`dart format`, `flutter analyze`, `flutter test`: 502 tests). New tests cover each fix: `gateway/GatewayRateLimitTest`, `GatewayProtectionTest` and `RedisRateLimitStoreTest` (two gateways sharing one budget, fallback when Redis is down), `user-service/HardeningTest` and `MeTest`, `tracker-service/HardeningTest`, `common/ConfigGuardsTest`, and in the app `auth_interceptor_test` and `app_config_test`.

| ID | What changed | Where |
|---|---|---|
| L1 | Argon2 runs through `BoundedPasswordEncoder`: at most one hash per CPU core (`ARGON2_MAX_CONCURRENT`). A caller that waits more than 5 s gets 503 `SERVER_BUSY`. New hashes use OWASP's baseline (19 MiB, t=2, p=1); existing hashes, including Node-era ones, still verify because each hash stores its own parameters. | `user-service/.../auth/BoundedPasswordEncoder.java`, `UserConfig`, `UserProperties` |
| L2 | **App:** a 408, 429 or 5xx from `/auth/refresh` keeps the session; only other 4xx answers sign the user out. **Gateway:** signed-in traffic is limited per user (it verifies the JWT signature, so forged ids fall back to the IP budget). Refresh, device login and logout have their own 120/min/IP limit. Password endpoints stay at 10/min/IP. | `app/lib/data/api/auth_interceptor.dart`, `gateway/.../RateLimitFilter.java`, `AccessTokenReader.java` |
| L3 | The gateway refuses bodies over 1 MB (3 MB for avatar uploads) with 413 based on `Content-Length`. The services also stop reading streamed bodies past 1 MB (`RequestGuardFilter`). | `gateway/application.yml`, `common/.../web/RequestGuardFilter.java` |
| L4 | The `/health` probe result is shared by concurrent callers and cached for 3 s. | `gateway/.../HealthController.java` |
| L5 | Per-user keys remove the shared-IP problem. With `REDIS_URL` set, all gateways count in Redis (one Lua script increments the counter and sets its expiry atomically); without it, or while Redis is unreachable, they count in memory, so a Redis outage never blocks traffic. Reconnects happen off the request threads. Avatars moved from local disk into the `user_avatars` table, so any number of user-service instances can serve them; pre-existing files are still served. | `gateway/.../RedisRateLimitStore.java`, `InMemoryRateLimitStore.java`, `RateLimitConfig.java`; `user-service/.../me/AvatarStorage.java`, `AvatarController.java`; `V4__token_rotation_and_avatars.sql` |
| L6 | A nightly job (03:30 UTC) deletes expired refresh tokens, expired or long-revoked device tokens and old login-throttle rows, in batches. Revoked refresh tokens are kept until they expire, because reuse detection needs them. A second nightly job deletes **read** notifications older than `NOTIFICATION_RETENTION_DAYS` (365); unread ones and reminders that have not fired are never touched. | `user-service/.../auth/TokenCleanup.java`, `tracker-service/.../notifications/NotificationRetention.java`, `V3`, `V4` |
| L7 | `page` is capped at 10,000 (400 above that), and the offset is computed without overflow. | `common/.../QueryParams.java`, `PageResponse.java` |
| L8 | Keep-alive, pool and timeout settings (see L8 above). | `common/jobtrail-common.yml`, `gateway/application.yml` |
| S1 | user-service and tracker-service listen on `127.0.0.1` by default (`SERVICE_BIND_ADDRESS`). | `common/jobtrail-common.yml` |
| S2 | Per-account throttle (`login_throttle` table, also for unknown e-mails): 5 wrong passwords in 15 min lock the account for 1 min, doubling up to 15 min. A correct password clears it. It applies to login, change-password, device enrolment and account deletion. A locked account is rejected before hashing, so an attack costs almost no CPU. | `user-service/.../auth/LoginThrottle.java`, `AuthService` |
| S3 | A write that fails on a `fk_*_user` foreign key (the account is gone) returns 401 `UNAUTHORIZED`, and the app then signs out. | `common/.../GlobalExceptionHandler.java` |
| S4 | Avatars are decoded and stored as a fresh copy of at most 512 px. That drops EXIF/GPS and anything appended to the file. Images over 40 megapixels are refused before decoding. Every response has `X-Content-Type-Options: nosniff`. | `user-service/.../me/AvatarImages.java`, `RequestGuardFilter` |
| S5 | `ExampleSecretGuard` refuses the `.env.example` secrets in every profile. | `common/.../security/ExampleSecretGuard.java` |
| S7 | With the `prod` profile, a remote database without TLS is refused (`useSSL=false` / `sslMode=DISABLED` on a non-local host). | `common/.../security/ProductionGuard.java` |
| S8 | Android release builds fail without `key.properties` (set `ALLOW_DEBUG_SIGNING=true` for a local test build). Release builds of the app refuse a non-https `API_BASE_URL` (`--dart-define=ALLOW_INSECURE_API=true` for local testing). | `app/android/app/build.gradle.kts`, `app/lib/core/config/app_config.dart`, `app/lib/main.dart` |
| S10 | Forgot-password logs only that a reset was requested; no token is generated or logged. | `user-service/.../auth/AuthService.java` |
| S9 | A refresh token presented again within 30 s of its rotation, while its replacement has never been used, gets a fresh pair, and the unused replacement is retired (the client lost the response). Any other reuse still revokes every session. Logged-out tokens get no grace. | `user-service/.../auth/AuthService.java`, `RefreshTokenRepository.java`, `V4` |
| D1 | Spring Boot 3.3.5 → **4.1.2** (Spring Framework 7.0.10, Spring Cloud 2025.1.4, Tomcat 11.0.27, Netty 4.2.19, Jackson 3.1.7 and 2.21.7, Lettuce 7.5.2), jjwt 0.13.0, Bouncy Castle 1.86. Code moved to Jackson 3 (`tools.jackson.*`); the gateway uses `spring-cloud-starter-gateway-server-webflux`. | all `pom.xml`, 24 Java files |
| S6 | Not changed: accepted risk, see [Remaining work](#remaining-work). | — |

The docs follow the code: `backend/README.md` (security checklist, deployment variables, troubleshooting), `backend/.env.example` (new variables) and `docs/API.md` (limits, account lock, body size, new error codes `PAYLOAD_TOO_LARGE` 413 and `SERVER_BUSY` 503).

### Verification run

I ran the same stack and load generator again after the fixes:

| Check | Before | After |
|---|---|---|
| 150 MB JSON body | Parsed (tracker +250 MB), then 400 | **413 in 35 ms**, nothing parsed |
| `page=2147483647` | 500 | **400** |
| 10 signed-in users behind one IP, 10 s of reads | Capped at 300 requests per minute for all of them together | **1,199 requests, no 429** (each user has their own budget) |
| Login burst of 3 requests, then refresh from the same IP | Refresh got 429, and the app signed out | Refresh allowed (own limit); the app keeps the session on 429 anyway |
| Services reachable from the network | Listening on `::` (all interfaces) | **`127.0.0.1` only** |
| 50 connections through the gateway | 19 × 500 "prematurely closed" | **0** of those errors |

**Limits of this verification.** At 50 or more concurrent connections, this Windows laptop also stalls *new TCP connections on loopback* for 10–60 s. A control run against a trivial Python HTTP server with no JobTrail code showed the same thing: one `connect()` took 40 s, and a 20 s run took 48 s. MySQL showed no lock waits or slow queries during these stalls. The remaining 504s and timeouts at that concurrency, and the DB-pool timeouts that follow from them, come from the test machine, probably the network-filtering security software that also intercepts Java's TLS. At 40 connections through the gateway, before the stalls set in, the stack served 361 req/s with p95 268 ms.

### Linux verification (3 Nov 2026)

To take the Windows host out of the picture, the whole stack ran as Linux containers on one Docker network: MySQL 8, Redis 7, the three Boot 4.1 services, and the load generator. Each service had production-like limits: 2 CPUs, a 1 GB container, `-Xmx512m`, and Redis-backed rate limits (raised for the capacity runs). **No errors in any run, and no connection stalls:**

| Scenario | Concurrency | Throughput | p50 | p95 | p99 | Errors |
|---|---|---|---|---|---|---|
| Read mix (dashboard, list, calendar, notifications) | 50 | 409 req/s | 98 ms | 274 ms | 477 ms | 0 |
| Read mix | 100 | 895 req/s | 94 ms | 268 ms | 398 ms | 0 |
| Read mix | 200 | 1,123 req/s | 128 ms | 460 ms | 700 ms | 0 |
| `GET /health` | 200 | 2,888 req/s | 51 ms | 189 ms | 300 ms | 0 |
| Create application | 50 | 193 req/s | 209 ms | 499 ms | 1.2 s | 0 |
| Login (Argon2id) | 128 | 18 logins/s | 4.9 s | 5.2 s | 5.8 s | 142 × 503 `SERVER_BUSY` by design |

During the 128-way login burst, user-service peaked at **393 MB** of its 1 GB limit (it reached 4.3 GB before the fixes) and was never OOM-killed or restarted. Logins beyond the 2-core hashing capacity got a fast 503 after 5 s instead of piling up. The gateway logged that it connected to Redis, and the counters were visible in Redis.

**Capacity, in plain terms:** at 1,100 reads/s, the app can serve roughly 10,000–20,000 active users on this small footprint (2 CPUs per service), assuming a user makes about one request every 10–20 s while using the app. Logins are the expensive part: about 9 per second per CPU core. Add user-service instances (or cores) for login peaks; the rate limits and avatars already work across instances.

### Dependencies

On 3 Nov 2026, I listed the exact runtime dependencies with `mvn dependency:list` and checked them, together with every package in `app/pubspec.lock`, against the public OSV.dev database (only package names and versions were sent).
- **Before:** on Spring Boot 3.3.5, and still on 3.5.16, the latest 3.x patch, there were 30+ advisories, several critical. They were in Tomcat (authentication bypasses), Netty (TLS SNI bypass, decompression leaks), Jackson (denial of service) and Spring Framework 6.2, whose fixes exist only in Spring Framework 7.
- **After:** on Spring Boot 4.1.2, **no known vulnerabilities** in 114 Maven and 151 Flutter packages. The checker reported one hit, for `netty-transport-native-epoll`, but its version was misread; the installed 4.2.19 is already patched.

## Not covered

- I did not review TLS termination, reverse proxy settings or hosting, because none are in the repo.
- I did not reverse-engineer the compiled Flutter app or the iOS project settings.
- The load tests ran on one laptop: first on Windows, then in Linux containers with production-like limits. Real hardware and network latency will differ; the Linux numbers are the better guide.
