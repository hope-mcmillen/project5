---
name: resurhombus-ui
description: UI/UX design and Flutter implementation specialist for the ResuRhombus app's geometric, card-based design system (Canvas/Framework/Deck/Match/Pass palette, rhombus and triangle motifs, swipe deck, radar chart, recruiter Mosaic tile grid). Use this skill whenever building, styling, reviewing, or critiquing any screen, widget, theme, animation, layout, icon, color, typography, empty state, or responsive behavior in this project, even if the user just says "make this look better", "build the job card", "add the recruiter board", or "fix the swipe animation". Also use it for accessibility and contrast questions and for turning a PRD flow into screens.
---

# ResuRhombus UI

You design and build the ResuRhombus interface in Flutter. The product wants a job hunt that feels **playful and geometric** but stays **clean and professional**. Think tactile cards, interlocking shapes, diagonal energy, and lots of calm whitespace. Every visual choice should support one of two jobs: helping a candidate decide on a job in seconds, or helping a recruiter triage applicants in seconds.

The product source of truth is `docs/PRD.md`. Read the relevant flow before designing a screen: §3 is the design system, §4 is sign-up, §5 is the candidate experience, and §6 is the recruiter experience. If a design decision changes a requirement, say so, so the PRD can be updated. Don't silently diverge from it.

## Reference files (read when needed)
- `references/tokens-and-theme.md` has the full token table and the Dart `ThemeData` / `ThemeExtension` implementation. **Read it before writing any styling code.**
- `references/components.md` is the component catalog: the job card, swipe deck, score badge, radar, recruiter tile, triangle actions, geometric background, and more, with anatomy, states, and implementation notes. Read the entry for any component you touch.
- `references/motion-and-a11y.md` covers swipe physics, durations and curves, reduced motion, contrast math, and TalkBack. Read it for any animation or accessibility work.

## Core principles

1. **Tokens, never literals.** Colors, spacing, radii, and durations come from the theme (`context.rr.*` and `Theme.of(context)`). A hex literal or a magic `EdgeInsets.all(13)` in a widget is a bug. With one source of truth, a palette tweak is a one-line change, and dark mode can be added later.
2. **Color carries meaning, so protect it.** Teal (`match`) always means *yes, advance, apply, or strong fit*. Crimson (`pass`) always means *no, reject, or destructive*. Don't use them for decoration, or users stop trusting the signal. Sky blue (`deck`) belongs to job cards. Gray (`framework`) is for structure and inactive elements.
3. **Never use color alone.** Pair every color signal with an icon, shape, or label (✓ / ✕, ▲ / ▼, a "Strong" text band). This helps colorblind users and makes the UI easier to read at a glance.
4. **Geometry has a grammar.** Use these consistently so the motifs feel designed and not random:
   - **Rhombus**: identity and score. Used for the brand mark, score badge, avatar placeholder, and anonymous candidate handle "◆ 4F2A".
   - **Triangle**: decisive recruiter actions (▲ advance, ▼ reject).
   - **Diagonal lines**: section dividers, header accents, and progress. Use one angle across the app: **12°**.
   - **Hexagon and rhombus wireframes**: background only. Low contrast and slow moving.
   - Corners are mostly crisp: radius 4–12. Pill shapes are for chips only. Avoid soft blobs, because they fight the geometric identity.
5. **Calm canvas, lively cards.** The background stays quiet (`canvas` plus faint wireframes) so the cards can tilt, lift, and fly. If a screen feels busy, take decoration away from the background first.
6. **Every screen has four states.** Design loading (shimmer in the shape of the content, not a lone spinner), empty (a geometric illustration, one sentence, and one action), error (what happened and a retry), and content. The PRD calls out several empty and error states, such as an empty deck, a failed parse, and a board with no applicants.
7. **The UI never blocks on the AI.** Parsing and scoring are asynchronous. Show progress (the prism animation), let users leave the screen and come back, and update through Realtime.
8. **Buttons as well as gestures.** Every swipe has a tappable equivalent, and every hover action has a tap or long-press equivalent. This is both an accessibility requirement and a must on Android (§3.2 of the PRD).

## Workflow for building or redesigning a screen

1. **Locate it in the PRD.** Find the flow and its requirement IDs (e.g., C-SW-2, R-TRI-1). List the data the screen shows and the actions it offers.
2. **Sketch the structure before code.** Write a short ASCII or bullet layout covering the compact (phone) and expanded (≥ 900 px web) layouts, plus the four states. For anything non-trivial, show it to the user and confirm before writing a lot of code.
3. **Build from the catalog.** Reuse components from `lib/ui/components/` (see `references/components.md`). If a new pattern appears twice, extract it into a component.
4. **Keep widgets presentational.** Screens get data from Riverpod providers. Components take plain values and callbacks, which makes them easy to preview and test. Put new files under the feature folder (`lib/features/<feature>/presentation/`) or under `lib/ui/` for shared design-system pieces.
5. **Check it:**
   - Run the contrast checklist in `references/motion-and-a11y.md`.
   - Check text scale at 1.3× and 2.0× (no clipping or overflow).
   - Check with animations disabled.
   - Check at 360 px wide (small Android) and at 1280 px for recruiter screens.
   - Write a widget test for the states, and a golden test for core visuals (job card, score badge, tile) if goldens are set up.
6. **Look at it.** When possible, run it with `flutter run` on the Android emulator or `-d chrome` for recruiter screens, and take a screenshot rather than assuming it looks right.

## Reviewing or critiquing UI

When asked to review, organize feedback as **blocking**, then **should fix**, then **polish**. Cite the principle each item breaks. Common issues to check for:
- White text on `deck` sky blue. It's about 1.9:1 and unreadable. Use `ink`.
- Small white text on `match` teal. Use `match-strong` or make the text large and bold.
- Teal or crimson used for decoration.
- Hardcoded colors or spacing.
- Hover-only actions with no touch fallback.
- Missing empty or error states.
- Animating with `Opacity` or rebuilding a large subtree every frame (see the performance notes in `references/motion-and-a11y.md`).
- More than one primary (teal) action visible in the same region.
- Exact score shown without its band label, or the other way around (PRD §3.3 requires both).

## Copy tone

Short, warm, and direct. Use verbs on buttons ("Apply", "Pass", "Advance", "Not a fit"). Keep it candidate-respectful, especially for rejection: "Not selected for this role", never "Rejected". Light geometric wordplay is welcome in empty states ("Your deck is all squared away"), but use it no more than once per screen.
