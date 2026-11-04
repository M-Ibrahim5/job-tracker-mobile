# JobTrail — Dashboard Charts Spec

Covers the two dashboard charts chosen from the "12 · Chart ideas" board:
- **Pipeline: Option A** — segmented ring with a live center
- **Applications per week: Option A** — rounded bars with a tooltip

Both charts are **interactive drill-downs**: tapping a part of a chart opens the Applications list with the matching filter. Visual tokens come from `DESIGN.md §2`; this file adds chart-specific specs. Where this file and `DESIGN.md §4.3` differ, **this file wins** for the two charts.

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

### 1.5 Interaction — drill down to the list
| Gesture | Behavior |
|---|---|
| **Press / hover / drag over a segment** (touch down) | Select preview: segment grows to 33, center and legend row update. Releasing outside any segment clears it. |
| **Tap a ring segment** | Navigate to the list filtered by that status. |
| **Tap a legend row** | Same navigation (works for zero-count rows too → shows the empty-state "No Offer applications"). |
| Tap the center | Nothing (or navigate to unfiltered list; v1: nothing). |
| Haptic | `HapticFeedback.selectionClick()` on selection change; `lightImpact()` on navigate. |

Navigation target: `context.go('/applications?status=<status>')`, e.g. `/applications?status=applied`. See §3 for the full routing contract. The existing status tiles at the top of the Dashboard use the same target.

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

### 2.4 Interaction — drill down to the list
| Gesture | Behavior |
|---|---|
| **Press / drag across bars** | Selection preview: that bar darkens slightly (gradient `#8E9AE0` → `#5C6BC0`; current week keeps its colors but gets 3 px outline `#283593`), tooltip follows. |
| **Tap a bar with count > 0** | Navigate to the Applications list filtered to that week. |
| **Tap a zero week** | No navigation; tooltip shows "0 · wk of …" and a snackbar is *not* shown. Bar hit area is still the full column height so it's easy to hit. |
| Hit target | The **full column** (bar + empty space above it), min 40 dp wide, full chart height. |
| Haptic | `selectionClick()` while dragging across bars; `lightImpact()` on navigate. |

Navigation target (week of Mon 12 Oct → Sun 18 Oct 2026):
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
- Unit: `applicationsUriForStatus`, `applicationsUriForWeek` (week boundaries, month/year rollover, DST-safe since dates only), `filterFromQuery` (valid, invalid, multi-status), `percentages` sums to 100, `axisMax`.
- Widget: tapping each legend row navigates to the right URI (use a `MockGoRouter`/`GoRouter` test harness); zero-count row still navigates; tapping a zero-week bar does **not** navigate; tapping a non-zero bar navigates to the correct `from`/`to`; selection preview updates center text and legend highlight; empty and loading states render; semantics labels exist.
- Applications screen: opening `/applications?status=applied` shows only applied items and a removable filter chip; clearing the chip removes the query.
- Golden (optional): ring and bars in light/dark at 320 and 390 px widths.

## 6. Mockup reference
Canvas board **"12 · Chart ideas (dashboard)"**, options *Pipeline A* and *Applications per week A*. The mockup is static; the press/selection, navigation, animation and empty/loading states above are additions to it.
