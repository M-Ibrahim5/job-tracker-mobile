# Session 07 — App: Dashboard & Calendar

**Depends on:** sessions 05 and 06 (navigation targets, interview form). Live backend: session 02.
**Read first:** `docs/00-README.md`, `docs/DESIGN.md` §4.3, §4.7, `docs/API.md` (Dashboard, Calendar, Applications timeline).
**Owns:** `app/lib/features/{dashboard,calendar}/`, `data/api/api_dashboard_repository.dart`, `api_calendar_repository.dart`.

## Goal
The Dashboard home tab and the Calendar tab exactly as designed, driven by real data.

## Tasks

1. **Repositories**: `ApiDashboardRepository` (`GET /dashboard?tz=` with the device IANA tz from `flutter_timezone`), `ApiCalendarRepository` (`GET /calendar?from&to&tz`, `GET /applications/:id/timeline`) + fakes.
2. **Dashboard** (`/`) per DESIGN §4.3:
   - Greeting by local time + first name; header "+" → `/applications/new`.
   - Summary card (primary fill, 3 stats, response-rate bar with semantics label).
   - Status tiles → `context.go('/applications?status=<s>')` (session 05 deep-link filter).
   - Pipeline donut (`fl_chart` `PieChart`, ring 20, center total, legend) with semantics text summary.
   - Applications per week bar chart (8 bars, count labels, current week highlighted, axis labels).
   - Upcoming interviews (3) → `/interviews/:id`; "See all" → `/interviews`.
   - Recent activity (5): "Moved **Company** to Status", icon tile in status colors, relative time (`DateHelpers.relative`).
   - Pull-to-refresh, skeleton loading state, error state with retry, and the **empty state** (total == 0): illustration (simple vector drawn with `CustomPainter`/icons, no external asset) + "Add your first application".
   - Charts must not overflow at 320px width / large text; no business logic in widgets (a `DashboardViewModel` computes labels, colors, bar heights).
3. **Calendar** (`/calendar`) per DESIGN §4.7:
   - `table_calendar` with Month / 2 weeks / Week toggle (`CalendarFormat`), Monday start, "Today" button, last format remembered in `shared_preferences`.
   - Fetch events for the visible range (+ padding), cache per month, refetch on page change/refresh.
   - Day markers via `markerBuilder`: dots per DESIGN (applied blue 6, status change in status accent 6, interview purple 8, follow-up orange 6; max 3 dots), today ring, selected fill. Legend row.
   - Day agenda below: grouped by type with eyebrow labels and left-border cards; tap → application/interview detail; empty day text.
   - **Job timeline mode**: application picker (bottom sheet search over applications); show vertical timeline from `/applications/:id/timeline` (history + interviews, upcoming ones outlined) and highlight those dates on the calendar (e.g. ring/underline); clear to exit mode.
   - FAB "Interview" → `/interviews/new?date=<selected day>`.
   - Pure functions + unit tests: `groupEventsByDay`, `markersForDay` (cap + priority), `visibleRange(format, focusedDay)`.

## Definition of Done
- Dashboard numbers match backend/fake fixtures (total 15, active 11, response 67% with the fixtures from `DESIGN.md` seed, or whatever the seed produces — assert against the fixture, not hard-coded UI).
- Calendar shows each event type correctly, per-day agenda, timeline mode, quick-add prefilled date.
- Tests: view-model unit tests (greeting, percentages, bar scaling), widget tests (empty state, skeleton, tile → navigation, calendar format toggle persistence, agenda grouping), `markersForDay`.
- Light + dark, 320px width, 1.5× text scale — no overflow.
- `dart format . && flutter analyze && flutter test` clean.

