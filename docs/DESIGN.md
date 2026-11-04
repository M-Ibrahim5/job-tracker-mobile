# JobTrail — Design Spec

Source of truth for UI. Mockups (private link, owner only): https://claude.ai/artifact/GEjtcZNDJ6jDyfzaJwsFTj
All mockups are 390×844 phone, light theme. Dark theme = same structure using Material 3 dark scheme from the same seed.

Sample data in mockups is illustrative only. Real data comes from the API (`API.md`).

---

## 1. Design principles

- Calm and professional: soft indigo, rounded cards, generous spacing.
- Material 3. Font: **Plus Jakarta Sans** (use `google_fonts`, or bundle the font). Fallback: system.
- Status is never color alone: always **color + icon + text label**.
- Touch targets ≥ 48dp. Text contrast ≥ 4.5:1. Every list/screen has loading (skeleton), empty and error states.
- Phone portrait first. Must not overflow at large text scale (use `Flexible`/`Wrap`, ellipsis on single-line titles).

## 2. Design tokens

### Colors (light)

| Token | Hex | Use |
|---|---|---|
| `seed` / primary | `#3F51B5` | Buttons, FAB, selected, links. **Single constant `kSeedColor`** |
| primaryContainer | `#E3E7FA` | Selected chips, nav indicator, tonal buttons |
| onPrimaryContainer | `#283593` | Text/icons on primaryContainer |
| background | `#F6F7FB` | Screen background |
| surface | `#FFFFFF` | Cards, inputs, nav bar |
| outline (cards) | `#E6E8F0` | 1px card border |
| outline (inputs) | `#B9BED2` | 1px input / segmented border |
| divider | `#EEF0F6` | List dividers |
| text | `#1B1E2B` | Primary text |
| textSecondary | `#4A4F66` / `#5B6178` | Secondary text |
| placeholder | `#6B7088` | Hints |
| error | `#B3261C` | Errors, destructive, unread badge bg |
| warningContainer | `#FFF1D0` (text `#4A3000`) | Notices/banners |

### Status styles (`StatusStyle` in `app/theme`)

| Status | Accent (dots, chart) | Chip bg | Chip text | Icon (Material equivalent) |
|---|---|---|---|---|
| Applied | `#1E88E5` | `#E3F0FC` | `#0D47A1` | `send_rounded` |
| Screening | `#FFA000` | `#FFF1D0` | `#7A4F00` | `manage_search_rounded` |
| Interview | `#8E24AA` | `#F1E3F7` | `#6A1B80` | `groups_rounded` |
| Offer | `#43A047` | `#E0F2E1` | `#1B5E20` | `workspace_premium_rounded` |
| Rejected | `#E53935` | `#FDE3E1` | `#B71C1C` | `cancel_rounded` |
| Follow-up (calendar) | `#00897B` (teal; orange clashed with Screening) | — | text `#00695C` | — |

Chip text colors are darker than accents to meet contrast; use accents for dots/charts/fills, chip text colors for text.

### Typography (Plus Jakarta Sans)

| Role | Size / weight |
|---|---|
| Screen title (H1) | 26 / 800, letter-spacing -0.5 |
| Auth title | 30 / 800 |
| Section title (H2) | 17 / 700 |
| Eyebrow (group label) | 13 / 800, uppercase, letter-spacing 0.6, `textSecondary` |
| Card title | 15–16 / 700 |
| Body | 14–15 / 500 |
| Caption | 12–13 / 600 |
| Button | 15–16 / 800 |
| Big stat | 34 / 800 |

### Spacing and shape

- Spacing scale: 4 / 8 / 12 / 16 / 24. Screen horizontal padding **20**. Gap between sections **24**. Card inner padding 12–18.
- Radii: cards 16–20 (summary card 24), inputs 14, buttons 14–16, chips 12 (status pill: full), FAB 18, avatar full.
- Elevation: none on cards (border only). FAB shadow `0 6 16 rgba(63,81,181,.35)`.

## 3. Shared components

