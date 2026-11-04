# FEATURE-CALENDAR-DAY — Tap a date to see that day's events

Status: design approved. Boards 18a (day with events) and 18b (empty day) in the design canvas.
Applies to the Calendar tab (Month, 2 weeks and Week views).
This file overrides the Calendar section of DESIGN.md where they differ (see section 7).

## 1. What changes

1. Tapping any date opens a **bottom sheet** listing that day's events. Each row opens the job or interview details.
2. The sheet has two buttons at the bottom: **Add interview** and **Add job application**, both prefilled with the tapped date.
3. The inline "day agenda" list under the calendar is **removed**. The "Job timeline" section stays.
4. **Follow-up** events change colour from orange to **teal** so they are distinct from Status change (amber).

## 2. The popup sheet

Layout (top to bottom):

- Drag handle (40 x 4, `#D9DCE8`).
- Header: date as `Fri, 30 Oct 2026` (20 sp, weight 800) with a subtitle `N events` / `1 event` / `No events` (13 sp). Close button on the right (48 dp circle, `#F1F2F8`).
- Event list (gap 10). Each row is a card: white, 1 px `#E6E8F0` border, 4 px coloured left edge, radius 16, min height 64, padding 12/8/12/14. It contains:
  - Label line, 11 sp, weight 800, letter spacing 0.6, uppercase: `TYPE · TIME` or `TYPE · ALL DAY`.
  - Title, 15 sp, weight 700.
  - Subtitle, 13 sp, `#5B6178`.
  - Chevron on the right.
- Two buttons stacked (gap 10), each 52 dp high, radius 16, outlined (`#B9BED2` border, `#283593` text):
  1. `Add interview` (plus icon)
  2. `Add job application` (briefcase icon)

Container: white, top radius 28, padding 12 / 20 / 24, over a 50% scrim (`rgba(27,30,43,0.5)`). Max height 75% of the screen; the event list scrolls, the buttons stay visible.

**Empty day (18b):** header subtitle `No events`, a 64 dp circle with a calendar icon, text "Nothing scheduled" and "No interviews, follow-ups or application updates on this day.", then the same two buttons.

### Row content by type

| Type | Left edge / label colour | Label | Title | Subtitle |
|---|---|---|---|---|
| Interview | `#8E24AA` / `#6A1B80` | `INTERVIEW · 10:00 AM` | Interview name, e.g. "Technical interview · Round 2" | Company · mode (Video call, On-site, Phone) |
| Follow-up | `#00897B` / `#00695C` | `FOLLOW-UP · 2:00 PM` | Reminder title | Company · job role |
| Status change | `#FFA000` / `#7A4B00` | `STATUS CHANGE · ALL DAY` | Job role | Company · "Moved to {Status}" |
| Applied | `#1E88E5` / `#0D47A1` | `APPLIED · ALL DAY` | Job role | Company · "via {source}" if known |

Colour is never the only signal: every row also carries its text label.

### Ordering

1. Timed items (interviews, follow-ups with a time) sorted by time, earliest first.
2. All-day items: Applied, then Status change, sorted by company name.
3. Ties are broken by id so the order is stable.

## 3. Behaviour

| Action | Result |
|---|---|
| Tap a date (any view) | Select the date (filled indigo circle) and open the sheet |
| Tap an event row | Close the sheet and open **Application detail** for that job. For an interview row, the detail page scrolls to that interview and highlights it for about 2 seconds |
| Tap `Add interview` | Open the Add interview form with the date prefilled |
| Tap `Add job application` | Open the Add/Edit application form with `appliedDate` prefilled (see rule below) |
| Tap close, the scrim, or swipe down | Close the sheet. The date stays selected |
| Back from a detail page | Return to the calendar with the date still selected. The sheet stays **closed** |
| Save a new interview or application | The calendar dots and any reopened sheet refresh immediately |

Rules:
- Add interview: the form's date is the tapped date. If the user has no applications yet, the form shows its existing "add a job first" empty state.
- Add job application: if the tapped date is today or in the past, `appliedDate` = tapped date. If it is in the future, `appliedDate` = today (an application cannot have been sent in the future).
- Month view: tapping a muted day from the previous or next month changes the visible month to it and opens the sheet.
- Tapping the already selected date opens the sheet again.
- The **Today** button jumps to today and does not open the sheet.

