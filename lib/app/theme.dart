import 'package:flutter/material.dart';

/// Theme mode provider for Riverpod.
///
/// Manages light/dark/system theme switching across the app.
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

/// Design tokens for the TubeFlow app.
///
/// All color constants are defined here so they can be referenced
/// consistently across both light and dark theme configurations.
abstract final class AppColors {
  // Shared
  static const primary = Color(0xFF0D87E1);
  static const primaryForeground = Color(0xFFFFFFFF);

  // Light mode
  static const lightBackground = Color(0xFFF1F5F9);
  static const lightForeground = Color(0xFF0F172A);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardForeground = Color(0xFF0F172A);
  static const lightSecondary = Color(0xFFF1F5F9);
  static const lightSecondaryForeground = Color(0xFF0F172A);
  static const lightMuted = Color(0xFFF1F5F9);
  static const lightMutedForeground = Color(0xFF64748B);
  static const lightDestructive = Color(0xFFEF4444);
  static const lightBorder = Color(0xFFE2E8F0);

  // Dark mode
  static const darkBackground = Color(0xFF050506);
  static const darkForeground = Color(0xFFFAFAFA);
  static const darkCard = Color(0xFF18181B);
  static const darkCardForeground = Color(0xFFFAFAFA);
  static const darkSecondary = Color(0xFF27272A);
  static const darkSecondaryForeground = Color(0xFFFAFAFA);
  static const darkMuted = Color(0xFF27272A);
  static const darkMutedForeground = Color(0xFFA1A1AA);
  static const darkDestructive = Color(0xFF7F1D1D);
  static const darkBorder = Color(0xFF27272A);
}

/// Central theme configuration for TubeFlow.
///
/// Provides fully-specified [ThemeData] for light and dark modes using the
/// design tokens defined in [AppColors]. Typography uses Inter for body text,
/// Instrument Sans for headings, and DM Sans (weight 700) for display styles.
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  static const _fontBody = 'Inter';
  static const _fontHeading = 'Instrument Sans';
  static const _fontDisplay = 'DM Sans';

  static TextTheme _buildTextTheme(Color foreground, Color muted) {
    return TextTheme(
      // Display styles — DM Sans 700
      displayLarge: TextStyle(
        fontFamily: _fontDisplay,
        fontWeight: FontWeight.w700,
        fontSize: 57,
        color: foreground,
      ),
      displayMedium: TextStyle(
        fontFamily: _fontDisplay,
        fontWeight: FontWeight.w700,
        fontSize: 45,
        color: foreground,
      ),
      displaySmall: TextStyle(
        fontFamily: _fontDisplay,
        fontWeight: FontWeight.w700,
        fontSize: 36,
        color: foreground,
      ),

      // Headline styles — Instrument Sans
      headlineLarge: TextStyle(
        fontFamily: _fontHeading,
        fontWeight: FontWeight.w600,
        fontSize: 32,
        color: foreground,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontHeading,
        fontWeight: FontWeight.w600,
        fontSize: 28,
        color: foreground,
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontHeading,
        fontWeight: FontWeight.w600,
        fontSize: 24,
        color: foreground,
      ),

      // Title styles — Instrument Sans
      titleLarge: TextStyle(
        fontFamily: _fontHeading,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: foreground,
      ),
      titleMedium: TextStyle(
        fontFamily: _fontHeading,
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: foreground,
      ),
      titleSmall: TextStyle(
        fontFamily: _fontHeading,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: foreground,
      ),

      // Body styles — Inter
      bodyLarge: TextStyle(
        fontFamily: _fontBody,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: foreground,
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontBody,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: foreground,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontBody,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: muted,
      ),

      // Label styles — Inter
      labelLarge: TextStyle(
        fontFamily: _fontBody,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: foreground,
      ),
      labelMedium: TextStyle(
        fontFamily: _fontBody,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: foreground,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontBody,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        color: muted,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------

  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.lightSecondary,
      onSecondary: AppColors.lightSecondaryForeground,
      surface: AppColors.lightCard,
      onSurface: AppColors.lightCardForeground,
      error: AppColors.lightDestructive,
      onError: AppColors.primaryForeground,
      outline: AppColors.lightBorder,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: _buildTextTheme(
      AppColors.lightForeground,
      AppColors.lightMutedForeground,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.06),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightCard,
      foregroundColor: AppColors.lightForeground,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightCard,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: _fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.lightForeground,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.lightCard,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: _fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: _fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.lightMutedForeground,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: _fontBody,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lightForeground,
        side: const BorderSide(color: AppColors.lightBorder),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: _fontBody,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightSecondary,
      labelStyle: const TextStyle(
        fontFamily: _fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.lightSecondaryForeground,
      ),
      side: const BorderSide(color: AppColors.lightBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.lightForeground,
      contentTextStyle: const TextStyle(
        fontFamily: _fontBody,
        color: AppColors.lightCard,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ---------------------------------------------------------------------------
  // Dark theme
  // ---------------------------------------------------------------------------

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.darkSecondary,
      onSecondary: AppColors.darkSecondaryForeground,
      surface: AppColors.darkCard,
      onSurface: AppColors.darkCardForeground,
      error: AppColors.darkDestructive,
      onError: AppColors.primaryForeground,
      outline: AppColors.darkBorder,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: _buildTextTheme(
      AppColors.darkForeground,
      AppColors.darkMutedForeground,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkCard,
      foregroundColor: AppColors.darkForeground,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkCard,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: _fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.darkForeground,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.darkCard,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: _fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: _fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.darkMutedForeground,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: _fontBody,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkForeground,
        side: const BorderSide(color: AppColors.darkBorder),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: _fontBody,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSecondary,
      labelStyle: const TextStyle(
        fontFamily: _fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.darkSecondaryForeground,
      ),
      side: const BorderSide(color: AppColors.darkBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkForeground,
      contentTextStyle: const TextStyle(
        fontFamily: _fontBody,
        color: AppColors.darkCard,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
