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

  final Color canvas,
      framework,
      deck,
      deckDeep,
      match,
      matchStrong,
      pass,
      ink,
      inkMuted,
      stretch;

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
    1 => [
      BoxShadow(
        color: framework.withValues(alpha: .6),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ],
    2 => [
      BoxShadow(
        color: framework.withValues(alpha: .7),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    _ => [
      BoxShadow(
        color: framework.withValues(alpha: .8),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ],
  };

  @override
  RRTheme copyWith({
    Color? canvas,
    Color? framework,
    Color? deck,
    Color? deckDeep,
    Color? match,
    Color? matchStrong,
    Color? pass,
    Color? ink,
    Color? inkMuted,
    Color? stretch,
  }) => RRTheme(
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
