// lib/ui/theme/rr_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'rr_theme_ext.dart';
import 'rr_tokens.dart';

TextStyle _display(double size, double lineHeight) => TextStyle(
  fontFamily: RRFonts.display,
  fontSize: size,
  height: lineHeight / size,
  fontWeight: FontWeight.w900,
  letterSpacing: size >= 24 ? -.5 : 0,
);

ThemeData buildRRTheme() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final scheme = ColorScheme.fromSeed(seedColor: RRColors.match).copyWith(
    primary: RRColors.matchStrong,
    onPrimary: Colors.white,
    primaryContainer: RRColors.match.withValues(alpha: .14),
    onPrimaryContainer: RRColors.ink,
    secondary: RRColors.deck,
    onSecondary: RRColors.ink,
    secondaryContainer: RRColors.lemon,
    onSecondaryContainer: RRColors.ink,
    tertiary: RRColors.violet,
    onTertiary: Colors.white,
    error: RRColors.pass,
    onError: Colors.white,
    surface: RRColors.surface,
    onSurface: RRColors.ink,
    onSurfaceVariant: RRColors.inkMuted,
    surfaceContainerLowest: RRColors.surface,
    surfaceContainerLow: RRColors.surface,
    surfaceContainer: RRColors.surface,
    surfaceContainerHigh: RRColors.canvas,
    surfaceContainerHighest: RRColors.canvasDeep,
    outline: RRColors.framework,
    outlineVariant: RRColors.framework,
  );

  // Bundled fonts work offline and avoid per-weight network requests.
  final body = ThemeData.light().textTheme.apply(fontFamily: RRFonts.body);
  final text = body
      .copyWith(
        displayLarge: _display(56, 60),
        displayMedium: _display(44, 50),
        displaySmall: _display(36, 42),
        headlineLarge: _display(32, 40),
        headlineMedium: _display(28, 36),
        headlineSmall: _display(24, 32),
        titleLarge: _display(20, 28),
        titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        labelSmall: body.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
        ),
      )
      .apply(bodyColor: RRColors.ink, displayColor: RRColors.ink);

  const stadium = StadiumBorder();
  const buttonPadding = EdgeInsets.symmetric(
    horizontal: RRSpace.xl,
    vertical: RRSpace.md,
  );
  final buttonText = text.labelLarge?.copyWith(fontSize: 16);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RRColors.canvas,
    textTheme: text,
    extensions: const [RRTheme.light],
    appBarTheme: AppBarTheme(
      backgroundColor: RRColors.canvas,
      foregroundColor: RRColors.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: RRColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(RRRadius.xl),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: RRColors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: RRColors.ink,
      textColor: RRColors.ink,
      selectedColor: RRColors.ink,
      selectedTileColor: RRColors.lemon,
      minVerticalPadding: RRSpace.md,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RRColors.ink,
        minimumSize: const Size(48, 48),
        padding: buttonPadding,
        side: const BorderSide(color: RRColors.ink, width: 2),
        shape: stadium,
        textStyle: buttonText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RRColors.matchStrong,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: buttonPadding,
        shape: stadium,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RRColors.ink,
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge,
        shape: stadium,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: RRColors.ink),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: RRColors.lemon,
      foregroundColor: RRColors.ink,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 2,
      highlightElevation: 0,
      shape: StadiumBorder(),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: RRColors.surface,
      selectedColor: RRColors.lemon,
      side: BorderSide.none,
      labelStyle: text.labelLarge?.copyWith(fontSize: 13),
      shape: stadium,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: RRColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(RRRadius.lg),
        borderSide: BorderSide(color: RRColors.framework),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(RRRadius.lg),
        borderSide: BorderSide(color: RRColors.framework),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(RRRadius.lg),
        borderSide: BorderSide(color: RRColors.ink, width: 2),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: RRColors.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyLarge,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(RRRadius.lg),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: RRColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(RRRadius.xl),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RRColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: RRColors.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      actionTextColor: RRColors.lemon,
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RRColors.ink,
      linearTrackColor: RRColors.framework,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: RRColors.ink,
      unselectedLabelColor: RRColors.inkMuted,
      indicatorColor: RRColors.ink,
      labelStyle: text.labelLarge,
    ),
    dividerTheme: const DividerThemeData(
      color: RRColors.framework,
      thickness: 1,
    ),
    focusColor: RRColors.ink.withValues(alpha: .16),
  );
}
