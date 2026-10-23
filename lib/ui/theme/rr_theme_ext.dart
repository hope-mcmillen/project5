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
    required this.violet,
    required this.pink,
    required this.lemon,
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
      stretch,
      violet,
      pink,
      lemon;

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
    violet: RRColors.violet,
    pink: RRColors.pink,
    lemon: RRColors.lemon,
  );

  /// Flat collage shadows: a hard navy offset rather than a soft blur.
  List<BoxShadow> shadow(int level) => switch (level) {
    1 => [
      BoxShadow(
        color: ink.withValues(alpha: .10),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ],
    2 => [
      BoxShadow(
        color: ink.withValues(alpha: .14),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
    _ => [
      BoxShadow(
        color: ink.withValues(alpha: .20),
        blurRadius: 24,
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
    Color? violet,
    Color? pink,
    Color? lemon,
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
    violet: violet ?? this.violet,
    pink: pink ?? this.pink,
    lemon: lemon ?? this.lemon,
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
      violet: Color.lerp(violet, other.violet, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
      lemon: Color.lerp(lemon, other.lemon, t)!,
    );
  }
}

extension RRContext on BuildContext {
  RRTheme get rr => Theme.of(this).extension<RRTheme>()!;
}