| Component | Spec |
|---|---|
| `StatusChip` | Pill, icon 14 + label 12/700, per status table. Already exists in `core/widgets`. |
| Bottom nav | Floating, icon-only pill (`NavigationBar` inside a stadium-shaped, elevated card; 64 high, 16 side margin). **No text labels** (labels remain as tooltips/semantics). 5 tabs: Dashboard, Applications, Calendar, Alerts, Settings. Selected = filled primary circle with white icon. Alerts shows red unread badge (count; hide at 0; "9+" cap). |
| Text field | Label above (13/700), required marker red `*`, outlined 52–54 high, radius 14. Focus border 2px primary. Error border 2px `error` + icon + message (12/600) below. |
| Segmented control | 3 options (work arrangement, theme, calendar format): outlined, selected = primaryContainer + check icon + bold. |
| Choice chips | 40 high, radius 12; selected = primaryContainer + check icon. Multi-select used for reminder offsets. |
| Primary button | 52–56 high, radius 16, primary fill, white 800 text. Secondary = outlined `#B9BED2`. Destructive = outlined `error` 2px. |
| Form footer | Pinned bottom bar: Cancel (outlined) + Save (filled), white, top border. |
| Notice banner | `warningContainer`, icon + text + action button (40 high). |
| FAB | Extended, 56 high: icon + label ("Add", "Interview"), above the nav bar at right 20. |
| Switch | Material 3 switch (52×32); off state has visible outline. |
| Date block | 52×56 tonal tile: day (20/800) over month (12/700) — interviews use Interview colors. |

---

## 4. Screens

Route names in brackets. "Nav" = shows bottom navigation.

### 4.1 Login [`/login`] (no nav)
- Logo tile (48, primary) + "JobTrail". H1 "Welcome back", subtitle.
- Fields: Email (leading mail icon), Password (leading lock, trailing show/hide). "Forgot password?" right-aligned link.
- Primary "Sign in". Divider "or".
- **Social buttons ("Continue with Google/Apple") and "Continue without an account" are in the mockup but OUT OF SCOPE for v1** (MySQL backend, email+password only). Do not build them (see §6).
- Footer: "New to JobTrail? **Create account**" → `/register`.
- Errors: wrong credentials → inline banner above button; network error → snackbar.

### 4.2 Register [`/register`] (no nav)
- Back arrow, H1 "Create your account".
- Fields: Full name, Email (inline validation), Password (show/hide, 4-segment strength meter + label Weak/Fair/Good/Strong, hint "At least 8 characters with a number and a symbol"), Confirm password.
- Terms checkbox ("I agree to the Terms and Privacy Policy"), required to enable submit.
- Primary "Create account". Footer "Already have an account? Sign in".
- On success: auto-login → `/` (or onboarding on first launch).

### 4.3 Dashboard [`/`] (nav)
Order top to bottom (scrollable, pull-to-refresh, skeletons while loading):
1. Header: date line ("Saturday, 24 Oct"), H1 "Good morning, {firstName}" (morning/afternoon/evening), square 48 "+" button → new application.
2. **Summary card** (primary fill, radius 24, white text): 3 stats — Applications (total), Active (not Rejected/Offer), Response rate (% moved past Applied) + progress bar.
3. **By status**: 5 equal tiles (icon, count, label), each in its status chip colors; tap → Applications list pre-filtered by that status.
4. **Pipeline**: donut (`fl_chart`, ring 20 thick) with total in center + legend list (swatch, name, count).
5. **Applications per week**: bar chart, last 8 weeks, counts above bars, current week in primary, others `#C5CBEF`; axis labels start-week and "This week".
6. **Upcoming interviews** (next 3): date block, title (ellipsis), "Company · time · type"; "See all" → calendar/interviews. Tap → interview detail.
7. **Recent activity** (last 5 status changes): status-colored icon tile, "Moved **Company** to Status", relative time ("2h ago", older = date).
- Empty state (no applications): illustration + "Add your first application" button.

### 4.4 Applications list [`/applications`] (nav)
- H1 + "{n} total". Search field (title, company, location) + square filter/sort button (opens bottom sheet: status multi-select, work arrangement, date range, sort: Newest, Oldest, Company A–Z, Status).
- Horizontal filter chips row: All + statuses.
- Caption row: "Sorted by newest first".
- Cards: title (16/700, ellipsis), "Company · Location", applied date (top right), status chip + work arrangement tag; optional right-aligned hint: "Next: 27 Oct" (purple) or "Follow up 25 Oct" (orange).
- **Swipe right → change status** (reveals primary panel with "Status"; opens status bottom sheet). **Swipe left → delete** with confirm dialog then Undo snackbar (client delays the real `DELETE` call until the snackbar closes).
- Extended FAB "Add" → `/applications/new`.
- Infinite scroll/pagination (page size 20). Empty (no results vs no data) and error states.

