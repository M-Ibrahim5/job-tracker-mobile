# JobTrail — REST API Contract (v1)

Contract shared by the **backend** and **Flutter app** sessions. Neither side may change it without editing this file first.

- Base URL: `/api/v1`, served by the **gateway** (`:3000`), which routes to the user and tracker services; clients never see that split. JSON only (`Content-Type: application/json`), **camelCase** fields, enum strings exactly as in `DATABASE.md`.
- Auth: `Authorization: Bearer <accessToken>` on everything except `/auth/*` (register, login, refresh, forgot-password) and `/health`.
- Times: ISO-8601 UTC strings with `Z` (`2026-10-27T02:00:00.000Z`). `appliedDate` is a date-only string `YYYY-MM-DD`. The app converts to local time for display.
- IDs: JSON numbers.
- Pagination: `?page=1&pageSize=20` (max 100) → `{ "items": [...], "page": 1, "pageSize": 20, "total": 57 }`.
- Errors (all non-2xx):
```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Human readable", "fields": { "jobTitle": "This field is required" } } }
```
Codes: `VALIDATION_ERROR` 400/422, `UNAUTHORIZED` 401 (`TOKEN_EXPIRED` variant → app refreshes), `FORBIDDEN` 403, `NOT_FOUND` 404, `INTERVIEW_CONFLICT` 409, `EMAIL_TAKEN` 409, `INVALID_CREDENTIALS` 401, `PAYLOAD_TOO_LARGE` 413, `RATE_LIMITED` 429, `INTERNAL` 500, `SERVER_BUSY` 503 (too many password checks at once; retry shortly).
- Access token: JWT, 15 min. Refresh token: opaque, 30 days, rotated on every refresh.

---

## Auth

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/auth/register` | `{ fullName, email, password }` | 201 `AuthResponse` |
| POST | `/auth/login` | `{ email, password }` | 200 `AuthResponse` |
| POST | `/auth/refresh` | `{ refreshToken }` | 200 `{ accessToken, refreshToken }` |
| POST | `/auth/logout` | `{ refreshToken }` | 204 (revokes it) |
| POST | `/auth/forgot-password` | `{ email }` | 204 always (stub: log the reset link server-side in v1) |
| POST | `/auth/change-password` | `{ currentPassword, newPassword, refreshToken? }` | 204 (revokes all other refresh tokens; send the current `refreshToken` so this session is kept, otherwise all are revoked) |

**Device token (fingerprint login).** After the user confirms their password once, the server gives that phone a long random *device token*. The phone keeps it in secure storage and releases it only after a fingerprint scan, so the password is never stored on the device.

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/auth/device-token` | `{ password, deviceName? }` (needs the bearer token) | 201 `{ deviceToken }` (`INVALID_CREDENTIALS` 401 if the password is wrong) |
| POST | `/auth/device-login` | `{ deviceToken }` | 200 `AuthResponse` (`UNAUTHORIZED` 401 if unknown, revoked or expired) |
| DELETE | `/auth/device-token` | `{ deviceToken }` (needs the bearer token) | 204 (revokes it; unknown tokens are ignored) |

- The server stores only a SHA-256 hash. Tokens are valid 90 days from last use (sliding), at most 5 live per user (the oldest is revoked when a 6th is issued).
- `/auth/change-password` **revokes all device tokens** of the user; the app then asks for a new one using the new password. Deleting the account removes them.
- `device-login` is public and rate limited like the other `/auth/*` endpoints.

Password rules: ≥ 8 chars, ≥ 1 digit, ≥ 1 symbol. Hash with argon2id (or bcrypt cost ≥ 12).

```json
AuthResponse = { "accessToken": "...", "refreshToken": "...", "user": User }
User = { "id": 1, "email": "a@b.com", "fullName": "Muhammad Ibrahim", "phone": null, "currentRole": "Software Engineer",
         "lookingFor": null, "location": "Kuala Lumpur, Malaysia", "avatarUrl": null, "emailVerified": true }
```

