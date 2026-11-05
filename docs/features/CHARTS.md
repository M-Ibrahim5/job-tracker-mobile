# JobTrail — Dashboard Charts Spec

Covers the two dashboard charts chosen from the "12 · Chart ideas" board:
- **Pipeline: Option A** — segmented ring with a live center
- **Applications per week: Option A** — rounded bars with a tooltip

Both charts are **interactive drill-downs**: pressing a part of a chart previews it, and tapping it opens a **pop-up sheet with the applications behind it** (see §7). Each pop-up keeps an "Open in Applications" button that opens the Applications list with the matching filter (§3).

*Revised 5 Nov 2026: taps used to jump straight to the filtered list. They now open a pop-up first, so the user sees the jobs without leaving the dashboard.* Visual tokens come from `DESIGN.md §2`; this file adds chart-specific specs. Where this file and `DESIGN.md §4.3` differ, **this file wins** for the two charts.

Library: `fl_chart` (`PieChart`, `BarChart`). If a requirement below can't be met with `fl_chart`, use a `CustomPainter` for that chart and keep the same visuals and behavior.

---

## 1. Pipeline chart (segmented ring)

### 1.1 Layout
Card: white surface, 1px `#E6E8F0` border, radius 24, padding 20 / 18. Content stacked, centered, gap 16:
1. Donut, 200 × 200.
2. Legend list (full width), below the donut.

### 1.2 Ring
| Property | Value |
|---|---|
| Size | 200 × 200 |
| Start angle | 12 o'clock, clockwise (`startDegreeOffset: -90`) |
| Section order | Applied, Screening, Interview, Offer, Rejected (pipeline order) |
| Section colors | status accents from `DESIGN.md` (`#1E88E5`, `#FFA000`, `#8E24AA`, `#43A047`, `#E53935`) |
| Section thickness (`radius`) | 24 normal, **33 when selected** |
| `centerSpaceRadius` | ≈ 64 (hollow center) |
| Gap between sections (`sectionsSpace`) | 3 (card surface shows through; never draw borders) |
| Corner rounding | none required (butt caps). Rounded caps are optional via `CustomPainter` only |
| Zero-count statuses | not drawn in the ring (legend row still shown, dimmed) |
| Single status only (e.g. 1 application) | full ring in that color, **no gaps**, center shows its status |

