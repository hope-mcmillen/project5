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
      lg = Radius.circular(12);
}

abstract final class RRMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const emphasized = Curves.easeOutCubic;
  static const settle = Curves.easeOutBack; // card snap-back
  static const diagonal = 0.2094; // 12° in radians
}