## Me / profile / settings

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | → `User` |
| PATCH | `/me` | Partial `{ fullName, phone, currentRole, lookingFor, location }`. Email is **not** editable. → `User` |
| POST | `/me/avatar` | `multipart/form-data` field `file` (jpeg/png, ≤ 2 MB) → `User` |
| DELETE | `/me` | Deletes account and all data. Body `{ password }`. 204 |
| GET | `/me/settings` | → `Settings` |
| PATCH | `/me/settings` | Partial → `Settings` |

```json
Settings = { "theme": "system", "interviewRemindersEnabled": true, "followUpRemindersEnabled": true,
             "statusAlertsEnabled": true, "defaultReminderOffsetsMinutes": [1440, 60], "defaultFollowUpDays": 7 }
```
`defaultFollowUpDays`: `null` (off) | 3 | 5 | 7 | 14.

## Applications

```json
JobApplication = {
  "id": 12, "jobTitle": "Senior Flutter Developer", "companyName": "Northwind Labs", "location": "Kuala Lumpur",
  "workArrangement": "hybrid", "jobDescription": "...", "applicationLink": "https://...", "employmentType": "fullTime",
  "salaryRange": "RM 9,000 – 12,000", "source": "linkedIn", "appliedDate": "2026-10-22", "status": "interview",
  "notes": "...", "contactName": "Aisha Rahman", "contactEmail": "aisha@northwind.example",
  "followUpAt": null, "nextInterviewAt": "2026-10-27T02:00:00.000Z",
  "createdAt": "...", "updatedAt": "..."
}
```
`nextInterviewAt` is computed (earliest future interview, may be null) so the list can show "Next: 27 Oct". The list response omits `jobDescription` (returns `null`) to stay light; detail returns it.

| Method | Path | Notes |
|---|---|---|
| GET | `/applications` | Query: `q` (title/company/location LIKE), `status` (repeatable/comma), `arrangement` (comma), `from`,`to` (appliedDate range), `sort` = `newest`(default) \| `oldest` \| `companyAZ` \| `status` (pipeline order), `page`,`pageSize`. → paginated `JobApplication` |
| POST | `/applications` | Body = `JobApplication` fields without computed/id/timestamps; `status` optional (default `applied`). Creates initial history. 201 → `JobApplication` |
| GET | `/applications/:id` | → `JobApplication` |
| PATCH | `/applications/:id` | Partial editable fields. **`status` ignored.** If `followUpAt` changes, reschedule its reminder notification. |
| DELETE | `/applications/:id` | 204. (Undo is client-side: the app delays this call until the Undo snackbar closes.) |
| POST | `/applications/:id/status` | `{ status, note? }` → `{ application: JobApplication, history: StatusHistoryEntry }`. No-op (200 with same status, no history row) if unchanged. |
| GET | `/applications/:id/history` | → `StatusHistoryEntry[]` oldest first |
| GET | `/applications/:id/timeline` | → `{ history: StatusHistoryEntry[], interviews: Interview[] }` for the calendar's job-timeline mode |

Validation (server and app): `jobTitle`,`companyName`,`location` required, trimmed, ≤ 100; `applicationLink` http(s) URL ≤ 2048; `appliedDate` ≤ today + 1 day; `contactEmail` valid; `jobDescription` ≤ 10,000 chars.

```json
StatusHistoryEntry = { "id": 5, "applicationId": 12, "fromStatus": "screening", "toStatus": "interview",
                       "changedAt": "2026-10-24T03:05:00.000Z", "note": "Recruiter called" }
```
`fromStatus` is `null` for the initial entry.

## Interviews

```json
Interview = { "id": 3, "applicationId": 12, "applicationTitle": "Senior Flutter Developer", "companyName": "Northwind Labs",
  "title": "Technical interview · Round 2", "type": "video", "scheduledAt": "2026-10-27T02:00:00.000Z",
  "durationMinutes": 60, "locationOrLink": "https://meet...", "interviewerName": "Daniel Lim", "notes": "...",
  "reminderOffsetsMinutes": [1440, 60], "outcome": "pending", "createdAt": "...", "updatedAt": "..." }
```

