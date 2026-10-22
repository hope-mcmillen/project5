// lib/ui/theme/rr_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'rr_theme_ext.dart';
import 'rr_tokens.dart';

ThemeData buildRRTheme() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final scheme = ColorScheme.fromSeed(seedColor: RRColors.match).copyWith(
    primary: RRColors.matchStrong,
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

  // Bundled variable fonts work offline and avoid per-weight network requests.
  final body = ThemeData.light().textTheme.apply(fontFamily: 'Inter');
  final text = body
      .copyWith(
        displaySmall: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 32,
          height: 40 / 32,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(bodyColor: RRColors.ink, displayColor: RRColors.ink);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RRColors.canvas,
    textTheme: text,
    extensions: const [RRTheme.light],
    appBarTheme: const AppBarTheme(
      backgroundColor: RRColors.canvas,
      foregroundColor: RRColors.ink,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: RRColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(RRRadius.lg),
        side: BorderSide(color: RRColors.framework),
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: RRColors.surface),
    listTileTheme: const ListTileThemeData(
      iconColor: RRColors.inkMuted,
      textColor: RRColors.ink,
      selectedColor: RRColors.ink,
      selectedTileColor: RRColors.canvas,
      minVerticalPadding: RRSpace.md,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RRColors.ink,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: RRSpace.lg,
          vertical: RRSpace.md,
        ),
        side: const BorderSide(color: RRColors.framework),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(RRRadius.md),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: RRSpace.lg,
          vertical: RRSpace.md,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(RRRadius.md),
        ),
        textStyle: text.labelLarge?.copyWith(
          fontSize: 16,
        ), // ≥ large-text threshold for white-on-teal
      ),
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: RRColors.framework),
      labelStyle: text.labelSmall,
      shape: const StadiumBorder(),
    ),
    dividerTheme: const DividerThemeData(
      color: RRColors.framework,
      thickness: 1,
    ),
    focusColor: RRColors.matchStrong.withValues(alpha: .24),
  );
}
