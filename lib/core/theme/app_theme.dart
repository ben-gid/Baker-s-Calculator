/// Warm artisan palette: terracotta on cream, sage for "ready" states.
///
/// Every colour in the app comes from `Theme.of(context).colorScheme` or the
/// [BakingColors] extension below — no widget hardcodes a hex value. Contrast
/// ratios in the comments are measured against the surface of that mode and are
/// all at or above WCAG AA for their use.
library;

import 'package:flutter/material.dart';

import 'spacing.dart';

const _seed = Color(0xFF9A3412); // terracotta

abstract final class _Light {
  static const surface = Color(0xFFFFFBEB); // warm cream
  static const surfaceContainer = Color(0xFFFFFFFF);
  static const surfaceContainerHigh = Color(0xFFFDF4E3);
  static const onSurface = Color(0xFF0F172A); // 16.0:1
  static const onSurfaceVariant = Color(0xFF57534E); // 7.4:1
  static const primary = Color(0xFF9A3412); // 7.0:1
  static const onPrimary = Color(0xFFFFFFFF); // 7.3:1 on primary
  static const primaryContainer = Color(0xFFFFE0D2);
  static const onPrimaryContainer = Color(0xFF5C1A06);
  static const outline = Color(0xFFD6C9B8);
  static const outlineVariant = Color(0xFFEADFCE);
  static const error = Color(0xFFB3261E);
  static const proof = Color(0xFF047857); // 5.4:1 — safe for text
  static const proofContainer = Color(0xFFD9F2E6);
  static const warn = Color(0xFF9A6400); // 4.8:1
}

abstract final class _Dark {
  static const surface = Color(0xFF1A1614); // warm charcoal, not neutral grey
  static const surfaceContainer = Color(0xFF241E1B);
  static const surfaceContainerHigh = Color(0xFF2E2724);
  static const onSurface = Color(0xFFF5EFE9); // 15.1:1
  static const onSurfaceVariant = Color(0xFFC4B7AC); // 8.2:1
  static const primary = Color(0xFFFFB59A); // 10.6:1
  static const onPrimary = Color(0xFF5C1A06);
  static const primaryContainer = Color(0xFF7A2A0E);
  static const onPrimaryContainer = Color(0xFFFFE0D2);
  static const outline = Color(0xFF544A44);
  static const outlineVariant = Color(0xFF3A322E);
  static const error = Color(0xFFF2B8B5);
  static const proof = Color(0xFF34D399); // 9.4:1
  static const proofContainer = Color(0xFF11493A);
  static const warn = Color(0xFFE8B84B);
}

/// Colours with a baking meaning rather than a Material role. Reached through
/// `Theme.of(context).extension<BakingColors>()!`.
@immutable
class BakingColors extends ThemeExtension<BakingColors> {
  const BakingColors({
    required this.proof,
    required this.onProof,
    required this.proofContainer,
    required this.warn,
  });

  /// Fermentation / "ready" indicators, and the accent on totals.
  final Color proof;
  final Color onProof;
  final Color proofContainer;

  /// Advisory validation — distinct from `colorScheme.error`, which blocks.
  final Color warn;

  @override
  BakingColors copyWith({
    Color? proof,
    Color? onProof,
    Color? proofContainer,
    Color? warn,
  }) => BakingColors(
    proof: proof ?? this.proof,
    onProof: onProof ?? this.onProof,
    proofContainer: proofContainer ?? this.proofContainer,
    warn: warn ?? this.warn,
  );

