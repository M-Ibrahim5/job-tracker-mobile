# Security audit (10 Nov 2026): implementation plan

This plan fixes the findings of the security audit run on 10 Nov 2026 with Cloudflare's `security-audit` skill (quick profile, source review only). It is written for the agent that implements the fixes. Each task stands alone: read its section, make the change, add the test, run the checks.

The full audit output (ledger, structured findings, verifier records) is outside the repo in `C:\Users\Acer\security-audit-skill\job-tracker-v1\run-1\`. You do not need it; everything required is below.

## Read first

- **Status of the findings.** Every finding is `needs_validation`: the source path was checked by two independent agents, but nothing was executed during the audit (there was no sandbox). So **every task starts by writing the regression test and running it against the current code.** If the test passes before your change (the bug is not real), stop that task, do not change the code, and write that result in the task's "Result" line in [Tracking](#tracking).
- **Project rules** (from `CLAUDE.md`): no `print`/`System.out`/`console.*`; app strings go in `app/lib/core/constants`; enum values stay camelCase; `docs/API.md` and `docs/DATABASE.md` are the contract, so update them in the same change when behaviour visible to clients changes.
- **Checks after each task:**
  - Backend: `cd backend && mvn verify` (see the memory note on the JDK 21 path and Maven TLS flag if Maven fails to start or download).
  - App: `cd app && dart format . && flutter analyze && flutter test`.
- **One commit per task**, message style `fix(gateway): ...`, `fix(user-service): ...`, `fix(app): ...` as in the existing history. Work on a branch off `develop`.
- **Prior review.** `docs/SECURITY-AND-LOAD-REPORT.md` (2 Nov) lists fixes L1–L8, S1–S10, D1. Do not undo any of them. Tasks 1–3 below are gaps in those fixes (L2/L5 rate limits, S2 account lock).

## Priority order

| # | Task | Area | Who can trigger it | Why this order |
|---|---|---|---|---|
| 1 | [Encoded paths bypass gateway rate limits](#task-1--encoded-paths-bypass-gateway-rate-limits) | gateway | Anyone on the internet | Unauthenticated; defeats every rate limit, lets one client fill the Argon2 slots so real users get 503 at login |
| 2 | [Login lock can be raced](#task-2--login-lock-can-be-raced) | user-service | Anyone with several IPs | Defeats the S2 per-account lock (more than 5 guesses per lock) |
| 3 | [Leftmost X-Forwarded-For is trusted](#task-3--leftmost-x-forwarded-for-is-trusted) | gateway | Anyone, once deployed behind nginx | Planned production setup (W08) turns it on; fix before deploying |
| 4 | [Fingerprint login not bound to the account](#task-4--fingerprint-login-not-bound-to-the-account) | app | Someone holding the unlocked phone | Signs in as another person's account |
| 5 | [Previous account's data shown after account switch](#task-5--previous-accounts-data-shown-after-account-switch) | app | Next person who signs in on the same phone | Shows another user's applications and interviews |
| 6 | [Unbounded reads in reminders, calendar and timeline](#task-6--unbounded-reads-in-reminders-calendar-and-timeline) | tracker-service | Any signed-in user | One account can make every `/reminders/upcoming` call load hundreds of MB |
| 7 | [Hardening batch](#task-7--hardening-batch) | all | — | Defence in depth; no direct exploit found |

---

## Task 1 — Encoded paths bypass gateway rate limits

**Problem.** `RateLimitFilter` decides which limit applies by testing the raw, still-encoded path with `startsWith`:

- [RateLimitFilter.java:43-59](../backend/gateway/src/main/java/com/jobtrail/gateway/RateLimitFilter.java#L43-L59): `path = exchange.getRequest().getPath().value()`, then `path.startsWith("/api/v1/")`, `path.startsWith("/api/v1/auth/")`, `TOKEN_PATHS.contains(path)`.

Route predicates in [application.yml:26-50](../backend/gateway/src/main/resources/application.yml#L26-L50) and Spring MVC in the services match **decoded** segments with `;params` removed. So:

- `POST /%61pi/v1/auth/login` or `POST /api/v1;x/auth/login` → no limit at all, still routed to `AuthController.login`.
- `POST /api/v1/%61uth/login` → skips the 10/min auth limit, only the 300/min API limit applies.

Effect: unlimited logins and registrations from one client. Each login runs Argon2 through `BoundedPasswordEncoder`; when its slots are full, **all** users get 503 `SERVER_BUSY`.

**Fix.** No legitimate client sends `%`, `;`, `\`, `//` or dot segments in the path (ids are numeric, avatar file names match `\d+-[0-9a-f]{24}\.(png|jpg)`, search text is in the query string). Reject such paths at the edge, before rate limiting.

