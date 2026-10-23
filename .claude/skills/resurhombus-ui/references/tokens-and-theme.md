# Tokens & Theme

## Contents
1. Color tokens
2. Spacing, radius, elevation
3. Typography
4. Breakpoints
5. Dart implementation (`lib/ui/theme/`)

---

## 1. Color tokens

**Collage palette (Oct 2026).** Flat grey canvas, navy ink, saturated tiles, inspired by a geometric marketing collage. Rhombus and triangle motifs stay. Source of truth: `lib/ui/theme/rr_tokens.dart`.

| Token | Hex | Role | Text on it |
|---|---|---|---|
| `canvas` | `#E6E6E3` | App background (light grey) | `ink` (12:1) |
| `canvasDeep` | `#D6D7D1` | Shimmer, loading blocks, wells on canvas | `ink` |
| `surface` | `#FFFFFF` | Cards, sheets, dialogs, recruiter tiles | `ink` |
| `framework` | `#C4C5BF` | Dividers, input outlines, inactive elements | n/a |
| `deck` | `#2D9CEB` | Job card header tile (sky); decorative tiles | `ink` only (5.1:1) |
| `deckDeep` | `#1B7FCC` | Card edge, stacked back layers | `ink` |
| `match` | `#1F8A3B` | Apply/advance/strong (green) | white **large or bold only** (4.4:1) |
| `matchStrong` | `#17702F` | Primary buttons, small green text, links | white OK (6.2:1) |
| `pass` | `#A31621` | Pass, reject, destructive, errors | white (7.8:1) |
| `ink` | `#14215A` | Navy text, icons, ribbons, outlined buttons | n/a |
| `inkMuted` | `#4A5275` | Secondary text | 6.1:1 on canvas |
| `stretch` | `#6B7187` | "Stretch" band | `ink` |
| `violet` | `#5B2BC9` | Decorative tile | white or lemon |
| `pink` | `#FF7AA2` | Decorative tile, recruiter header tiles | `ink` (6.1:1) |
| `lemon` | `#FFE14D` | Decorative tile, selected drawer item, avatar, FAB | `ink` (11.6:1) |

Green and crimson keep their meaning: never use them for decoration. Decorative tiles use violet, pink, lemon, sky and navy. `onTile(color)` in `branded_page.dart` picks AA text for a tile.

**Collage components** (`lib/ui/components/collage.dart`): `CollageTile` (square, circle, pill, half-circle "D" shapes, leaf), `TileMotif` (rhombus, triangle, asterisk, arrow, ring, squiggle), `TileMosaic` (rows of butting tiles), `HeadlineTile` (big lowercase "word." header tile), `TileCluster` (empty-state illustration), `RibbonBackdrop` (navy/pink/lemon ribbons, auth pages only), `CollageWordmark`. Candidate pages get a colourful `HeadlineTile`; recruiter pages keep white cards on grey with one pink header tile.

**Score band to visual** (PRD §3.3):

| Band | Range | Rhombus | Color | Label |
|---|---|---|---|---|
| Strong | 85–100 | filled | `match` | "Strong" |
| Good | 70–84 | outlined (2 px) | `match` | "Good" |
| Stretch | 50–69 | outlined, dashed | `stretch` | "Stretch" |
| (hidden) | below 50 | n/a | n/a | Shown only if the user turns on "Show stretch roles". The label is "Low". |

## 2. Spacing, radius, elevation

