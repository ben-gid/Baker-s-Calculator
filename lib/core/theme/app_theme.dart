/// Starter Jar: soft, organic and calm, with fermentation as the hero. A pale
/// sage page in light mode and a deep forest one in dark, white or deep-green
/// panels on it, sage for action and a honey-yellow starter for the answer.
///
/// Containers are told apart by their **fill**, not by a border. The page is a
/// tinted ground, a panel is the lighter (or, in dark, slightly raised) surface
/// on it, and a field is a darker fill inside the panel. `colorScheme.outline`
/// is only used where a control genuinely needs an edge; `outlineVariant` draws
/// hairline dividers and the jar's glass rim.
///
/// Sage carries action and selection, the starter's yellow carries the result,
/// and red and amber stay reserved for the two states that warn. Every accent
/// has a *container* pair — a pale tint in light and a deep one in dark.
///
/// [BakingColors.proofContainer] is the totals block. Only two foregrounds are
/// drawn on it — [BakingColors.onProofContainer] for the total and
/// [BakingColors.onProofContainerMuted] for the labels. The jar's own colours —
/// [BakingColors.starter], [BakingColors.starterDeep] and [BakingColors.bubble]
/// — are paint only: no text is ever drawn on the liquid.
///
/// `primary` and [BakingColors.proof] are deliberately the same sage — the
/// dough being ready *is* the brand. They stay separate names so a future
/// change can split them again.
///
/// Every colour in the app comes from `Theme.of(context).colorScheme` or the
/// [BakingColors] extension below — no widget hardcodes a hex value. Contrast
/// ratios in the comments are measured against the surfaces of that mode, and
/// `test/theme_contrast_test.dart` re-measures every one of them.
library;

import 'package:flutter/material.dart';

import 'spacing.dart';

const _seed = Color(0xFF3F5A3C); // sage — derives the neutrals

abstract final class _Light {
  /// The page: pale glass sage. Panels are white and sit on it.
  static const surface = Color(0xFFEEF2E8);
  static const surfaceContainer = Color(0xFFFFFFFF);
  static const surfaceContainerHigh = Color(0xFFE3EADB);
  static const onSurface = Color(0xFF24331F); // 11.9:1
  static const onSurfaceVariant = Color(0xFF55664F); // 5.0:1 on the field fill
  static const primary = Color(0xFF3F5A3C); // deep sage, 6.3:1
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFD5E3C8); // pale sage
  static const onPrimaryContainer = Color(0xFF24331F);
  static const outline = Color(0xFF74806E); // control edges
  static const outlineVariant = Color(0xFFC3D0B8); // dividers, the jar's rim
  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
  static const proof = Color(0xFF3F5A3C); // the accent itself — see above
  static const proofContainer = Color(0xFFF6E7A1); // starter at its peak
  static const onProofContainer = Color(0xFF24331F); // the total
  static const onProofContainerMuted = Color(0xFF4A5944); // the labels
  static const warn = Color(0xFF7A5900);
  static const starter = Color(0xFFF3DF8E);
  static const starterDeep = Color(0xFFE0BF57);
  static const bubble = Color(0xFFFFFBEA);
}

abstract final class _Dark {
  /// The page: deep forest. Panels are a step raised from it.
  static const surface = Color(0xFF121812);
  static const surfaceContainer = Color(0xFF1C241B);
  static const surfaceContainerHigh = Color(0xFF263024);
  static const onSurface = Color(0xFFE6EEDF); // 13.9:1
  static const onSurfaceVariant = Color(0xFFA9B8A0); // 6.6:1 on the field fill
  static const primary = Color(0xFFA8C99A); // light sage, 7.5:1
  static const onPrimary = Color(0xFF142012);
  static const primaryContainer = Color(0xFF34502F); // deep sage
  static const onPrimaryContainer = Color(0xFFD5E8C8);
  static const outline = Color(0xFF7E8C77); // control edges
  static const outlineVariant = Color(0xFF3A4734); // dividers, the jar's rim
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const proof = Color(0xFFA8C99A); // the accent itself — see above
  static const proofContainer = Color(0xFF3B3418); // deep honey
  static const onProofContainer = Color(0xFFF6E7A1); // the total
  static const onProofContainerMuted = Color(0xFFD4C68C); // the labels
  static const warn = Color(0xFFFFD24A);
  static const starter = Color(0xFFE9CF6E); // glows against the dark glass
  static const starterDeep = Color(0xFFB8962F);
  static const bubble = Color(0xFFFFF3C4);
}