### 1.3 Center label (live)
Always two states, cross-fade 150 ms:
- **Default (nothing selected):** total number (40 / 800) over "Applications" (14 / 700). Under it nothing else.
- **A section is selected / pressed:** count (40 / 800, colored with the status's *chip text* color, e.g. `#6A1B80`), status name (14 / 700), "23% of 34" (12 / 600, `#4A4F66`).
Percentages use largest-remainder rounding so the legend sums to exactly 100%.

### 1.4 Legend rows
One row per status, 48 dp min height, radius 12, padding 7 / 10, gap 10:
`[12×12 swatch r4] [name 14/600, flex] [count 14/800] [percent 14/600, right-aligned, 40 wide, #4A4F66]`
- Selected row: background = status chip bg (`#F1E3F7` for Interview, etc.), text = chip text color, name/count 800.
- Zero-count row: text and swatch at 45% opacity, still tappable.
- Row has `Semantics(button: true, label: "Interview, 8 applications, 23 percent. Opens filtered list")`.

### 1.5 Interaction — preview, then a pop-up
| Gesture | Behavior |
|---|---|
| **Press / hover / drag over a segment** (touch down) | Preview: the segment grows from 24 to 33, the center shows that status's **number of jobs**, name and share ("7 · Interview · 21% of 34"), and its legend row highlights. Releasing outside any segment clears it. |
| **Tap a ring segment** | Open the **status pop-up** (§7.1) listing the applications in that status. |
| **Tap a legend row** | Same pop-up (works for zero-count rows too → "No Offer applications yet"). |
| Tap the center | Nothing. |
| Haptic | `HapticFeedback.selectionClick()` on selection change; `lightImpact()` when the pop-up opens. |

From the pop-up, "Open in Applications" goes to `context.go('/applications?status=<status>')`, e.g. `/applications?status=applied` (§3). The status tiles at the top of the Dashboard still go straight to that list: they are quick filters, not a chart.

Pressed state must never block scrolling the dashboard: only horizontal/short taps count; if the touch moves > 12 px vertically, cancel selection (use `PieTouchData(touchCallback)` and ignore `FlPanUpdateEvent`s that scroll, or wrap in a `RawGestureDetector` as needed).

### 1.6 Animation
- On first load: sweep in clockwise 600 ms `Curves.easeOutCubic`, center total counts up 0 → N over the same time.
- Data change (pull-to-refresh): `PieChart` implicit animation 300 ms.
- Respect `MediaQuery.disableAnimations` (no sweep/count-up, show final state).

### 1.7 States
| State | Rendering |
|---|---|
| Loading | Skeleton: gray ring (`#EEF0F6`) + 5 skeleton legend rows, shimmer. |
| Empty (0 applications) | Ring replaced by dashed outline circle, center "0" / "No applications yet", legend hidden, button "Add your first application". |
| Error | Card with message + Retry. |

### 1.8 Accessibility
- Chart wrapper `Semantics(label: "Pipeline: 34 applications. 9 applied, 7 screening, 8 interview, 4 offer, 6 rejected.", container: true)`; the ring itself is `excludeSemantics` since the legend rows provide the same actions.
- Status is conveyed by text in the legend (not by color alone).

---

## 2. Applications-per-week chart (rounded bars)

### 2.1 Layout
Card: same style as §1. Header row: title "Applications per week" (H2 17/700) and caption "Last 8 weeks" (13/500, `#4A4F66`). Chart height ≈ 196 (viewBox 372×196 in the mockup).

### 2.2 Bars
| Property | Value |
|---|---|
| Data | 8 weeks, oldest → newest; last = current (partial) week; Monday-start in the user's timezone (from `GET /dashboard` → `weekly[]`) |
| Bar width | ≈ 28 (scales with width; 8 bars evenly spaced) |
| Bar shape | top corners radius 8 (`BorderRadius.vertical(top: Radius.circular(8))`); bottom square at the baseline |
| Past weeks | `#C5CBEF` |
| Peak week (max count, earliest if tie; only if max > 0) | vertical gradient `#9FA8E6` → `#C5CBEF` |
| Current week | vertical gradient `#5C6BC0` → `#3F51B5` |
| Zero weeks | **no bar**; a 7 px dot (`#D5D9EE`) sitting 4 px above the baseline |
| Y scale | 0 → max(4, maxCount) (min of 4 so one application doesn't fill the whole chart); hidden y-axis labels |
| Grid | 5 horizontal lines, 1 px `#ECEEF7`, no vertical lines, no border |
| X labels | only first ("31 Aug", 12/600 `#4A4F66`) and last ("This week", 12/800 `#3F51B5`); no others |
| Count labels | none by default (tooltip instead) |

### 2.3 Tooltip
- Dark bubble: `#1B1E2B`, white 12/700 text, radius 9, padding 6 / 10, a small pointer arrow, floating 8 px above the bar top.
- Text: `"4 · wk of 12 Oct"`; singular/plural not needed. For the current week: `"2 · this week"`. For a zero week: `"0 · wk of 7 Sep"`.
- **Default**: tooltip is shown on the **peak week** (matches the mockup). While the user presses another bar the tooltip moves to it; when released it returns to the peak week.
- Must stay inside the card horizontally (clamp).

### 2.4 Interaction — preview, then a pop-up
| Gesture | Behavior |
|---|---|
| **Press / drag across bars** | Selection preview: that bar darkens slightly (gradient `#8E9AE0` → `#5C6BC0`; current week keeps its colors but gets 3 px outline `#283593`), tooltip follows with the count ("4 · wk of 12 Oct"). |
| **Tap a bar with count > 0** | Open the **week pop-up** (§7.2): that week's applications as a day-by-day timeline, with where they stand now. |
| **Tap a zero week** | Nothing opens; tooltip shows "0 · wk of …" and a snackbar is *not* shown. Bar hit area is still the full column height so it's easy to hit. |
| Hit target | The **full column** (bar + empty space above it), min 40 dp wide, full chart height. |
| Haptic | `selectionClick()` while dragging across bars; `lightImpact()` when the pop-up opens. |

From the pop-up, "Open in Applications" goes to (week of Mon 12 Oct → Sun 18 Oct 2026):
`context.go('/applications?from=2026-10-12&to=2026-10-18')`
- `from` = the week's Monday, `to` = that week's Sunday, both `YYYY-MM-DD`, inclusive, computed in the user's timezone, matching the `weekStart` from the API (`to = weekStart + 6 days`). For the **current week** `to` is still that week's Sunday (future days simply contain nothing).
- The filter is on **applied date** (the same date the chart counted), not on status-change dates.

### 2.5 Animation
First load: bars grow from the baseline 500 ms `easeOutCubic`, staggered 40 ms each. Data change: 300 ms implicit. Honor `disableAnimations`.

### 2.6 States
| State | Rendering |
|---|---|
| Loading | Skeleton: 8 rounded rectangles of varied heights (`#EEF0F6`), shimmer. |
| All weeks zero | Show the 8 dots + centered caption "No applications in the last 8 weeks" and a "Add application" text button. Tooltip hidden. |
| Error | Card with message + Retry. |

### 2.7 Accessibility
- Wrapper semantics: `"Applications per week, last 8 weeks: 1, 2, 0, 3, 2, 1, 4, 2"`.
- Each column is an accessible button: `"Week of 12 Oct: 4 applications. Opens filtered list"` (zero weeks: `"Week of 7 Sep: no applications"`, not a button).
- Touch target for each column ≥ 40 × 48 dp.

---

## 3. Routing and filter contract (app side)

**Query parameters on `/applications`** (all optional, combinable):

| Param | Format | Example |
|---|---|---|
| `status` | one or more statuses, comma-separated, camelCase | `status=applied` or `status=screening,interview` |
| `arrangement` | comma-separated | `arrangement=remote` |
| `from`, `to` | `YYYY-MM-DD`, inclusive, applied-date range | `from=2026-10-12&to=2026-10-18` |
| `q`, `sort` | as in `API.md` | `sort=newest` |

Rules:
1. **Replace, don't merge.** Arriving from the dashboard resets the previous filter, then applies the params, so the list matches what was tapped.
2. The Applications screen reads the route's query params and writes them into `applicationFilterProvider` whenever the URL changes (use `GoRouterState.uri.queryParameters`).
3. Show the active filter clearly at the top of the list: a removable chip row, e.g. `Status: Applied ✕` or `12 Oct – 18 Oct ✕`; "Clear all" resets to the unfiltered list (and drops the query params from the URL).
4. Navigation uses `context.go(...)` so the bottom nav switches to the Applications tab. Pressing back from the filtered list returns to the Dashboard at its previous scroll position (keep Dashboard state alive with the `StatefulShellRoute` branch).
5. The list header caption becomes "{n} Applied applications" / "{n} applications · 12–18 Oct".
6. Empty result (e.g. zero-count status): list empty state "No Offer applications yet" with a "Clear filter" button.
7. Backend: no change needed — `GET /applications` already supports `status` and `from`/`to` (see `API.md`).

Pure helpers (put in `features/dashboard/application/`, unit-test them):
- `Uri applicationsUriForStatus(ApplicationStatus s)`
- `Uri applicationsUriForWeek(DateTime weekStartMonday)` → `from`/`to` as above
- `ApplicationFilter filterFromQuery(Map<String,String> q)` (parse/validate; ignore unknown/invalid values)
- `Map<ApplicationStatus,int> percentages(counts)` using largest-remainder rounding
- `int axisMax(List<int> counts)` = `max(4, maxCount)`

---

## 4. Dark theme
- Card surface `#1C1B22` (≈ M3 `surfaceContainerLow`), border `#3A3A44`, text `#E6E1E5`, secondary `#B8B3BD`.
- Status accents are unchanged (they already read well on dark). Center/legend selected text uses the accent lightened ~20% (e.g. Interview `#C77DDA`); selected row background = accent at 18% opacity.
- Bars: past `#3A4075`, peak gradient `#6E78C8` → `#4A5199`, current `#7986E0` → `#5C6BC0`. Zero dots `#3A3A44`. Grid `#2A2A33`. Tooltip bubble `#E6E1E5` with dark text `#1B1E2B`.

## 5. Tests (add to session 07's Definition of Done)
- Pop-ups (§7): tapping a segment or legend row opens the status pop-up for that status (no navigation yet); its rows show title, company and status; a row opens `/applications/:id`; "Open in Applications" opens the filtered list; Close stays on the dashboard. Tapping a non-zero bar opens the week pop-up ("This week" for the current one); it groups by applied day (earliest first) and shows the outcome strip; a zero week opens nothing. Unit: `statusDrillFilter`, `weekDrillFilter`, `groupByAppliedDay`, `statusBreakdown`. Both pop-ups fit 320 px at 1.5× text in light and dark.
- Unit: `applicationsUriForStatus`, `applicationsUriForWeek` (week boundaries, month/year rollover, DST-safe since dates only), `filterFromQuery` (valid, invalid, multi-status), `percentages` sums to 100, `axisMax`.
- Widget: tapping each legend row navigates to the right URI (use a `MockGoRouter`/`GoRouter` test harness); zero-count row still navigates; tapping a zero-week bar does **not** navigate; tapping a non-zero bar navigates to the correct `from`/`to`; selection preview updates center text and legend highlight; empty and loading states render; semantics labels exist.
- Applications screen: opening `/applications?status=applied` shows only applied items and a removable filter chip; clearing the chip removes the query.
- Golden (optional): ring and bars in light/dark at 320 and 390 px widths.

## 6. Mockup reference
Canvas board **"12 · Chart ideas (dashboard)"**, options *Pipeline A* and *Applications per week A*. The mockup is static; the press/selection, navigation, animation and empty/loading states above are additions to it.

## 7. Pop-ups — the applications behind a chart

Tapping a ring segment, a legend row or a non-zero bar opens a bottom sheet (same frame as the calendar day sheet: drag handle, top radius 28, 50% scrim, max 80% of the screen, fade instead of slide with reduced motion). The sheet loads its applications with `GET /applications` and the same filter as the Applications link (at most 50; if there are more, a "Showing 50 of 120" note sits above the button). It reloads when applications change.

Shared parts:
- **Header:** a 40 dp circle with the icon, the title (20/800) with a one-line subtitle, and a 48 dp close button.
- **Rows:** a company monogram (first letter, tinted by status), job title (15/700, 2 lines max) and company (13, secondary) on the left, and the **status chip** on the right. On narrow screens (< 380 dp) or with large text, the chip moves under the company. The whole row is one button: it closes the sheet and opens that application (`/applications/:id`, pushed, so Back returns to the dashboard). Semantics: "Flutter Developer at Acme, Applied. Opens the application".
- **Footer:** "Open in Applications" (outlined, 52 dp), pinned below the scrolling list, opens the filtered list (§3).
- **States:** a spinner while loading; "Couldn't load these applications." with Retry; an empty message when the filter matches nothing.

### 7.1 Status pop-up (pipeline ring)
*"Which jobs are in Interview right now?"*
- Header: the status icon in its colour, the title = status name ("Interview"), the subtitle = "7 applications".
- A list of the applications in that status, newest applied first.
- Empty: "No Offer applications yet".

### 7.2 Week pop-up (weekly bars)
*"What did I send that week, and how is it going?"*
- Header: a calendar icon, the title "Week of 12 Oct" ("This week" for the current week), the subtitle "4 applications · 12–18 Oct".
- **Where they are now:** one stacked bar (12 dp, rounded) with a segment per current status of that week's applications, in pipeline order and coloured like the ring, plus a legend "2 Applied · 1 Interview · 1 Rejected". It shows at a glance how that week's batch has progressed.
- **Day-by-day timeline:** a vertical rail with a dot per day that had applications (empty days are skipped), earliest first. Each day reads "Mon 12 Oct · 2 applications", followed by its application rows.
- Empty week: never opened from the chart (zero bars are inert); if the data changed meanwhile, it shows "No applications in the last 8 weeks".

### 7.3 Why the two pop-ups are different
Showing the same list in both would make the second chart redundant, as the user said. The two charts answer different questions, so their pop-ups do too:

| | Pipeline ring | Weekly bars |
|---|---|---|
| Question | *Where are my applications **now**?* (a snapshot across all jobs) | *How **active** was I, and what came of it?* (activity over time) |
| Groups jobs by | current status | the week they were sent |
| Pop-up adds | nothing extra: the status is the point | a **timeline by day** (when exactly I applied) and the **outcome strip** (how that week's batch progressed, e.g. 1 of 4 reached Interview) |

**Recommendation (implemented):** the week pop-up shows the extra timeline and outcome information rather than a plain list. A plain list would duplicate the ring, while the timeline turns the bar into a review of that week ("I applied to four jobs on Monday and Wednesday, one reached an interview, one was rejected"). Both pop-ups use the same row (title, company, status), so they still feel like one system.
