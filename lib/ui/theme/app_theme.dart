import 'package:flutter/material.dart';

import 'rr_theme.dart';
import 'rr_tokens.dart';

/// Compatibility names for the early home screen; all values use C2 tokens.
abstract final class AppStyle {
  static const canvas = RRColors.canvas;
  static const ink = RRColors.ink;
  static const muted = RRColors.inkMuted;
  static const framework = RRColors.framework;
  static const match = RRColors.matchStrong;
  static const small = RRSpace.sm;
  static const medium = RRSpace.lg;
  static const large = RRSpace.xl;
  static const extraLarge = RRSpace.xxl;
  static const contentWidth = RRSpace.pageWidth;
  static const radius = BorderRadius.all(RRRadius.lg);
}

ThemeData buildAppTheme() => buildRRTheme();