/// Colours with a baking meaning rather than a Material role. Reached through
/// `Theme.of(context).extension<BakingColors>()!`.
@immutable
class BakingColors extends ThemeExtension<BakingColors> {
  const BakingColors({
    required this.proof,
    required this.proofContainer,
    required this.onProofContainer,
    required this.onProofContainerMuted,
    required this.warn,
    required this.starter,
    required this.starterDeep,
    required this.bubble,
  });

  /// Fermentation / "ready" indicators. Drawn on a surface, never on
  /// [proofContainer].
  final Color proof;

  /// The totals block.
  final Color proofContainer;

  /// The total itself, on [proofContainer].
  final Color onProofContainer;

  /// Labels on [proofContainer]. `onSurfaceVariant` cannot be used there — it is
  /// tuned against the page, not against a warm tonal fill, and misses AA on it
  /// in both modes.
  final Color onProofContainerMuted;

  /// Advisory validation — distinct from `colorScheme.error`, which blocks.
  final Color warn;

  /// The starter in the jar: its surface, the deeper colour it settles to at
  /// the bottom, and its bubbles. Paint only — no text is drawn on them.
  final Color starter;
  final Color starterDeep;
  final Color bubble;

  @override
  BakingColors copyWith({
    Color? proof,
    Color? proofContainer,
    Color? onProofContainer,
    Color? onProofContainerMuted,
    Color? warn,
    Color? starter,
    Color? starterDeep,
    Color? bubble,
  }) => BakingColors(
    proof: proof ?? this.proof,
    proofContainer: proofContainer ?? this.proofContainer,
    onProofContainer: onProofContainer ?? this.onProofContainer,
    onProofContainerMuted: onProofContainerMuted ?? this.onProofContainerMuted,
    warn: warn ?? this.warn,
    starter: starter ?? this.starter,
    starterDeep: starterDeep ?? this.starterDeep,
    bubble: bubble ?? this.bubble,
  );

  @override
  BakingColors lerp(BakingColors? other, double t) {
    if (other == null) return this;
    return BakingColors(
      proof: Color.lerp(proof, other.proof, t)!,
      proofContainer: Color.lerp(proofContainer, other.proofContainer, t)!,
      onProofContainer: Color.lerp(
        onProofContainer,
        other.onProofContainer,
        t,
      )!,
      onProofContainerMuted: Color.lerp(
        onProofContainerMuted,
        other.onProofContainerMuted,
        t,
      )!,
      warn: Color.lerp(warn, other.warn, t)!,
      starter: Color.lerp(starter, other.starter, t)!,
      starterDeep: Color.lerp(starterDeep, other.starterDeep, t)!,
      bubble: Color.lerp(bubble, other.bubble, t)!,
    );
  }
}

/// Weight for a variable font. Setting `fontWeight` alone makes Flutter
/// synthesise a bold; the variation selects the real designed weight.
List<FontVariation> _wght(double weight) => [FontVariation('wght', weight)];

/// The one face. Nunito is a rounded sans that suits the soft shapes, it is a
/// variable font (200–1000), and its digits are all the same width by design —
/// so columns of grams line up without a separate monospace face.
const appFont = 'Nunito';