### 4.5 Application detail [`/applications/:id`] (no nav)
- App bar: back, edit, delete (red).
- Header: status chip, title (26/800), company, info chips: location (pin icon), arrangement, employment type, salary.
- **Quick actions** (3 tonal tiles, 72 high): Open link (url_launcher; snackbar on failure), Interview (add), Follow-up (set follow-up date).
- **Status**: 5-button selector (icon + label); current = 2px status-colored border + container; next-in-flow = dashed outline; helper text "Dashed outline marks the next step… Any status can be set at any time." Choosing opens a bottom sheet with optional note, then confirms.
- **Status timeline**: vertical, status-colored circle icon, "From → To", timestamp, optional note box. Newest on top; first entry "Applied · date · via {source}".
- **Interviews**: list rows (date block, title, "time · type · duration", outcome pill) + "+ Add".
- **Job description**: card, first paragraph(s) + 3-line clamp + "Read more" (expand inline). Up to 10,000 chars.
- **Details**: definition list — Applied on, Source, Contact (name + email, tap to mail), Follow-up (date or "Not set").
- **Notes** card.

### 4.6 Add / edit application [`/applications/new`, `/applications/:id/edit`] (no nav)
- App bar: close, title "New application"/"Edit application", "Save" text button.
- Fields in order: Job title*, Company*, Location*, Work arrangement* (segmented On-site/Hybrid/Remote), Employment type (chips), Applied date* (picker, default today) + Source (dropdown) side by side, Salary range, Application link, Job description (multiline min 140, counter "0 / 10,000"), Contact name + Contact email side by side, Notes, **Follow-up reminder** switch row ("Remind me on {date} if no reply"; date from default follow-up days in settings).
- Validation (inline, on blur and submit): required fields trimmed ≤100; link must be http(s); appliedDate ≤ today+1 day; email valid; JD ≤ 10,000.
- Footer Cancel/Save. Back with unsaved changes → confirm dialog.

### 4.7 Calendar [`/calendar`] (nav)
- H1 + "Today" button. Format segmented: **Month | 2 weeks | Week** (remember last choice locally).
- `table_calendar`, week starts Monday. Month header with chevrons. Today = 2px primary ring; selected = primary fill. Dots under day numbers (max 3): applied (blue 6), status change (status accent 6), interview (purple **8**, emphasized), follow-up (teal 6). Legend row below grid.
- **Day events**: tapping any date opens a bottom sheet with that day's events and the Add interview / Add job application buttons. See [features/FEATURE-CALENDAR-DAY.md](features/FEATURE-CALENDAR-DAY.md). There is no inline day agenda; the Job timeline section stays.
- **Job timeline mode**: picker "Company ▾" to select an application; shows vertical list Applied → Screening → Interview → upcoming rounds with dates; those dates are highlighted on the calendar.
- Extended FAB "Interview" → add interview with date prefilled to selected day.

### 4.8 Add / edit interview [`/applications/:id/interviews/new`, `/interviews/new?date=`, `/interviews/:id/edit`] (no nav)
- Fields: Application* (picker; locked when opened from an application), Title*, Type* (7 chips: Phone, Video, On-site, Technical, HR, Final, Other), Date* + Time* (pickers), Duration (30/45/60/90, default 60), Meeting link or address, Interviewer, **Remind me** (multi-chips: 1 day before ✓, 1 hour before ✓, 15 min before, + Custom; defaults come from settings), Prep notes.
- Past date → non-blocking warning. Same application + same exact time → blocking error (server 409 `INTERVIEW_CONFLICT`).
- **Status suggestion card** (warning color) shown when this is the first interview and application status is Applied/Screening: "Move {company} from {status} to Interview?" [Yes, move it] [Not now]. Offered, never forced.
- Footer Cancel/Save.

### 4.9 Notification center [`/notifications`] ("Alerts", nav)
- H1 + text actions "Mark all read", "Clear all" (confirm).
- Permission banner when OS notifications are denied: "Phone reminders are off…" + "Enable" (opens system settings).
- Groups: Today / Yesterday / Earlier (eyebrow labels); each group is one rounded card of rows. Row: 40 tonal icon tile by type, title (800 if unread), body, caption "time · Type", unread dot (10, primary) and light tint background when unread. Tap → mark read + deep link to the interview/application. Swipe to delete.
- Type icon/colors: statusChange (new status colors), interviewReminder (purple, calendar icon), followUpReminder (teal `#D3F0EC`/`#00544C`, clock icon), system (primary tonal, info icon).
- Empty state: "You're all caught up".