## Handoff notes
**Done**
- `dart format . && flutter analyze` clean (0 issues); `flutter test` 396/396 pass (≈80 new: view-model and calendar-logic unit tests, dashboard and calendar widget tests, REST repositories).
- `ApiDashboardRepository` (`GET /dashboard?tz=`) and `ApiCalendarRepository` (`GET /calendar?from&to&tz`) replace the stubs (`api_stubs.dart` is gone). The job timeline uses the existing `JobApplicationRepository.timeline`. The fakes already covered both. `core/services/device_timezone.dart` reads the IANA zone via `flutter_timezone` (falls back to `UTC`; the fake backend never asks the platform).
- **Dashboard** (`/`): `DashboardViewModel` (greeting, first name, percentages, bar scaling, donut slices, semantics summaries, relative times) is pure and unit-tested; widgets only lay it out. Summary card with response-rate bar, status tiles → `context.go('/applications?status=<s>')`, `fl_chart` donut (ring 20, total in the center, legend), 8 custom weekly bars (current week in primary, count labels, axis "31 Aug … This week"), upcoming interviews (+ See all → `/interviews`), recent activity, pull-to-refresh, skeleton, error + Retry, and the empty state (CustomPainter illustration + "Add your first application"). Reloads when `applicationsRevisionProvider` / `interviewsRevisionProvider` / `dataRevisionProvider` change.
- **Calendar** (`/calendar`): `table_calendar` Month / 2 weeks / Week (Monday start, format remembered in `shared_preferences` under `calendar_format`), Today button, month header with chevrons, markers (applied blue 6, status change in status accent 6, interview purple 8, follow-up orange 6, max 3, interviews first), today ring / selected fill, legend, per-day agenda grouped Interviews → Applications → Status changes → Follow-ups with left-border cards, empty-day text, FAB "Interview" → `/interviews/new?date=<selected day>`. Events are fetched per month (padded grid, ≤ 56 days) and cached; paging fetches only new months, pull-to-refresh / Retry reload, data changes clear the cache. **Job timeline mode**: "Company ▾" chip → search sheet over applications → vertical timeline (history + interviews, upcoming ones outlined and labelled) with the dates underlined/ringed in the grid; ✕ leaves the mode. Pure, tested functions: `visibleRange`, `groupEventsByDay`, `markersForDay`, `agendaGroups`, `requiredMonths`, `timelineItems`, `timelineDates`.
- Strings: `core/constants/dashboard_strings.dart` (`DashboardStrings`, `CalendarStrings`).

**Fixes / decisions**
- The dashboard empty-state title is "Start tracking your job search" so the CTA button can keep the wording "Add your first application" from the brief.
- Month view requests only the focused month (its padded range already covers the grid and neighbours), so most navigation needs a single call per month.
- Dashboard "+" uses `push` to `/applications/new`; tiles use `go` so they switch to the Applications tab.

**Not done / open**
- Not run on a device/emulator (no visual comparison against the mockups); the 320px / 1.5× text / light+dark checks are widget tests only.
- `flutter build apk` is still blocked here by the Gradle SSL problem noted in session 06.
- No git commit (working tree also holds sessions 03–06). Suggested message: `S07: dashboard and calendar`.
- Manual script: sign in (`USE_FAKE=true`) → Dashboard numbers match the Applications list → tap a status tile → back → pull to refresh → Calendar: switch formats and restart (format kept), page months, tap days, add an interview via the FAB (date prefilled) and see the dot appear, pick a company for the job timeline.

### Charts upgrade (docs/CHARTS.md)
**Done**
- Pipeline: segmented ring (fl_chart `PieChart`, 200 dp, hole 64, thickness 24 → 33 selected, 3 dp gaps, none for a single status), live center (total counts up; press shows count, name and "23% of 34"), legend rows with percentages (largest remainder), clockwise sweep-in, dashed empty ring, skeleton. `features/dashboard/presentation/dashboard_charts.dart`.
- Weekly chart is now a `CustomPainter` (rounded top corners, peak/current gradients, dots for empty weeks, grid, persistent tooltip clamped inside the card, staggered grow-in, full-column hit areas, skeleton, "no applications" state). `fl_chart` `BarChart` could not do the persistent tooltip, dots and full-column hits, which the spec allows as a fallback.
- Touch: `ChartTouchRegion` listens to raw pointer events (no gesture arena), so the dashboard keeps scrolling; a vertical move over 12 px cancels the preview and the tap. `fl_chart`'s own touch is disabled.
- Routing: `chart_logic.dart` has `applicationsUriForStatus/Week/Filter`, `filterFromQuery`, `percentages`, `axisMax`, `peakIndex`, `weekTooltip` and `ringSegmentAt`. `ApplicationsScreen` takes the route's whole query (replace, not merge) and shows removable chips, "Clear all" (drops the params), the "{n} Applied applications" / "{n} applications · 12–18 Oct" caption and "No Offer applications yet" + "Clear filter". Labels live in `applications/application/filter_labels.dart`.
- Tests: 79 new (475 total). `dart format` of changed dirs, `flutter analyze` and `flutter test` are clean.

**Deviations / open**
- `ApplicationsScreen(initialStatus:)` became `ApplicationsScreen(query:)`.
- The status chips and filter sheet do not write the URL, so tapping a chart link that is identical to the current URL after changing the filter by hand does not re-apply it.
- There is one `GET /dashboard` call, so the charts have no separate error card; the whole-screen error + Retry covers them.
- At 320 px the eight columns are about 31 dp wide (spec asks for 40 dp minimum).
- Not run on a device; visuals are unchecked against the mockup board.
