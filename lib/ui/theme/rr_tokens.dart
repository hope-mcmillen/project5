// lib/ui/theme/rr_tokens.dart
import 'package:flutter/material.dart';

/// Collage palette: flat grey canvas, navy ink, saturated tiles.
///
/// Meaning still wins over decoration: green ([match]) is yes/apply/advance
/// and crimson ([pass]) is no/reject/destructive. Decorative tiles use
/// [violet], [pink], [lemon], [deck] (sky) and [ink] (navy) only.
abstract final class RRColors {
  static const canvas = Color(0xFFE6E6E3);
  static const canvasDeep = Color(0xFFD6D7D1); // shimmer, wells on canvas
  static const surface = Color(0xFFFFFFFF);
  static const framework = Color(0xFFC4C5BF);
  static const deck = Color(0xFF2D9CEB); // sky; ink text only (5.1:1)
  static const deckDeep = Color(0xFF1B7FCC);
  static const match = Color(0xFF1F8A3B); // white large/bold only (4.4:1)
  static const matchStrong = Color(0xFF17702F); // white OK (6.2:1)
  static const pass = Color(0xFFA31621);
  static const ink = Color(0xFF14215A); // navy
  static const inkMuted = Color(0xFF4A5275);
  static const stretch = Color(0xFF6B7187);

  // Decorative tile accents (never carry yes/no meaning).
  static const violet = Color(0xFF5B2BC9); // white or lemon text
  static const pink = Color(0xFFFF7AA2); // ink text
  static const lemon = Color(0xFFFFE14D); // ink text
}

abstract final class RRSpace {
  static const pageWidth = 720.0;
  static const markSize = 32.0;
  static const badgeSmall = 32.0, badgeMedium = 48.0, badgeLarge = 96.0;
  static const xs = 4.0,
      sm = 8.0,
      md = 12.0,
      lg = 16.0,
      xl = 24.0,
      xxl = 32.0,
      xxxl = 48.0;
}

abstract final class RRRadius {
  static const sm = Radius.circular(4),
      md = Radius.circular(8),
      lg = Radius.circular(12),
      xl = Radius.circular(20);
}

abstract final class RRFonts {
  /// Heavy geometric headlines ("grow."), bundled as Poppins Black.
  static const display = 'Poppins';
  static const body = 'Inter';
}

abstract final class RRMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const emphasized = Curves.easeOutCubic;
  static const settle = Curves.easeOutBack; // card snap-back
  static const diagonal = 0.2094; // 12° in radians
}