### 4.10 Settings [`/settings`] (nav)
Top to bottom:
1. H1 "Settings".
2. **Profile card**: 64 avatar (initials on primary, or photo), name 18/800, email, "role · location", tonal "Edit profile" button → `/settings/profile`.
3. **Account**: Personal details (→ edit profile), Change password (dialog/screen: current, new, confirm).
4. **Appearance**: Theme segmented System / Light / Dark.
5. **Notifications**: switches — Interview reminders, Follow-up reminders, Status changes; chips "Default interview reminders" (1 day, 1 hour, 15 min; multi); chips "Default follow-up after" (Off, 3, 5, 7, 14 days; single).
6. **Data**: Export data (JSON/CSV share sheet), Delete all data (red; double confirmation: dialog 1, then type "DELETE").
   - *"Import backup" was removed from the design — do not build import.*
7. **About**: "About JobTrail — Version x.y.z".
8. **Log out**: full-width red outlined button + caption "Signed in as {email}". Confirm dialog, then revoke refresh token, clear secure storage, cancel all local notifications, go to `/login`.

### 4.11 Edit profile [`/settings/profile`] (no nav)
- App bar: back, "Edit profile", "Save".
- Avatar 96 with camera button + "Change photo" (image_picker → `POST /me/avatar`).
- Fields: Full name* (focused style), Email (read-only, "Verified" badge, helper text), Phone, Current role, Looking for, Location.
- "Delete account" red text button (confirm → `DELETE /me` → login).
- Footer Cancel/Save.

---

## 5. Navigation map

```
/login ⇄ /register
(auth) → [Shell: / | /applications | /calendar | /notifications | /settings]
/applications → /applications/new
/applications/:id → /applications/:id/edit, /applications/:id/interviews/new
/interviews (upcoming/past tabs), /interviews/:id, /interviews/:id/edit
/settings → /settings/profile
/onboarding (first launch, 3 slides + notification permission)
```
Redirect rule: unauthenticated → `/login`; authenticated visiting `/login`|`/register` → `/`. Notification tap deep-links to `/interviews/:id` or `/applications/:id`.

## 6. Deltas between mockups and the build (read this)

1. Remove Google/Apple buttons and "Continue without an account" from Login (not in v1).
2. "Import backup" removed from Settings (already removed in mockup).
3. Settings "Change password" and the logout confirm dialog, status bottom sheet, filter/sort sheet, onboarding and Interviews list are specified in text above but not drawn — build them with the same tokens/components.
4. Dashboard "+" header button goes to new application (mockup links to list).
5. The "Settings" tab and all links in the mockup are navigable prototypes only.

## 7. Accessibility checklist

- `Semantics` labels on icon-only buttons (back, edit, delete, show password, filter, change photo, nav badge "3 unread").
- Chart alternatives: donut and bar charts have text summary semantics ("5 applied, 3 screening…").
- Form: associate labels; error text announced; never rely on border color alone (icon + text present).
- Minimum 48dp targets, even for text links (use `minimumSize`/padding).

## 8. As built (deviations agreed during implementation)

1. **Status suggestion** (§4.8) is a dialog shown on Save for a *new* interview (Applied/Screening, first interview), not an inline card in the form. Yes = create + move to Interview, Not now / dismiss = create only.
2. **Large text.** Below 320 px or above text scale 1.2 some rows re-flow instead of shrinking: outcome pills sit under the title, the banner action goes under its message, side-by-side form fields stack, the segmented control drops its check icon (tonal fill + bold label remain), and at ×1.8+ the list's "Sorted by …" caption is hidden.
3. **Dashboard.** The empty-state title is "Start tracking your job search" (the button keeps "Add your first application"). Weekly bars are drawn with plain widgets; the donut uses `fl_chart`.
4. **Calendar.** Month view fetches a month with one padded request; the header title is a 48 dp target; the chevrons carry "Previous" / "Next" labels.
5. **Follow-up default.** The new-application form starts with the follow-up switch on (today + the default-days setting) and disables it when that setting is Off.
6. **FABs** use no Hero (`heroTag: null`): several tabs stay mounted at once and shared tags crash route transitions.
7. **Launcher icon / splash** (white briefcase on `#3F51B5`, same mark as the Login logo tile) live in `app/assets/branding/` and are generated with `flutter_launcher_icons` / `flutter_native_splash`.
