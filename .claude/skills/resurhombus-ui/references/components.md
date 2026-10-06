# Component Catalog

Shared components live in `lib/ui/components/`. Each takes plain data and callbacks, with no providers inside, so it can be previewed and tested on its own.

## Contents
- Brand & primitives: RhombusMark, ScoreBadge, DiagonalDivider, GeometricBackground
- Candidate: JobCard, SwipeDeck, DeckActionBar, UndoToast, PassReasonChips, RadarDeepDive, PipelineTimeline, StatusChip, PrismUploadProgress, SkillReviewList
- Recruiter: CandidateTile, MosaicGrid, TriangleActions, RequirementEditor, CompanyBadge
- Shared: RoleChoiceCard, EmptyState, ShimmerShape

---

## Brand & primitives

### RhombusMark
- A rhombus drawn with `CustomPainter` (a square rotated 45° and squashed to 0.8 height). Variants: filled, outlined, dashed.
- Used for the logo, ScoreBadge, avatar placeholder, and the blind candidate handle.
- Prefer `ShapeBorder` subclasses (`RhombusBorder`) so it works with `Material`, `Ink`, and `ClipPath`.

### ScoreBadge
- **Anatomy:** a rhombus with the number (`titleLarge`, tabular figures) inside, and the band label (`labelSmall`, uppercase) below or beside it.
- **Visuals by band:** see `tokens-and-theme.md` §1.
- **Sizes:** small (32 px, on tiles), medium (48 px, on cards), large (96 px, on Deep-Dive). The large size counts up from 0 over 600 ms on first show (skipped under reduced motion).
- **Semantics:** `"Match score 87 percent, Strong"`.

### DiagonalDivider
- A 1 px `framework` line at 12°, or a 6 px `match` accent stripe for section headers. Keep it decorative: wrap it in `ExcludeSemantics`.

### GeometricBackground
- Drifting wireframe rhombuses and hexagons in `framework` at 25–40% alpha, 1 px stroke, 6–10 shapes per screen.
- **Performance:** a single `CustomPainter` driven by one `AnimationController` (period about 60 s, `repeat()`), wrapped in a `RepaintBoundary` and placed **behind** content in a `Stack`. Never rebuild the widget tree per frame. Pass the animation to `CustomPainter(repaint: controller)`.
- Pause it when `MediaQuery.disableAnimationsOf(context)` is true, or when the app goes to the background (`AppLifecycleListener`). Render one static frame instead.

---

## Candidate

### JobCard
- **Surface:** `deck`, radius `lg`, shadow `e2`, padding `xl`, aspect about 3:4, max width 440.
- **Content top to bottom:**
  1. Company logo (or a RhombusMark with the company initial) plus the company name (`titleMedium`), and CompanyBadge if unverified.
  2. Job title (`titleLarge`, max 2 lines).
  3. Meta row with icons: location or remote, job type, salary range.
  4. ScoreBadge (medium), aligned to the top right of the card.
  5. Top 3 matched skills as chips (`surface` background, `ink` text). Up to 2 gaps as outlined chips with a `pass` "missing" dot.
  6. A "Tap for details" affordance with a small rotating rhombus icon.
- **Text is always `ink`** because of `deck` contrast.
- **The "Invited" variant** (Phase 2) has a 6 px `match` diagonal ribbon across the top-left corner with the label "INVITED".
- **Drag overlays:** as the card drags right, a `match` stamp "APPLY ✓" fades in at the top-left, with opacity = drag progress. Dragging left shows a `pass` stamp "PASS ✕" at the top-right. The stamps are rotated −12° and +12°.

### SwipeDeck
- Shows 3 visible cards. Back cards are scaled 0.94 and 0.88, offset 10 px and 20 px down, with resting tilts alternating −3° and +2°, using `deckDeep` for depth.
- Prefetch when 5 or fewer cards remain (cursor pagination from `get_feed`).
- Physics are in `motion-and-a11y.md`. Use the custom gesture approach, or `flutter_card_swiper` if it can render the tilted stack.
- **Empty state:** EmptyState with a stacked-rhombus illustration, the text "Your deck is all squared away", and two actions: "Widen filters" and "Update resume".

### DeckActionBar
- Shown under the deck. A large circular ✕ button (`pass` outline and icon), a smaller ⓘ button (opens Deep-Dive), and a large ✓ button (`match` filled, white icon).
- Minimum 56 px each. Spaced evenly, within thumb reach.
- These are the accessible equivalent of swiping (PRD C-SW and §3.2). Never hide them.

### UndoToast
- Appears after a right swipe. A bottom `SnackBar`-style bar with the text "Applied to {title}" and an "Undo" action in `matchStrong`, plus a 5 s linear progress line along the bottom edge.
- Shows the real remaining time from the server's `committed_at`, not a local guess.

### PassReasonChips
- A bottom sheet that appears for 3 s after a left swipe, or an inline row under the deck. Chips: Location · Salary · Stack · Seniority · Company.
- Tapping one sends it and closes. Ignoring it does nothing. The chips must never block the next swipe.

### RadarDeepDive
- **Opening:** from JobCard as a hero transition. Use a flip (Y-axis rotation) on compact layouts, or an inline side panel on expanded layouts.
- **Chart:** `fl_chart` `RadarChart`.
  - Job polygon: `framework` stroke at 2 px with no fill, at value 1.0.
  - "You" polygon: `match` stroke at 2 px with `match` fill at 25% alpha.
  - Grid: `framework` at 50% alpha, 4 rings. Tick labels hidden.
  - Axis titles: `labelSmall` in `ink`, truncated at 14 characters.