  @override
  BakingColors lerp(BakingColors? other, double t) {
    if (other == null) return this;
    return BakingColors(
      proof: Color.lerp(proof, other.proof, t)!,
      onProof: Color.lerp(onProof, other.onProof, t)!,
      proofContainer: Color.lerp(proofContainer, other.proofContainer, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
    );
  }
}

/// Weight for a variable font. Setting `fontWeight` alone makes Flutter
/// synthesise a bold; the variation selects the real designed weight.
List<FontVariation> _wght(double weight) => [FontVariation('wght', weight)];

/// Lining, fixed-width digits. Every gram and percentage uses this so columns
/// of numbers line up instead of shimmering as values change.
const tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final colorScheme =
      ColorScheme.fromSeed(seedColor: _seed, brightness: brightness).copyWith(
        surface: isDark ? _Dark.surface : _Light.surface,
        surfaceContainerLowest: isDark ? _Dark.surface : _Light.surface,
        surfaceContainer: isDark
            ? _Dark.surfaceContainer
            : _Light.surfaceContainer,
        surfaceContainerHigh: isDark
            ? _Dark.surfaceContainerHigh
            : _Light.surfaceContainerHigh,
        onSurface: isDark ? _Dark.onSurface : _Light.onSurface,
        onSurfaceVariant: isDark
            ? _Dark.onSurfaceVariant
            : _Light.onSurfaceVariant,
        primary: isDark ? _Dark.primary : _Light.primary,
        onPrimary: isDark ? _Dark.onPrimary : _Light.onPrimary,
        primaryContainer: isDark
            ? _Dark.primaryContainer
            : _Light.primaryContainer,
        onPrimaryContainer: isDark
            ? _Dark.onPrimaryContainer
            : _Light.onPrimaryContainer,
        outline: isDark ? _Dark.outline : _Light.outline,
        outlineVariant: isDark ? _Dark.outlineVariant : _Light.outlineVariant,
        error: isDark ? _Dark.error : _Light.error,
      );

  final textTheme = _textTheme(colorScheme);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    fontFamily: 'PlusJakartaSans',
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    extensions: [
      BakingColors(
        proof: isDark ? _Dark.proof : _Light.proof,
        onProof: isDark ? _Dark.surface : Colors.white,
        proofContainer: isDark ? _Dark.proofContainer : _Light.proofContainer,
        warn: isDark ? _Dark.warn : _Light.warn,
      ),
    ],

    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),

    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, minTapTarget),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(minTapTarget, minTapTarget),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      border: _fieldBorder(colorScheme.outline),
      enabledBorder: _fieldBorder(colorScheme.outline),
      focusedBorder: _fieldBorder(colorScheme.primary, width: 2),
      errorBorder: _fieldBorder(colorScheme.error),
      focusedErrorBorder: _fieldBorder(colorScheme.error, width: 2),
      helperMaxLines: 3,
      errorMaxLines: 3,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      helperStyle: TextStyle(color: colorScheme.onSurfaceVariant),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colorScheme.primary,
        selectedForegroundColor: colorScheme.onPrimary,
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outline),
        minimumSize: const Size(0, minTapTarget),
        textStyle: textTheme.labelLarge,
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      side: BorderSide(color: colorScheme.outlineVariant),
      labelStyle: textTheme.labelMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: Insets.lg),
      minVerticalPadding: Insets.md,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.field),
      ),
    ),

    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      iconColor: colorScheme.primary,
      collapsedIconColor: colorScheme.onSurfaceVariant,
    ),
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.field),
      borderSide: BorderSide(color: color, width: width),
    );

TextTheme _textTheme(ColorScheme colors) {
  TextStyle style(
    double size,
    double weight, {
    double? height,
    Color? color,
    double letterSpacing = 0,
  }) => TextStyle(
    fontSize: size,
    height: height,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: _wght(weight),
    letterSpacing: letterSpacing,
    color: color ?? colors.onSurface,
  );

  return TextTheme(
    displaySmall: style(36, 700, height: 1.15, letterSpacing: -0.5),
    headlineMedium: style(28, 700, height: 1.2, letterSpacing: -0.3),
    headlineSmall: style(24, 600, height: 1.25),
    titleLarge: style(20, 600, height: 1.3),
    titleMedium: style(17, 600, height: 1.35),
    titleSmall: style(15, 600, height: 1.4),
    bodyLarge: style(16, 400, height: 1.5),
    bodyMedium: style(14, 400, height: 1.5, color: colors.onSurfaceVariant),
    bodySmall: style(13, 400, height: 1.45, color: colors.onSurfaceVariant),
    labelLarge: style(15, 600, height: 1.2),
    labelMedium: style(13, 500, height: 1.2),
    labelSmall: style(12, 500, height: 1.2, color: colors.onSurfaceVariant),
  );
}
