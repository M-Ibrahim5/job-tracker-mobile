# Session 02 — Backend Features

**Depends on:** session 01 merged.
**Read first:** `docs/00-README.md`, `docs/DATABASE.md` (incl. Rules), `docs/API.md` (all sections after Settings).
**Owns:** `backend/tracker-service` (`applications`, `interviews`, `notifications`, `reminders`, `dashboard`, `calendar`, `data`, `history`, `settings` packages) + tests, `backend/seed` data, `backend/e2e`. Don't touch `app/`.

## Goal
All remaining REST endpoints in `API.md` as the **tracker-service** (:3002, reached through the gateway), scoped per authenticated user, with correct status-history, notification and reminder behavior.

## Tasks

1. **Applications**
   - CRUD + list (`q`, `status`, `arrangement`, `from`, `to`, `sort`, pagination) exactly per `API.md`. Sorting `status` = pipeline order (MySQL ENUM order), not alphabetical. `q` matches title/company/location with `LIKE ... ESCAPE` so `%`/`_` are literal. Include computed `nextInterviewAt` (subquery: earliest future *pending* interview). List rows omit `jobDescription`.
   - Create: transaction → insert application + initial `status_history` row (`from_status` NULL). If `followUpAt` or the user's default follow-up applies, create its `followUpReminder` notification row (see below). An omitted `followUpAt` takes the default (`appliedDate + N days, 09:00 UTC`), an explicit `null` opts out.
   - PATCH ignores `status`. Changing `followUpAt` (or company/title, which the reminder text embeds) replaces its unfired reminder row.
   - `POST /applications/{id}/status`: transaction → update status + insert history (+ `statusChange` notification if the user's `statusAlertsEnabled`). Unchanged status → 200 no-op, no history row.
   - `GET /{id}/history`, `GET /{id}/timeline`.
   - Ownership: any id not belonging to the user (or not a positive integer) → 404 (never 403, never leak existence).
2. **Interviews**
   - Create/list/get/patch/delete per `API.md`. Unique `(application_id, scheduled_at)` → map `DuplicateKeyException` to 409 `INTERVIEW_CONFLICT`.
   - Each create/update: delete the interview's unfired reminder notification rows, insert new ones for each offset where `scheduled_at - offset > now`, the user's `interviewRemindersEnabled` and the outcome is `pending`. Title like `Interview in 1 day` / `Interview in 1 hour`, body `Company · 10:00 AM · Video` (time in the `X-Timezone` header's zone, else UTC). FK cascade handles deletion.
   - List joins `applicationTitle` and `companyName`.
3. **Notifications**: list (only `visible_at <= now`, newest first, paginated), unread-count, read, read-all, delete, clear-all (visible rows only). Exposed `createdAt` = `visible_at`.
4. **Reminders**: `GET /reminders/upcoming` → next 60 days of interview + follow-up reminder items with stable `key`s (`interview:<id>:<offsetMinutes>`, `followUp:<appId>`), only future, only enabled types.
5. **Dashboard**: `GET /dashboard?tz=` per `API.md` (SQL aggregates; weeks Monday-start in `tz`, 8 buckets incl. zero weeks; upcoming = next 3 pending future interviews; recent activity = last 5 history rows with `from_status IS NOT NULL`).
6. **Calendar**: `GET /calendar?from&to&tz` returning events of types `applied`, `statusChange` (exclude initial entries), `interview`, `followUp`; reject ranges ≥ 70 days apart with `VALIDATION_ERROR`; `date` computed in `tz` with `java.time`.
7. **Data**: `GET /export?format=json|csv` (streamed in keyset pages of 500; CSV with RFC 4180 escaping and formula-injection guard; JSON includes history and interviews), `DELETE /data` requiring `{confirm:"DELETE"}`.
8. **Preferences**: `UserSettingsClient` (interface) reads the user's settings from `user-service` `GET /internal/users/{id}/settings` with `X-Internal-Key` (2 s connect / 3 s read timeout); on failure use the documented defaults and log a warning. Tests replace it with a bean that reads `user_settings`.
9. **Seed**: `seed` module gives the demo user ~15 realistic applications across all statuses with status history, past/upcoming interviews and notifications (sample data style from `DESIGN.md`).
10. **E2E**: `e2e` module — `mvn -pl e2e test -De2e=true` walks the API through the gateway of a running stack (register, isolation, status change, interview + conflict, reminders, dashboard, calendar, export, refresh rotation/reuse, delete-all, delete account).

## Definition of Done
- Every endpoint in `API.md` implemented with validation matching the documented rules (title/company/location ≤ 100, URL http(s), appliedDate ≤ today+1d, email, JD ≤ 10,000).
- Tests (JUnit 5 + MockMvc against `jobtrail_test`) cover at minimum: user isolation (user B gets 404 on user A's ids); create → initial history; status change history + note; no-op status; list filters/sort/pagination; interview conflict 409; reminder rows created/replaced/deleted and hidden until `visible_at`; dashboard numbers against known fixtures (active, response rate, weekly buckets); calendar events and time zones; export JSON/CSV; delete-all; cascade delete of application removes interviews/history/notifications.
- `mvn verify` passes. Performance sanity: list with 1,000 applications < 200 ms locally, and an `EXPLAIN` assertion that the user filter uses an `idx_app_user_*` index.
- `backend/README.md` has the endpoint table; `backend/requests.http` has one request per endpoint.

## Handoff notes
**Done:** applications (CRUD, list filters/sort/paging, status + history, timeline), interviews (CRUD, 409 conflict, reminder rows), notifications, `/reminders/upcoming`, dashboard, calendar, export (JSON/CSV, streamed), `DELETE /data`, `UserSettingsClient`, seed (15 applications), e2e module, `backend/README.md` endpoint table, `backend/requests.http`. **54 tests** in `tracker-service` (24 applications incl. the performance check, 15 interviews/notifications/reminders, 15 dashboard/calendar/export/delete-all), all passing with `mvn verify`; the full run is 92 tests (user 26, tracker 54, gateway 12), and the e2e module passes against a live stack.

**Deviations / decisions**
- Behaviour carried over from the Node version: default follow-up from the user's setting (explicit `null` opts out); `GET /interviews` without `scope` returns all, ascending; `nextInterviewAt` and the dashboard's upcoming list only consider `pending` interviews; `X-Timezone` formats reminder bodies and `/reminders/upcoming`; weekly dashboard buckets use SQL on the `DATE` column (`tz` only picks the current week).
- Fixed from the Node version's open issues: `q` now escapes `%`/`_`; any non-`pending` outcome (not only `cancelled`) removes unfired interview reminders.
- Notification and history timestamps are truncated to milliseconds before insert, so "visible now" rows are never a rounding step in the future.
- Calendar range rule kept: `to - from` must be < 70 days (70 days inclusive at most).
- `status` sort relies on MySQL ENUM ordering (declaration order = pipeline order); the Java enum has the same order.

**Perf:** 1,000 applications list (`pageSize=50`, `status=applied,screening`, `sort=status`) is asserted `< 200 ms`; `EXPLAIN` for `user_id + status ORDER BY applied_date` is asserted to use an `idx_app_user_*` index.

**Open issues:** company/title edits don't rewrite already-created interview reminder bodies; concurrent interview creates on the same application were never load-tested (the app calls sequentially).