## 4. Data

No new endpoint is required. The calendar already loads events for the visible range to draw the dots, and the sheet filters that list for the tapped date.

Client model (one entry per dot/row):

```dart
enum CalendarEventType { interview, followUp, statusChange, applied }

class CalendarEvent {
  final String id;
  final CalendarEventType type;
  final DateTime date;        // local date
  final DateTime? time;       // null = all day
  final String title;
  final String subtitle;
  final String applicationId; // always set
  final String? interviewId;  // set for interview rows
}
```

Provider: `calendarDayProvider(DateTime date)` returns the sorted `List<CalendarEvent>` derived from `calendarRangeProvider`. If the range data for the date is not loaded yet (fast navigation), show a loading state in the sheet and fetch it.

Dates are compared in the user's local time zone. Server timestamps are UTC ISO strings (see API.md), so convert before bucketing into days. `appliedDate` is a plain date and is not converted.

## 5. Flutter implementation notes

- Open with `showModalBottomSheet` (`isScrollControlled: true`, `useSafeArea: true`, rounded top shape, constrained to 75% height). Content is a `Column` with the header, an `Expanded`/`Flexible` scrollable list, and the pinned buttons.
- Routes (go_router):
  - `/applications/:id?focusInterview=:interviewId` for event rows.
  - `/interviews/new?date=YYYY-MM-DD` for Add interview.
  - `/applications/new?appliedDate=YYYY-MM-DD` for Add job application.
- Close the sheet before navigating (`Navigator.pop` then `context.push`) so Back returns to the calendar, not the sheet.
- Highlighting the interview: the detail screen reads `focusInterview`, scrolls with `Scrollable.ensureVisible`, and animates the card background for about 2 seconds.
- Dot colours come from one place in the theme: Applied `#1E88E5`, Status change `#FFA000`, Interview `#8E24AA` (dot size 8, others 6), Follow-up `#00897B`, Rejected `#E53935`.
- Remove the day agenda widget from the Calendar screen and its legacy provider if nothing else uses it.

## 6. Accessibility

- Sheet is announced as a dialog with the label `Events on {weekday, day month year}`. Focus moves to the header on open and returns to the tapped date on close.
- Every row is one button with a combined label, e.g. "Interview, 10:00 AM, Technical interview round 2, Northwind Labs".
- All touch targets at least 48 dp (rows 64, buttons 52, close 48).
- Respect reduced-motion settings: use a fade instead of a slide.

## 7. Design deltas to apply

- **Calendar screen**: remove the "Tuesday, 27 Oct" agenda section; keep Job timeline. Update the legend and dots to use teal for Follow-up.
- **DESIGN.md**: update the status/event colour table (Follow-up `#00897B`, text `#00695C`) and replace the Calendar day-agenda description with a link to this file.
- **Floating "Interview" button on the Calendar screen**: keep it. With no date tapped it adds an interview for today.

## 8. Tests

Unit:
- `calendarDayProvider` ordering: timed before all-day, earliest first, stable ties.
- Time-zone bucketing: an interview at 23:30 UTC lands on the correct local day.
- `appliedDate` rule for past, today and future dates.

Widget:
- Tapping a date opens the sheet with the right title and count (`1 event`, `N events`, `No events`).
- Empty state shows the message and both buttons.
- Each row type shows the correct label and colour.
- Tapping an interview row navigates with `focusInterview` set.
- Both buttons pass the correct date.
- Sheet closes on scrim tap and the date stays selected.

Manual: a day with 8+ events (list scrolls, buttons stay visible), month navigation, 2-week and Week views, large text scale (1.5x), screen reader pass.

## 9. Build order

1. Remove the day agenda; switch Follow-up to teal everywhere.
2. `CalendarEvent` model and `calendarDayProvider`.
3. Sheet widget with the empty state.
4. Wire date taps in all three views.
5. Navigation and prefill for the two buttons.
6. Interview highlight on the detail page.
7. Tests and the manual pass.