- **Spacing scale (logical px):** `xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`. Phone page gutter = `lg` (16). Card internal padding = `xl` (24).
- **Radius:** `sm 4` (chips' inner elements, tags) · `md 8` (buttons, inputs) · `lg 12` (cards, tiles, sheets) · `pill 999` (chips only).
- **Elevation:** Use 2–3 shadow levels with `framework` as the shadow color, never pure black. This keeps the palette cool and airy.
  - `e1`: y 1, blur 3, `framework` at 60%. Tiles at rest.
  - `e2`: y 4, blur 12, `framework` at 70%. Top card, hovered tile.
  - `e3`: y 12, blur 28, `framework` at 80%. Dragged card, dialogs.
- **Diagonal angle:** 12° (`0.2094` rad) for accent stripes and dividers. Card resting tilt is separate (see motion).

## 3. Typography

Use the `google_fonts` package. For release builds, bundle the font files under `assets/fonts/` and set `GoogleFonts.config.allowRuntimeFetching = false` so the app works offline.

- **Display and headings:** *Poppins Black* (900), bundled at `assets/fonts/Poppins-Black.ttf`. Headlines are lowercase with a trailing period on header tiles ("swipe.", "hire."). Space Grotesk is still bundled but no longer used by the theme.
- **Body and UI:** *Inter*. Highly legible at small sizes.

| Style | Font | Size / line height | Weight | Use |
|---|---|---|---|---|
| displaySmall | Poppins | 36/42 | 900 | Score number on Deep-Dive |
| headlineSmall | Poppins | 24/32 | 900 | Screen titles |
| titleLarge | Poppins | 20/28 | 900 | Card job title |
| titleMedium | Inter | 16/24 | 600 | Company name, section headers |
| bodyLarge | Inter | 16/24 | 400 | Descriptions |
| bodyMedium | Inter | 14/20 | 400 | Default text |
| labelLarge | Inter | 14/20 | 600 | Buttons |
| labelSmall | Inter | 11/16 | 600, +0.5 letter-spacing | Chips, band labels (uppercase allowed) |

Respect the system text scale. Don't clamp it below 1.0, and test layouts up to 2.0×.

## 4. Breakpoints

| Name | Width | Candidate | Recruiter |
|---|---|---|---|
| compact | < 600 | Single deck, bottom nav | 1-column tiles, tap reveals actions |
| medium | 600–899 | Deck centered, max width 440 | 2–3 columns |
| expanded | ≥ 900 | Deck plus side panel (Deep-Dive inline) | NavigationRail, 3–5 column mosaic (tile min width 260), hover actions, keyboard shortcuts |

Use `LayoutBuilder` or `MediaQuery.sizeOf(context).width`, not `Platform` checks, so a resized web window behaves correctly.

## 5. Dart implementation

Put this in `lib/ui/theme/`. It is the starting point. Extend it rather than adding parallel constants elsewhere.

```dart
// lib/ui/theme/rr_tokens.dart
import 'package:flutter/material.dart';

abstract final class RRColors {
  static const canvas = Color(0xFFFCF7F8);
  static const surface = Color(0xFFFFFFFF);
  static const framework = Color(0xFFCED3DC);
  static const deck = Color(0xFF90C2E7);
  static const deckDeep = Color(0xFF6FA8D6);
  static const match = Color(0xFF4E8098);
  static const matchStrong = Color(0xFF3D6A80);
  static const pass = Color(0xFFA31621);
  static const ink = Color(0xFF1F2A33);
  static const inkMuted = Color(0xFF5B6670);
  static const stretch = Color(0xFF8A94A3);
}

abstract final class RRSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0, xxxl = 48.0;
}

abstract final class RRRadius {
  static const sm = Radius.circular(4), md = Radius.circular(8), lg = Radius.circular(12);
}

abstract final class RRMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const emphasized = Curves.easeOutCubic;
  static const settle = Curves.easeOutBack; // card snap-back
  static const diagonal = 0.2094; // 12° in radians
}
```

```dart
// lib/ui/theme/rr_theme_ext.dart
import 'package:flutter/material.dart';
import 'rr_tokens.dart';

/// Brand colors Material's ColorScheme has no slot for.
@immutable
class RRTheme extends ThemeExtension<RRTheme> {
  const RRTheme({
    required this.canvas,
    required this.framework,
    required this.deck,
    required this.deckDeep,
    required this.match,
    required this.matchStrong,
    required this.pass,
    required this.ink,
    required this.inkMuted,
    required this.stretch,
  });

  final Color canvas, framework, deck, deckDeep, match, matchStrong, pass, ink, inkMuted, stretch;

  static const light = RRTheme(
    canvas: RRColors.canvas,
    framework: RRColors.framework,
    deck: RRColors.deck,
    deckDeep: RRColors.deckDeep,
    match: RRColors.match,
    matchStrong: RRColors.matchStrong,
    pass: RRColors.pass,
    ink: RRColors.ink,
    inkMuted: RRColors.inkMuted,
    stretch: RRColors.stretch,
  );

  List<BoxShadow> shadow(int level) => switch (level) {
        1 => [BoxShadow(color: framework.withValues(alpha: .6), blurRadius: 3, offset: const Offset(0, 1))],
        2 => [BoxShadow(color: framework.withValues(alpha: .7), blurRadius: 12, offset: const Offset(0, 4))],
        _ => [BoxShadow(color: framework.withValues(alpha: .8), blurRadius: 28, offset: const Offset(0, 12))],
      };

  @override
  RRTheme copyWith({
    Color? canvas, Color? framework, Color? deck, Color? deckDeep, Color? match,
    Color? matchStrong, Color? pass, Color? ink, Color? inkMuted, Color? stretch,
  }) =>
      RRTheme(
        canvas: canvas ?? this.canvas,
        framework: framework ?? this.framework,
        deck: deck ?? this.deck,
        deckDeep: deckDeep ?? this.deckDeep,
        match: match ?? this.match,
        matchStrong: matchStrong ?? this.matchStrong,
        pass: pass ?? this.pass,
        ink: ink ?? this.ink,
        inkMuted: inkMuted ?? this.inkMuted,
        stretch: stretch ?? this.stretch,
      );

  @override
  RRTheme lerp(RRTheme? other, double t) {
    if (other == null) return this;
    return RRTheme(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      framework: Color.lerp(framework, other.framework, t)!,
      deck: Color.lerp(deck, other.deck, t)!,
      deckDeep: Color.lerp(deckDeep, other.deckDeep, t)!,
      match: Color.lerp(match, other.match, t)!,
      matchStrong: Color.lerp(matchStrong, other.matchStrong, t)!,
      pass: Color.lerp(pass, other.pass, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      stretch: Color.lerp(stretch, other.stretch, t)!,
    );
  }
}

extension RRContext on BuildContext {
  RRTheme get rr => Theme.of(this).extension<RRTheme>()!;
}
```

```dart
// lib/ui/theme/rr_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'rr_theme_ext.dart';
import 'rr_tokens.dart';

ThemeData buildRRTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: RRColors.match).copyWith(
    primary: RRColors.match,
    onPrimary: Colors.white,
    secondary: RRColors.deck,
    onSecondary: RRColors.ink,
    error: RRColors.pass,
    onError: Colors.white,
    surface: RRColors.surface,
    onSurface: RRColors.ink,
    onSurfaceVariant: RRColors.inkMuted,
    outline: RRColors.framework,
  );

  final body = GoogleFonts.interTextTheme();
  final text = body.copyWith(
    displaySmall: GoogleFonts.spaceGrotesk(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.spaceGrotesk(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.spaceGrotesk(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600),
  ).apply(bodyColor: RRColors.ink, displayColor: RRColors.ink);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RRColors.canvas,
    textTheme: text,
    extensions: const [RRTheme.light],
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(RRRadius.md)),
        textStyle: text.labelLarge?.copyWith(fontSize: 16), // ≥ large-text threshold for white-on-teal
      ),
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: RRColors.framework),
      labelStyle: text.labelSmall,
      shape: const StadiumBorder(),
    ),
    dividerTheme: const DividerThemeData(color: RRColors.framework, thickness: 1),
    focusColor: RRColors.matchStrong.withValues(alpha: .24),
  );
}
```

**Dependency:** `flutter pub add google_fonts`. Fonts are fetched at runtime in debug. Bundle them for release (see §3).

**Dark mode:** Not in MVP. If it gets added, create `RRTheme.dark` and a second `ThemeData`. Because everything reads tokens through `context.rr` and `colorScheme`, no widget code should need to change. That's a good test of whether tokens were used properly.
