import 'package:flutter/material.dart';

/// Approximation of your OKLCH palette in sRGB.
/// Keeps contrast and temperature close to your provided tones.
class AppColors {
  // Base neutrals
  static const bgDark = Color(0xFF171717); // oklch(0.1 0.025 97)
  static const bg = Color(0xFF1E1E1E); // oklch(0.15 0.025 97)
  static const bgLight = Color(0xFF2B2B2B); // oklch(0.2 0.025 97)

  static const text = Color(0xFFF5F5F5); // oklch(0.96 0.05 97)
  static const textMuted = Color(0xFFBDBDBD); // oklch(0.76 0.05 97)

  static const highlight = Color(0xFF7D7D7D); // oklch(0.5 0.05 97)
  static const border = Color(0xFF595959); // oklch(0.4 0.05 97)
  static const borderMuted = Color(0xFF3B3B3B); // oklch(0.3 0.05 97)

  // Accents
  static const primary = Color(0xFFC8E6FF); // oklch(0.76 0.1 97)
  static const secondary = Color(0xFFD0C8FF); // oklch(0.76 0.1 277)
  static const danger = Color(0xFFF2B8B5); // oklch(0.7 0.05 30)
  static const warning = Color(0xFFF5E5B8); // oklch(0.7 0.05 100)
  static const success = Color(0xFFB8F5C2); // oklch(0.7 0.05 160)
  static const info = Color(0xFFB8D8F5); // oklch(0.7 0.05 260)
}

final _radius = BorderRadius.circular(16);

ThemeData buildTheme({required bool isDark}) {
  final colorScheme = ColorScheme(
    brightness: isDark ? Brightness.dark : Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.black,
    secondary: AppColors.secondary,
    onSecondary: Colors.black,
    error: AppColors.danger,
    onError: Colors.black,
    surface: isDark ? AppColors.bg : AppColors.bgLight,
    onSurface: AppColors.text,
    background: isDark ? AppColors.bgDark : AppColors.bgLight,
    onBackground: AppColors.text,
  );

  final baseTextColor = AppColors.text;
  final mutedTextColor = AppColors.textMuted;

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: baseTextColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: baseTextColor,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: baseTextColor,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: baseTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        color: mutedTextColor,
        fontSize: 14,
      ),
      labelLarge: TextStyle(
        color: baseTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Buttons (M3 style)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: _radius),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: _radius),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: isDark ? AppColors.bg : AppColors.bgLight,
      shape: RoundedRectangleBorder(borderRadius: _radius),
      elevation: 1,
      margin: const EdgeInsets.all(8),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.bg : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: AppColors.borderMuted),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: AppColors.borderMuted),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: mutedTextColor),
      hintStyle: TextStyle(color: mutedTextColor.withOpacity(0.7)),
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.borderMuted,
      labelStyle: TextStyle(color: baseTextColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: Colors.transparent),
      selectedColor: AppColors.primary.withOpacity(0.2),
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: AppColors.borderMuted,
      thickness: 1,
    ),

    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary; // selected background
          }
          return colorScheme.surface; // unselected background
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary; // selected text/icon color
          }
          return colorScheme.onSurface; // unselected text/icon color
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      )
    )

  );
}

final lightTheme = buildTheme(isDark: false);
final darkTheme = buildTheme(isDark: true);