1. Add `backend/gateway/src/main/java/com/jobtrail/gateway/CanonicalPathFilter.java`, a `GlobalFilter, Ordered` with `getOrder() = Ordered.HIGHEST_PRECEDENCE`.
   - Read `exchange.getRequest().getURI().getRawPath()`.
   - Reject when the raw path contains `%`, `;`, `\`, `//`, or has a segment equal to `.` or `..`.
   - Respond with `ApiErrors.write(exchange, HttpStatus.NOT_FOUND, "NOT_FOUND", "Route not found")`, the same body the gateway already returns for unknown routes ([ApiErrorHandler.java:27-28](../backend/gateway/src/main/java/com/jobtrail/gateway/ApiErrorHandler.java#L27-L28)). No new error code is needed.
   - Do not log the rejected path at INFO (it is attacker-controlled); `debug` is fine.
2. In `RateLimitFilter.getOrder()` return `Ordered.HIGHEST_PRECEDENCE + 1` so the new filter runs first.
3. Keep `RateLimitFilter`'s string checks. After step 1, the raw path equals the decoded path for every request that reaches it.

**Tests** (add `backend/gateway/src/test/java/com/jobtrail/gateway/GatewayPathCanonicalTest.java`; copy the setup of `GatewayRateLimitTest`: stub services, `auth-limit=3`, `api-limit=6`).

> **Watch out:** `WebTestClient.uri(String)` percent-encodes `%` into `%25`, so the bypass would not be sent. Build the URI with `URI.create("/api/v1/%61uth/login")` (or `uri(builder -> ...)` with `build(true)`/an already-encoded URI). Before the fix, confirm in the stub that the request really arrived as `/api/v1/%61uth/login`.

- **Before the fix (should fail today):** 5 × `POST /api/v1/%61uth/login` from one IP all reach the stub (no 429), while 5 × `POST /api/v1/auth/login` gives 429 on the 4th. Same for `GET /%61pi/v1/applications` and `GET /api/v1;x/applications` × 10.
- **After the fix:** each of those variants gets 404 `NOT_FOUND`, and the stub receives nothing. Also cover `/api/v1/me/../../internal/users/1/settings` → 404 and the stub receives nothing.
- **Regression:** the canonical paths still route (`GET /api/v1/applications`, `GET /uploads/avatars/1-0123456789abcdef01234567.png`). Run the existing `GatewayRateLimitTest`, `GatewayRoutingTest` and `GatewayProtectionTest` unchanged.

**Docs.** In [docs/API.md](API.md) "Implementation notes", add one line: paths with percent-encoding, `;`, `\`, `//` or dot segments get 404. In `docs/SECURITY-AND-LOAD-REPORT.md`, add a short "Follow-up (10 Nov 2026)" note under L2/L5 pointing to this task.

---

## Task 2 — Login lock can be raced

**Problem.** The per-account lock (S2) checks first and counts afterwards:

- [AuthService.java:106-120](../backend/user-service/src/main/java/com/jobtrail/user/auth/AuthService.java#L106-L120): `throttle.check()` → `matches()` (Argon2) → `throttle.failed()`.
- [LoginThrottle.java:50-78](../backend/user-service/src/main/java/com/jobtrail/user/auth/LoginThrottle.java#L50-L78): `check()` is a plain `SELECT`; `failed()` increments and locks only after the hash.
- `BoundedPasswordEncoder` makes callers wait up to 5 s for a hash slot, so a burst queues up and every queued guess is still evaluated.

N parallel guesses against one e-mail, all sent before the first lock is written, all get evaluated. The same ordering exists in `changePassword` (line ~214) and `requirePassword` (line ~236).

**Fix: reserve the attempt atomically before hashing.** Replace `check` + `failed` with one reservation that counts the attempt up front, under a row lock.

1. In `LoginThrottle`, add `public void reserve(String email, Instant now)`, run in one short transaction (inject `TransactionTemplate`, as `AuthService` already does; no hashing inside the transaction):
   1. Make sure the row exists: `INSERT IGNORE INTO login_throttle (email, failures, window_started_at) VALUES (:email, 0, :now)`.
   2. `SELECT failures, window_started_at, locked_until FROM login_throttle WHERE email = :email FOR UPDATE`.
   3. If `locked_until > now`, throw the same 429 `RATE_LIMITED` as `check()` does today (same message).
   4. `failures = (window_started_at < now - WINDOW) ? 1 : failures + 1`. If the window restarted, set `window_started_at = now`.
   5. If `failures >= FREE_FAILURES`, set `locked_until = now + lockFor(failures)`.
   6. `UPDATE` the row with these values.
2. Keep `succeeded(email)` as is: a correct password deletes the row, so it also clears a lock set by the reservation.
3. Remove `check()` and `failed()` (or make them private) once the three call sites use `reserve()`:
   - `login`: `throttle.reserve(email, now)` before `users.findByEmail`; after a wrong password, just throw `invalidCredentials()` (the attempt is already counted).
   - `changePassword` and `requirePassword`: the same pattern.
4. Behaviour stays as documented in [docs/API.md:193](API.md): 5 wrong passwords in 15 min → lock 1 min, doubling to 15 min, correct password clears. The difference is that the 5th attempt sets the lock *before* its hash runs, so concurrent extra attempts see the lock. The 5th attempt itself is still evaluated, so the user still gets 5 real tries.
5. Optional: if `matches()` throws `SERVER_BUSY` (503), call a small `refund(email)` that decrements `failures` (never below 0), so a busy server does not lock real users. Keep the lock if one was already set.

**Tests** (in `user-service`, alongside the existing `HardeningTest`, using the same scratch-DB setup the module's tests already use):

- **Before the fix (should fail today):** register `u@example.test`. Start 30 threads blocked on a `CountDownLatch`; 29 call `authService.login(email, "wrong-" + n)`, one calls it with the correct password. Release the latch. Count the outcomes. A secure result is at most 5 `INVALID_CREDENTIALS` (or 4 plus 1 success), with the rest `RATE_LIMITED`. Set `jobtrail.argon2.max-concurrent=2` in the test so requests queue.
- **After the fix:** the same test passes. Also keep or adapt the existing sequential lock tests: 5 wrong → 6th is 429; wait for the lock to expire (inject a clock or move `locked_until` back in the DB) → 6th wrong attempt is evaluated and locks for 2 min; correct password clears.

---

## Task 3 — Leftmost X-Forwarded-For is trusted

**Problem.** With `TRUST_FORWARDED_FOR=true`, [RateLimitFilter.java:70-79](../backend/gateway/src/main/java/com/jobtrail/gateway/RateLimitFilter.java#L70-L79) takes `forwarded.split(",")[0]`, the **leftmost** entry, which the client writes. nginx's common `$proxy_add_x_forwarded_for` *appends* the real address, so the client keeps control of the leftmost value. A client can then pick a new "IP" per request and never hit the per-IP limits. [W08-landing-qa-deploy.md:43-45](web-sessions/W08-landing-qa-deploy.md) plans exactly this setup. The default (`false`) is safe.

**Fix.**

1. Add to `GatewayProperties` a `trustedProxies` list (env `TRUSTED_PROXIES`, comma-separated IPs, default `127.0.0.1,::1`).
2. In `clientAddress()`:
   - If `trustForwardedFor` is false, or the TCP peer (`getRemoteAddress()`) is not in `trustedProxies`, use the TCP peer address. Ignore the header.
   - Otherwise, split the header on `,`, trim, and walk **from the right**, skipping entries that are themselves in `trustedProxies`. The first entry that is not a trusted proxy is the client. If none is left, use the TCP peer.
   - Ignore entries longer than 45 characters (the longest IPv6 text form), so junk cannot become a giant map key.
3. Document the expected nginx line in [backend/README.md](../backend/README.md) and in `W08-landing-qa-deploy.md` (the deploy step): `proxy_set_header X-Forwarded-For $remote_addr;` (overwrite, not append). Add `TRUSTED_PROXIES` to `backend/.env.example` with a comment.

**Tests** (extend `GatewayRateLimitTest`; its fixture already has `trust-forwarded-for=true` and `auth-limit=3`, and WebTestClient calls arrive from 127.0.0.1):

- **Before the fix (should fail today):** 4 × login with `X-Forwarded-For: 203.0.113.<i>, 10.0.0.9` (i = 1..4) → all 4 pass today. After the fix, they are all keyed by `10.0.0.9`, so the 4th gets 429.
- A single-value header (`X-Forwarded-For: 10.0.0.1`) still works as today. The existing tests use this form and must stay green.
- With `trusted-proxies` set to an address that is not the test client, the header is ignored and the TCP address is used.

---

## Task 4 — Fingerprint login not bound to the account

**Problem.**

- The device token sits under one fixed key with no owner: [biometric_service.dart:62-79](../app/lib/core/services/biometric_service.dart#L62-L79) (`_key = 'device_token'`).
- [biometric_controller.dart:25-33](../app/lib/features/auth/application/biometric_controller.dart#L25-L33) reports fingerprint login as enabled whenever *any* token exists.
- Password sign-in ([auth_controller.dart:52-57](../app/lib/features/auth/application/auth_controller.dart#L52-L57)) does not check whose token it is.
- So after A enables fingerprint login and signs out, B signs in with a password and sees the toggle on. Later, the fingerprint button signs in **as A**.
- Separately, `signIn()` ([biometric_controller.dart:89-104](../app/lib/features/auth/application/biometric_controller.dart#L89-L104)) uses only the boolean result of `local_auth`. A fingerprint enrolled later by someone who knows the phone PIN also works.

**Part A (do now): bind the token to its owner.**

1. Change `DeviceTokenStore` to store the owner as well. Add `Future<int?> readOwner()` and make `save(String token, {required int userId})` write a second key, `device_token_owner`. `clear()` deletes both keys. Update the fake/test implementations of `DeviceTokenStore`.
2. `BiometricActions.enable` and `passwordChanged` pass `userId: currentUser.id` (read `currentUserProvider`).
3. In `AuthController.signIn` and `signUp` (password paths), after the repository returns `user`: if a device token exists and its owner is not `user.id`, call `deviceTokenStore.clear()` (local only; the token also expires on the server) and invalidate `biometricStatusProvider`. A token with no owner (saved before this change) counts as a different owner, so clear it.
4. `biometricStatusProvider`: when a user is signed in, `enabled = token != null && owner == currentUser.id`. When signed out (login screen), keep today's behaviour.
5. Optional UX: store the enrolled e-mail too and show "Sign in as a•••@example.com with fingerprint" on the login screen. Put the text in `core/constants`.

**Part B (needs a decision from the owner before you start): bind the token to the enrolled biometrics.**
To stop "enrol a new fingerprint, then sign in", the token must be stored behind a Keystore/Keychain key that requires biometric authentication and is invalidated when enrolment changes (Android `setInvalidatedByBiometricEnrollment(true)` with a `CryptoObject`; iOS access control `.biometryCurrentSet`). `local_auth` cannot do this. It needs a new dependency (for example `biometric_storage`) or a small platform channel. **Do not add a dependency without asking.** Write a short proposal in the Tracking table instead.
Server-side, a smaller mitigation that needs no decision: in [AuthService.java:~191-192](../backend/user-service/src/main/java/com/jobtrail/user/auth/AuthService.java) `deviceLogin` extends the token by 90 days on every use. Consider a fixed absolute lifetime (90 days from creation), so a forgotten phone cannot stay signed in forever. Ask before changing it; it changes app behaviour.

**Tests** (`app/test/core/biometric_actions_test.dart` already exists; extend it):

- **Before the fix (should fail today):** user A enables fingerprint login, signs out; user B signs in with a password → `biometricStatusProvider` reports `enabled == true`, and `signIn()` signs in as A.
- **After the fix:** B's password sign-in clears the token. Status is `enabled == false` and `signIn()` returns false. A signing in again with a password keeps A's token.

---

## Task 5 — Previous account's data shown after account switch

**Problem.**

- The app has one `ProviderScope` for the whole process ([main.dart:19](../app/lib/main.dart#L19)).
- These providers are keep-alive (not `autoDispose`) and never depend on who is signed in:
  - `applicationListProvider` ([application_providers.dart:204](../app/lib/features/applications/application/application_providers.dart#L204), build at line 96)
  - `applicationFilterProvider`
  - `interviewListProvider` ([interviews_providers.dart:160](../app/lib/features/interviews/application/interviews_providers.dart#L160), build at line 92)
  - `calendarEventsProvider` ([calendar_providers.dart:157](../app/lib/features/calendar/application/calendar_providers.dart#L157), build at line 107; month cache)
  - `timelineApplicationProvider` ([calendar_providers.dart:184](../app/lib/features/calendar/application/calendar_providers.dart#L184))
- `signOut()` and `sessionExpired()` ([auth_controller.dart:80-94](../app/lib/features/auth/application/auth_controller.dart#L80-L94)) reset none of them.
- Result: after A signs out and B signs in without restarting the app, the Applications, Interviews and Calendar tabs show A's records.

**Fix: key per-user state on the user id.**

1. In [app/lib/app/providers.dart](../app/lib/app/providers.dart), next to `currentUserProvider`, add:
   ```dart
   /// Id of the signed-in user, or null. Per-user caches watch this so they reset on account switch.
   final currentUserIdProvider = Provider<int?>(
     (ref) => ref.watch(currentUserProvider.select((u) => u?.id)),
   );
   ```
   (Check the type of `User.id` and match it.) Use `select` so a profile edit (`updateUser`) does not reload every list.
2. Add `ref.watch(currentUserIdProvider);` as the first line of each keep-alive provider's `build`/create function listed above: `ApplicationListNotifier.build`, `InterviewListNotifier.build`, `CalendarEventsNotifier.build`, and the `applicationFilterProvider` and `timelineApplicationProvider` creators. That resets them to their initial state when the user changes.
3. Search the app for any other non-`autoDispose` provider that holds server data: `grep -rn "Provider<\|Provider(" app/lib | grep -v autoDispose`. Apply the same line where it holds per-user data. Leave app-wide ones alone (theme, config, repositories, `sharedPreferencesProvider`).
4. Also in `sessionExpired()`, cancel local reminders the way `signOut()` does (hardening item H5 below), so that path matches too.

**Tests** (new `app/test/app/account_switch_test.dart`, following `app_flow_test.dart` and the fake backend helpers in `app/test/helpers`):

- **Before the fix (should fail today):** seed user A with an application whose company is "Alpha Corp" and user B with none. Pump the app and sign in as A. Open Applications, Interviews and Calendar and `pumpAndSettle`. Sign out, sign in as B in the same `ProviderContainer`, open the same tabs, and expect `find.text('Alpha Corp')` to find nothing. Today it is still found.
- **After the fix:** the test passes. The existing app tests stay green.

---

## Task 6 — Unbounded reads in reminders, calendar and timeline

**Problem.**

- `GET /api/v1/reminders/upcoming` calls [InterviewRepository.pendingAfter](../backend/tracker-service/src/main/java/com/jobtrail/tracker/interviews/InterviewRepository.java#L149-L156): every pending future interview with `SELECT i.*`, including `notes` (up to 10,000 chars), with no `LIMIT` and no upper date.
- The 60-day horizon is only applied in Java afterwards ([ReminderController.java:54-66](../backend/tracker-service/src/main/java/com/jobtrail/tracker/reminders/ReminderController.java#L54-L66)).
- Reminder offsets are at most 43,200 min (30 days), so interviews more than 90 days out can never produce a reminder, yet they are loaded every time.
- There is no cap on how many interviews or applications a user can create.
- A user who creates ~20,000 far-future interviews makes every reminders call load hundreds of MB into the shared tracker JVM.
- Same pattern without a row cap: `InterviewRepository.between` (calendar), `forApplication` (timeline), and `ApplicationRepository.appliedBetween` / `followUpsBetween`.

**Fix.**

1. **Bound the reminder query in SQL.** Change `pendingAfter(userId, now)` to `pendingBetween(userId, now, upTo)` with `AND i.scheduled_at <= :upTo`. In `ReminderController`, pass `upTo = horizon.plus(Duration.ofMinutes(InterviewInput.MAX_REMINDER_OFFSET_MINUTES))`. Today 43,200 is a literal in `InterviewInput` (lines 52 and 54); turn it into that constant and use it in both places. Add `ORDER BY i.scheduled_at, i.id LIMIT 500`.
2. **Do not load wide columns where they are not used.** Reminders use only id, application id, company name, scheduled time, type and offsets. Add a narrow `SELECT` (no `notes`, no `location_or_link`) for `pendingBetween`. Do the same for calendar `between` if `CalendarController` does not render notes (check first).
3. **Row caps on the other non-paginated reads:** add `LIMIT 1000` to `between`, `appliedBetween`, `followUpsBetween`, and `LIMIT 200` to `interviews.forApplication` and `history.forApplication`. Read each caller to make sure a cap cannot cut off data the UI needs in normal use. A real user has far fewer rows than these caps.
4. **Per-user creation caps** (check with the owner before adding these; it is an API change): for example 5,000 applications per user and 200 interviews per application. Over the cap → 422 `VALIDATION_ERROR` with a clear message (an existing code, so no new enum value). If added, document both caps in `docs/API.md` (Applications / Interviews sections) and show the message in the app via `core/constants`.

**Tests** (tracker-service):

- **Before/after:** seed one user (direct JDBC insert in the test, not through the API) with 600 pending interviews scheduled 1–2 years ahead and 3 within the next 7 days with offsets `[60]`. Call `GET /api/v1/reminders/upcoming` and assert that exactly the 3 near interviews come back. Then spy on or count the repository rows loaded and assert ≤ 500. Before the fix, all 603 rows load.
- Existing reminder, calendar and timeline tests stay green.

---

## Task 7 — Hardening batch

These came from the hunters' notes. No exploit was shown for any of them. Do them after tasks 1–6, one small commit each, and skip any that turn out to be wrong when you read the code.

| ID | Change | Where |
|---|---|---|
| H1 | Strip incoming `X-Internal-Key` (and any other internal-only header) from client requests at the gateway, with a `RemoveRequestHeader` default filter. | `backend/gateway/src/main/resources/application.yml` |
| H2 | The gateway has no `ExampleSecretGuard`: refuse to start when `JWT_SECRET` equals the `.env.example` value (the gateway uses it to choose rate-limit keys). | `backend/gateway/.../AccessTokenReader.java` or a small startup check |
| H3 | Add `typ: "access"` to issued JWTs and require it in `JwtService.verify`, so a future JWT type signed with the same key cannot be used as an access token. | `backend/common/.../security/JwtService.java` |
| H4 | Password change: also clear the refresh-token grace eligibility (`rotated_at`/`replaced_by`) for the tokens it keeps, so an older token in its 30 s grace cannot revoke the kept one. | `backend/user-service/.../auth/RefreshTokenRepository.java` (`revokeAllExcept`) |
| H5 | `sessionExpired()` should cancel local reminders like `signOut()`; in `_syncOnce`, check again that the user is signed in after the network fetch and before scheduling. | `app/lib/features/auth/application/auth_controller.dart`, `app/lib/core/services/reminder_scheduler.dart` |
| H6 | Add `<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>` to `MainActivity`; the app has no deep links, and this stops other apps from setting the start route. | `app/android/app/src/main/AndroidManifest.xml` |
| H7 | Exclude secure-storage and shared-prefs files from Android backup (`android:dataExtractionRules` / `fullBackupContent`, or `allowBackup="false"`); on iOS use `KeychainAccessibility.first_unlock_this_device` for the token stores. | `AndroidManifest.xml`, `app/lib/data/api/token_storage.dart`, `app/lib/core/services/biometric_service.dart` |
| H8 | Reminder notifications show company and interview details: set Android `visibility: NotificationVisibility.private`. | `app/lib/core/services/flutter_notification_gateway.dart` |
| H9 | Delete the exported CSV/JSON from the temp directory after sharing. | `app/lib/core/services/file_sharer.dart` |
| H10 | `AuthInterceptor`: before ending the session on a 401, compare the request's `Authorization` header with the stored token; ignore a 401 for a request sent with a previous account's token. | `app/lib/data/api/auth_interceptor.dart` |
| H11 | Seeder: refuse to run with the `prod` profile or a non-local `DB_URL` (it creates `demo@jobtrail.test` / `Demo@1234`). | `backend/seed/.../Seeder.java` |
| H12 | Lower the avatar pixel limit (40 MP decodes to ~160 MB) to, for example, 16 MP, or run decodes through a small semaphore. | `backend/user-service/.../me/AvatarImages.java` |
| H13 | Avatar upload race: replace the old avatar inside one transaction (`SELECT ... FOR UPDATE` on the user row) so two concurrent uploads cannot leave an orphan row. | `backend/user-service/.../me/MeController.java` |
| H14 | Add `distributionSha256Sum` for the Gradle 9.3.1 distribution. | `app/android/gradle/wrapper/gradle-wrapper.properties` |
| H15 | Add `*.pem`, `*.key`, `*.p12`, `google-services.json`, `GoogleService-Info.plist` and `.vscode/` (or just `.vscode/*.local*`) to `.gitignore`. | `.gitignore` |
| H16 | Reject interview dates outside a sane range (for example year 2000–2100) with 400 instead of letting MySQL fail with 500. | `backend/common/.../time/Iso.java` or `InterviewInput` |
| H17 | Defence in depth: add `AND user_id = :user` to the id-only `UPDATE`s (`ApplicationRepository.update/updateStatus`, `InterviewRepository.update`, `HistoryRepository.get`). | tracker-service repositories |

---

## Tracking

Fill in as you go. "Result" is one of: fixed, not reproduced (test passed before the fix, so no change was made), or deferred (needs an owner decision, with a reason).

| Task | Result | Commit | Notes |
|---|---|---|---|
| 1 Encoded paths bypass rate limits | fixed | 1426f6e | Reproduced first: the encoded variants returned 200. New `CanonicalPathFilter`; `GatewayPathCanonicalTest`. |
| 2 Login lock race | fixed | fdbf936 | Reproduced first: 30 of 30 parallel guesses were hashed. `LoginThrottle.reserve` counts under a row lock; `LoginThrottleRaceTest`. |
| 3 Leftmost X-Forwarded-For | fixed | a3492cf | Reproduced first (4th login got 200). New `TRUSTED_PROXIES`; the proxy must overwrite the header. |
| 4A Fingerprint token owner | fixed | 9e5ba5b | Tests written together with the fix, not run on the old code. Tokens saved by an older app version have no owner: the first fingerprint sign-in claims them, a password sign-in by anyone else clears them. |
| 4B Fingerprint bound to biometrics | deferred | | Needs a decision: a new dependency (for example `biometric_storage`) or a platform channel, so the token sits behind a key that requires biometrics and is invalidated when a fingerprint is added. Not started. |
| 5 Account-switch cache | fixed | e1a4a38 | Reproduced first: all 4 tests failed. Per-user providers watch `currentUserIdProvider`. |
| 6 Unbounded reads | fixed | 09b7a64 | Reproduced first: 603 rows loaded for 3 reminders. Per-user creation caps (step 4) deferred: API change, needs a decision. |
| 7 H1-H4, H11-H13, H16, H17 | fixed | 20aa3c7 | H4 reproduced first (200 instead of 401). H3 note: access tokens issued before this change count as expired once, and the app refreshes. H12 limit is now 16 MP. H16 range is 2000-2100. |
| 7 H5-H10, H14, H15 | fixed | 7a99336 | H7: iOS keychain items use `first_unlock_this_device`; items saved with the old setting may need one sign-in again. H9: export files are deleted before the next export and after sign-out. |

Checks at the end: `mvn verify` passes for common, user-service, tracker-service, gateway and seed. The `e2e` module does not compile, with or without these changes (`HappyPathE2ETest.java:55`, "IOException is never thrown"): it is unrelated and left alone. App: `flutter analyze` clean, 527 tests pass.

When done, add a short "Audit of 10 Nov 2026" section to `docs/SECURITY-AND-LOAD-REPORT.md`, with this table's final state.