- **Axes:** 3–8 required skills, otherwise category groups (PRD §5.3). Fewer than 3 axes falls back to horizontal bars.
- **Below the chart:** Gap list with ✓ (match), ◐ (partial, `stretch`), and ✕ (missing, `pass`) icons and plain-language text ("AWS: 1 of 3 years").
- **Accessibility:** The chart is decorative for screen readers. The gap list is the accessible version of the same data, so make sure it's complete.
- The same widget is reused on the recruiter candidate detail view, with the "You" legend replaced by "Candidate".

### PipelineTimeline & StatusChip
- **Status to style:**
  - Applied: `framework` outline
  - Under Review: `deck` fill
  - Interview Requested: `match` fill, white text, ▲ icon
  - Not Selected: `pass` outline, `pass` text, neutral icon, never alarming
  - Withdrawn: `inkMuted`
  - Job Closed: `inkMuted` with strikethrough
- **Timeline:** a vertical diagonal-segment connector. Each node is a small rhombus, filled when reached.
- Updates live through Realtime. Animate new statuses with a 250 ms fade and slide.

### PrismUploadProgress
- A rhombus "prism" that splits a white beam into the palette colors as parsing progresses. Steps: Uploading, Reading layout, Extracting skills, Matching taxonomy, Ready.
- **Driven by the real `resumes.status` from Realtime.** Don't use a fake timer. The animation idles between steps.
- **Errors:** inline `passTint` banner with the reason and two actions, "Try another file" and "Add skills manually" (the PRD fallback).

### SkillReviewList (Review & Confirm)
- Rows show the skill name, a years stepper (0.5 steps), and an evidence icon that opens a sheet showing the source snippet. Swipe left or use a ✕ icon to remove a row.
- Rows the user has edited show a small "edited" pencil badge.
- "Add skill" opens a taxonomy search. The sticky footer CTA is "Looks right, start swiping" (`match` filled).

---

## Recruiter

### MosaicGrid
- Responsive grid: 1 / 2–3 / 3–5 columns by breakpoint, tile min width 260, gap `lg`.
- **Sorted strictly by score.** The grid never reorders on hover. When a tile is removed, the remaining tiles animate into place (`AnimatedList`-style, or `ImplicitlyAnimatedReorderableList`-style using keys).
- **Header:** job title, applicant count, filter chips (narrowing only), and a sort label fixed to "Sorted by Match".
- **Optional stagger:** offset every other row by half a tile to suggest interlocking shapes. Only on expanded layouts, and only if it doesn't hurt scanning.

### CandidateTile (blind)
- **Surface:** `surface`, radius `lg`, shadow `e1`, rising to `e2` on hover or focus.
- **Content:** a RhombusMark avatar with the handle "◆ 4F2A", ScoreBadge (small), total years, top 3 matched skills, and up to 2 gaps.
- **No name, photo, school, or resume link until advanced** (R-TRI-1). Don't add them "just for the demo".
- **Interaction:** hover or tap reveals TriangleActions. Clicking the body opens the detail view (status changes to UNDER_REVIEW). There's a visible focus ring (`matchStrong`, 2 px) for keyboard triage.

### TriangleActions
- Two right triangles that share the tile's diagonal. ▲ Advance is at the bottom-right (`match`) and ▼ Reject is at the top-left (`pass`). On hover they slide in from the corners over 150 ms.
- Each triangle has a white icon and a tooltip ("Advance to interview", "Not a fit"). The hit area is at least 48×48 even though the visible triangle is smaller.
- **Touch:** tapping a tile toggles the triangles. They must never trigger from a single accidental tap on the body.
- **Reject** shows a 10 s undo SnackBar (R-TRI). **Advance** gives a brief `match` flash and the tile flies to the "Interview" list.

### RequirementEditor (Job provisioning review)
- A table of extracted skills with columns for skill, Required/Preferred toggle, min years stepper, and weight (shown as 1–3 rhombus pips).
- Shows counters "8/8 required" and "12/15 total". The over-limit state disables the toggle and explains why.
- A raw JD panel sits beside the table (expanded) or in a collapsible section (compact). Selecting a requirement highlights its evidence in the JD.

### CompanyBadge
- Verified: a small `match` rhombus check plus "Verified".
- Unverified: a `framework` outline plus "Unverified" in `inkMuted`, with a tooltip that explains what it means.

---

## Shared

### RoleChoiceCard (Sign-up, PRD §4)
- Two large equal cards: "I'm looking for a job" (a JobCard-stack illustration in `deck`) and "I'm hiring" (a mosaic-tile illustration in `match`).
- The selected card gets a `matchStrong` 2 px border plus a check rhombus. Neither card is pre-selected, except via the `/recruiter` URL.

### EmptyState
- A geometric illustration (composed rhombuses and triangles in `framework` and `deck`, max 160 px), one `titleMedium` line, one `bodyMedium` line, and at most one primary action.

### ShimmerShape
- Loading placeholders in the shape of the real content (a card outline, tile outlines). A `framework` base with a diagonal 12° highlight sweep over 1.2 s. Static under reduced motion.