| Method | Path | Notes |
|---|---|---|
| GET | `/interviews` | Query: `scope` = `upcoming`(asc) \| `past`(desc), `applicationId`, `from`,`to`, `page`,`pageSize`. Paginated. |
| POST | `/applications/:id/interviews` | Create. 201 → `Interview`. **409 `INTERVIEW_CONFLICT`** if same application has one at the exact `scheduledAt`. The app decides whether to offer the status change by checking the application's status and its interview count before saving (`GET /interviews?applicationId=`). |
| GET | `/interviews/:id` | → `Interview` |
| PATCH | `/interviews/:id` | Partial. Reschedules reminder notifications. 409 on conflict. |
| DELETE | `/interviews/:id` | 204. Removes pending reminder rows. |

Past `scheduledAt` is allowed (app shows a warning); no reminders are generated for past times.

## Notifications (in-app center)

```json
Notification = { "id": 9, "type": "statusChange", "title": "Moved to Interview", "body": "Northwind Labs · Senior Flutter Developer",
                 "relatedApplicationId": 12, "relatedInterviewId": null, "createdAt": "2026-10-24T03:05:00.000Z", "isRead": false }
```
`createdAt` in the response = the row's `visible_at`. Only rows with `visible_at <= now` are returned.

| Method | Path | Notes |
|---|---|---|
| GET | `/notifications` | Paginated, newest first. The app groups Today/Yesterday/Earlier locally. |
| GET | `/notifications/unread-count` | → `{ "count": 3 }` (nav badge) |
| POST | `/notifications/:id/read` | 204 |
| POST | `/notifications/read-all` | 204 |
| DELETE | `/notifications/:id` | 204 |
| DELETE | `/notifications` | Clear all. 204 |

## Device reminders (for local push scheduling)

`GET /reminders/upcoming` → the app schedules local notifications (flutter_local_notifications) from this on launch, login, after edits, on timezone change and after reboot.

```json
{ "items": [ { "key": "interview:3:1440", "kind": "interviewReminder", "fireAt": "2026-10-26T02:00:00.000Z",
               "title": "Interview tomorrow", "body": "Northwind Labs · 10:00 AM · Video",
               "applicationId": 12, "interviewId": 3 } ] }
```
Includes the next 60 days of interview reminders and follow-up reminders (`kind: followUpReminder`), only future `fireAt`, only for enabled types. `key` is stable → the app derives the local notification id from it (`hash(key) & 0x7fffffff`) to cancel/replace.

## Dashboard

`GET /dashboard?tz=Asia/Kuala_Lumpur`
```json
{ "total": 15, "active": 11, "responseRatePercent": 67,
  "statusCounts": { "applied": 5, "screening": 3, "interview": 3, "offer": 1, "rejected": 3 },
  "weekly": [ { "weekStart": "2026-08-31", "count": 1 }, "... 8 items, oldest first, last = current week" ],
  "upcomingInterviews": [ Interview, "... max 3 (scheduledAt >= now, outcome pending)" ],
  "recentActivity": [ { "applicationId": 12, "companyName": "Northwind Labs", "toStatus": "interview", "changedAt": "..." }, "... max 5, excludes initial entries" ] }
```
Definitions: `active` = status not in (`offer`,`rejected`); `responseRatePercent` = round(100 × applications with status ≠ `applied` or any history beyond initial / total) — use "status ≠ applied" for simplicity; 0 when total = 0.

## Calendar

`GET /calendar?from=2026-10-01&to=2026-10-31&tz=Asia/Kuala_Lumpur` (range ≤ 70 days)
```json
{ "events": [
  { "date": "2026-10-22", "type": "applied", "applicationId": 12, "companyName": "Northwind Labs", "title": "Senior Flutter Developer" },
  { "date": "2026-10-24", "type": "statusChange", "applicationId": 12, "companyName": "...", "title": "...", "status": "interview", "at": "..." },
  { "date": "2026-10-27", "type": "interview", "interviewId": 3, "applicationId": 12, "companyName": "...", "title": "Technical interview · Round 2", "interviewType": "video", "at": "..." },
  { "date": "2026-10-25", "type": "followUp", "applicationId": 14, "companyName": "Orbit Health", "title": "Flutter Developer", "at": "..." } ] }
```
`date` is computed in the user's `tz`.