/// Sets [style] as a measurement. With one face that already has fixed-width
/// digits this only pins the weight variation, but every gram and percentage
/// still goes through here, so a future figures face has one place to land.
TextStyle numeric(TextStyle? style) {
  final base = style ?? const TextStyle();
  final weight = (base.fontWeight ?? FontWeight.w400).value;
  return base.copyWith(
    fontFamily: appFont,
    fontVariations: _wght(weight.toDouble()),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final colorScheme =
      ColorScheme.fromSeed(seedColor: _seed, brightness: brightness).copyWith(
        surface: isDark ? _Dark.surface : _Light.surface,
        surfaceContainerLowest: isDark ? _Dark.surface : _Light.surface,
        surfaceContainerLow: isDark
            ? _Dark.surfaceContainer
            : _Light.surfaceContainer,
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
        onError: isDark ? _Dark.onError : _Light.onError,
      );

  final textTheme = _textTheme(colorScheme);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    fontFamily: appFont,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    extensions: [
      BakingColors(
        proof: isDark ? _Dark.proof : _Light.proof,
        proofContainer: isDark ? _Dark.proofContainer : _Light.proofContainer,
        onProofContainer: isDark
            ? _Dark.onProofContainer
            : _Light.onProofContainer,
        onProofContainerMuted: isDark
            ? _Dark.onProofContainerMuted
            : _Light.onProofContainerMuted,
        warn: isDark ? _Dark.warn : _Light.warn,
        starter: isDark ? _Dark.starter : _Light.starter,
        starterDeep: isDark ? _Dark.starterDeep : _Light.starterDeep,
        bubble: isDark ? _Dark.bubble : _Light.bubble,
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
      shape: _rounded(Radii.card),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        shape: _rounded(Radii.pill),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        side: BorderSide(color: colorScheme.outline, width: Borders.hair),
        shape: _rounded(Radii.pill),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, minTapTarget),
        shape: _rounded(Radii.pill),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(minTapTarget, minTapTarget),
        shape: const CircleBorder(),
      ),
    ),

    // Filled and borderless: a field is a darker fill inside the panel, and only
    // the focused one gets an edge. The label sits above the box, so the border
    // never has a notch cut into it.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      border: _fieldBorder(Colors.transparent),
      enabledBorder: _fieldBorder(Colors.transparent),
      focusedBorder: _fieldBorder(colorScheme.primary, width: Borders.focus),
      errorBorder: _fieldBorder(colorScheme.error),
      focusedErrorBorder: _fieldBorder(colorScheme.error, width: Borders.focus),
      helperMaxLines: 3,
      errorMaxLines: 3,
      helperStyle: textTheme.bodySmall,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      side: BorderSide.none,
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onPrimaryContainer,
      ),
      shape: _rounded(Radii.chip),
    ),

    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: Borders.hair,
      space: Borders.hair,
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      minVerticalPadding: Insets.md,
      shape: _rounded(Radii.card),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: _rounded(Radii.field),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: _rounded(Radii.card + 8),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Radii.card + 8),
        ),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: _rounded(Radii.field),
      textStyle: textTheme.bodyLarge,
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      strokeCap: StrokeCap.round,
    ),

    datePickerTheme: DatePickerThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: _rounded(Radii.card + 8),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      elevation: 0,
      shape: _rounded(Radii.card + 8),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.surfaceContainerHigh,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : colorScheme.outline,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(Borders.hair),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.outline,
      ),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      textStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
    ),
  );
}

RoundedRectangleBorder _rounded(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

OutlineInputBorder _fieldBorder(Color color, {double width = Borders.hair}) =>
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
    String? family,
  }) => TextStyle(
    // Named on every style, not left to ThemeData.fontFamily: the button
    // themes below take these styles before ThemeData applies its family, and
    // would otherwise fall back to the platform font.
    fontFamily: family ?? appFont,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: _wght(weight),
    letterSpacing: letterSpacing,
    color: color ?? colors.onSurface,
  );

  // Nunito's rounded heavy cuts carry the display end; headings are told apart
  // from body by size and weight, never by shouting.
  TextStyle display(double size, double weight, {double? height}) => style(
    size,
    weight,
    height: height,
    letterSpacing: -size * 0.02,
    family: appFont,
  );

  return TextTheme(
    displayMedium: display(48, 800, height: 1.05),
    displaySmall: display(40, 800, height: 1.1),
    headlineMedium: display(30, 800, height: 1.15),
    headlineSmall: display(24, 800, height: 1.2),
    titleLarge: display(20, 700, height: 1.25),
    titleMedium: display(17, 700, height: 1.3),
    titleSmall: style(15, 700, height: 1.4),
    bodyLarge: style(16, 400, height: 1.5),
    bodyMedium: style(14, 400, height: 1.5, color: colors.onSurfaceVariant),
    bodySmall: style(13, 400, height: 1.45, color: colors.onSurfaceVariant),
    // Section headings and field labels. Sentence case, so the tracking goes
    // back to the small positive values that sit well under 16 px.
    labelLarge: style(15, 700, height: 1.2, letterSpacing: 0.1),
    labelMedium: style(13, 700, height: 1.2, letterSpacing: 0.1),
    labelSmall: style(
      12,
      600,
      height: 1.2,
      letterSpacing: 0.2,
      color: colors.onSurfaceVariant,
    ),
  );
}
