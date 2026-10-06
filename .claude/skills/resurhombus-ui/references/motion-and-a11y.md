# Motion, Performance & Accessibility

## 1. Swipe physics (SwipeDeck)

| Parameter | Value | Why |
|---|---|---|
| Resting tilt of top card | 0° (back cards −3° / +2°) | The top card reads cleanly. The back cards give the "subtly angled" stack. |
| Rotation while dragging | `dx / screenWidth × 15°`, clamped to ±15° | Feels hinged at the bottom, like a real card |
| Rotation origin | `Alignment.bottomCenter` | Same reason |
| Commit threshold | \|dx\| > 35% of width, **or** fling velocity > 800 px/s in that direction | Allows both deliberate drags and quick flicks |
| Commit animation | Fly out to 1.5× width over 250 ms, `easeOutCubic` | Fast enough to keep the rhythm |
| Cancel animation | Spring back over 400 ms, `easeOutBack` | Bouncy and playful, but brief |
| Vertical drag | Allowed at 0.3× resistance. Never triggers an action. | Keeps the card from feeling stuck on rails |
| Back cards on commit | Scale and offset up to the next position over 250 ms | Continuity |
| Haptics | `HapticFeedback.lightImpact()` when crossing the threshold, `mediumImpact()` on commit | Tactile confirmation |

**Implementation notes:**
- Drive the top card from one `AnimationController` plus `Offset` state. Apply `Transform.translate` and `Transform.rotate` to a widget that is **built once** (`child:`), so the card subtree doesn't rebuild every frame.
- Swipes triggered by the DeckActionBar buttons run the same commit animation, so button users get the same feedback.
- Wrap the card in a `RepaintBoundary`. Precache the next card's logo with `precacheImage`.

## 2. Durations & curves

| Token | Duration | Use |
|---|---|---|
| `fast` | 150 ms | Hover reveals, chip toggles, triangle slide-in |
| `medium` | 250 ms | Card commit, status chip change, page fades |
| `slow` | 400 ms | Spring-backs, Deep-Dive flip, hero transitions |
| Score count-up | 600 ms | Large ScoreBadge only |
| Background drift | 60 s loop | GeometricBackground |

Curves: `easeOutCubic` (standard), `easeOutBack` (settles), `linear` (only for the progress line and the background).

## 3. Reduced motion

Check `MediaQuery.disableAnimationsOf(context)` (this follows Android's "Remove animations" setting). When it's true:
- GeometricBackground draws one static frame.
- Score count-up shows the final number right away.
- The Deep-Dive flip becomes a 150 ms crossfade.
- Swipe still follows the finger (that's direct manipulation, not decoration), but commit and cancel snap with 100 ms linear.
- Shimmer becomes a static `framework` placeholder.

## 4. Performance checklist (target 60 fps on a mid-range Android device)

- Don't use `Opacity` for animation. Use `FadeTransition` or `AnimatedOpacity`, or set the alpha directly in a painter.
- Don't use `BackdropFilter` blur on the deck or grid. It's expensive on Android. Use solid or translucent surfaces.
- Avoid `saveLayer` triggers: `ShaderMask`, `ClipPath` with anti-aliasing on large moving areas. Prefer `ClipRRect` or decorated shapes.
- Wrap independently animating regions (background, top card, toast) in a `RepaintBoundary`.
- Use `const` constructors everywhere they're possible.
- Profile with `flutter run --profile` and the DevTools Performance view. Check that "Raster" and "UI" stay under 16 ms during a fast swipe streak.

## 5. Contrast checklist (WCAG AA)

Normal text needs ≥ 4.5:1. Large text (≥ 24 px regular or ≥ 18.66 px bold) and UI components need ≥ 3:1.

| Foreground / background | Ratio | Verdict |
|---|---|---|
| `ink` on `deck` | about 7.7:1 | ✅ |
| white on `deck` | about 1.9:1 | ❌ never |
| white on `match` | about 4.3:1 | ⚠️ large or bold text and icons only |
| white on `matchStrong` | about 5.9:1 | ✅ |
| white on `pass` | about 7.8:1 | ✅ |
| `ink` on `canvas` | about 13.7:1 | ✅ |
| `inkMuted` on `canvas` | about 5.5:1 | ✅ |
| `framework` on `canvas` (as a text color) | about 1.4:1 | ❌ decoration only |

For new pairs, compute relative luminance (sRGB to linear: `c ≤ 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4`, L = 0.2126R + 0.7152G + 0.0722B), then ratio = (L1+0.05)/(L2+0.05). Write the result into this table.

## 6. Screen readers (TalkBack) & input

- The **JobCard semantics label** is a summary: "Senior Flutter Engineer at Acme, remote, match 87 percent Strong. Actions: apply, pass, details." Use `Semantics(customSemanticsActions: {...})` to expose Apply and Pass as custom actions, so TalkBack users can act without the buttons.
- Mark decorative shapes (background, dividers, illustration pieces) with `ExcludeSemantics`.
- Status changes that arrive through Realtime are announced with `SemanticsService.sendAnnouncement` (or the current Flutter announcement API) and the text "Status update: Interview requested at Acme".
- Touch targets are ≥ 48×48 logical px, including the triangles (the visible shape can be smaller than the hit area).
- Keyboard on web: tab order follows visual order, focus rings are visible (`matchStrong`), and `J/K/A/R` shortcuts on the board use `Shortcuts` + `Actions` and are listed in a "?" help dialog.
- Text scale: test 1.3× and 2.0×. Cards may grow taller and scroll internally, but they must not clip.