## Data

| Method | Path | Notes |
|---|---|---|
| GET | `/export?format=json` | Full dump: `{ exportedAt, applications:[... with history & interviews] }`. `Content-Disposition: attachment`. |
| GET | `/export?format=csv` | Applications as CSV (one row per application). `createdAt` / `updatedAt` are printed as `dd/MM/yyyy \| hh:mm AM/PM` in the `X-Timezone` zone (UTC if absent). Other columns keep their API format. |
| DELETE | `/data` | Body `{ "confirm": "DELETE" }`. Deletes all applications/interviews/history/notifications; keeps account. 204 |

## Misc

- `GET /health` → `{ "status": "ok", "version": "1.0.0", "services": { "user": "up", "tracker": "up" } }` (no auth). If a backing service is down: 503 with `"status": "degraded"` and that service marked `down`.
- CORS not needed (mobile). Rate-limit `/auth/*` (10/min/IP, enforced by the gateway).
- Version info: `GET /health` also returns `"version"`.

## Implementation notes (agreed behaviour that the sections above leave open)

- **Timezone header.** Endpoints that format times into text (reminder bodies, `/reminders/upcoming`) (and the CSV export's `createdAt`/`updatedAt`) honour an optional `X-Timezone: <IANA name>` header; UTC otherwise. `/dashboard` and `/calendar` take `tz` as a query parameter.
- **Default follow-up.** `POST /applications` without `followUpAt` applies the user's default (`appliedDate + defaultFollowUpDays`, 09:00 UTC); an explicit `followUpAt: null` opts out.
- **`GET /interviews` without `scope`** returns every interview, soonest first.
- **Cancelled / passed / failed interviews** don't count towards `nextInterviewAt`, the dashboard's upcoming list or reminders; setting such an outcome removes the interview's unfired reminders (setting it back to `pending` recreates them).
- **Past interviews** may be created; they simply produce no reminders.
- **Rate limits.** Everything under `/api/v1` (except `/health`): 300 requests/min per user when a valid access token is sent, otherwise per IP. On top of that, per IP: `/auth/login`, `/auth/register`, `/auth/forgot-password`, `/auth/change-password`, `/auth/device-token` 10/min; `/auth/refresh`, `/auth/device-login`, `/auth/logout` 120/min. Exceeded → 429 `RATE_LIMITED` with a `Retry-After` header (seconds). A 429 or 5xx from `/auth/refresh` is temporary: clients keep their tokens and retry later. A backing service that cannot be reached → 503 `INTERNAL`.
- **Canonical paths.** The gateway answers 404 `NOT_FOUND` for any path containing percent-encoding, `;`, `\`, `//` or `.`/`..` segments, so rate limits and routing always see the same path.
- **Read caps.** Endpoints that are not paginated return at most 1000 rows per calendar range, 500 interviews for `/reminders/upcoming` (only those that can still produce a reminder), and 200 interviews and 200 status changes per application timeline.
- **Account lock.** After 5 wrong passwords for one e-mail within 15 minutes (whether or not the account exists), password checks for it answer 429 `RATE_LIMITED` ("Too many failed attempts. Try again in N minutes") for 1 minute, doubling per further failure up to 15 minutes. A correct password clears the count.
- **Body size.** JSON bodies are limited to 1 MB (avatar uploads: 2 MB file, 3 MB request) → 413 `PAYLOAD_TOO_LARGE`. `page` is at most 10,000.
- **Access to other users' ids** is always 404 (never 403); path ids that are not positive integers are 404 too.
- **Text search.** `GET /applications?q=` matches title, company and location case-insensitively; `%` and `_` are literal characters.
- **Avatar files** are served from `/uploads/avatars/<userId>-<random>.<ext>`; the random suffix makes URLs unguessable. They are re-encoded (at most 512 px, no metadata), stored in the database, and cached by clients for a year (a new upload gets a new name).
- **Refresh retries.** Presenting a refresh token that was rotated less than 30 s ago, whose replacement has never been used, returns a fresh pair (the client lost the earlier response) and retires the unused replacement. Any other reuse of a revoked refresh token revokes every session of the user.
