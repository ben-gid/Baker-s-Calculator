/// Soft tonal palette: filled surfaces, generous radii, no rules and no shadows.
///
/// Containers are told apart by their **fill**, not by a border. The page is a
/// slightly grey ground, a panel is the lighter surface sitting on it, and a
/// field is a slightly darker fill inside the panel — the way a grouped iOS list
/// or a Material 3 filled card works. `colorScheme.outline` is a mid grey and is
/// only used where a control genuinely needs an edge; `outlineVariant` draws the
/// hairline dividers inside a panel.
///
/// Blue carries action and selection, and a warm amber carries the result. Red
/// and amber stay reserved for the two states that warn. Every accent has a
/// *container* pair — a pale tint in light mode and a deep one in dark — because
/// tonal containers are the whole point of this look: a filled block should
/// belong to the surface it sits on rather than punch through it.
///
/// [BakingColors.proofContainer] is the totals block, and it is mode-dependent
/// like every other container. Only two foregrounds are drawn on it —
/// [BakingColors.onProofContainer] for the total and
/// [BakingColors.onProofContainerMuted] for the labels. `warn` and `proof` are
/// deliberately kept off it: the dough-temp advisory sits *below* the block,
/// where it reads better anyway, and a third foreground would need its own token
/// and a line in the contrast test rather than a `copyWith` at the call site.
///
/// `primary` and [BakingColors.proof] are deliberately the same blue — the dough
/// being ready *is* the brand, so "ready" and "accent" are one colour. They stay
/// separate names so a future change can split them again.
///
/// Every colour in the app comes from `Theme.of(context).colorScheme` or the
/// [BakingColors] extension below — no widget hardcodes a hex value. Contrast
/// ratios in the comments are measured against the surface of that mode and are
/// all at or above WCAG AA for their use; `test/theme_contrast_test.dart`
/// re-measures every one of them.
library;

import 'package:flutter/material.dart';

import 'spacing.dart';

const _seed = Color(0xFF2547C4); // blue — derives the cool neutrals

abstract final class _Light {
  /// The page. Deliberately *not* white: panels are white and have to sit on
  /// something, since nothing is outlined any more.
  static const surface = Color(0xFFF2F2F7);
  static const surfaceContainer = Color(0xFFFFFFFF);
  static const surfaceContainerHigh = Color(0xFFE8E8EF);
  static const onSurface = Color(0xFF1B1B1F); // 15.4:1
  static const onSurfaceVariant = Color(0xFF46464F); // 8.4:1
  static const primary = Color(0xFF2547C4); // 6.8:1
  static const onPrimary = Color(0xFFFFFFFF); // 7.6:1 on primary
  static const primaryContainer = Color(0xFFDDE3FF); // pale tonal blue
  static const onPrimaryContainer = Color(0xFF152C7A); // 9.9:1
  static const outline = Color(0xFF74747E); // 4.1:1 — control edges
  static const outlineVariant = Color(0xFFC7C6D0); // hairline dividers only
  static const error = Color(0xFFBA1A1A); // 5.8:1
  static const onError = Color(0xFFFFFFFF); // 6.5:1 on error
  static const proof = Color(0xFF2547C4); // the accent itself — see below
  static const proofContainer = Color(0xFFFFEFC2); // pale tonal amber
  static const onProofContainer = Color(0xFF3D2E00); // 11.6:1 — the total
  static const onProofContainerMuted = Color(0xFF5C4600); // 7.9:1 — the labels
  static const warn = Color(0xFF7A5900); // 5.8:1
}

abstract final class _Dark {
  static const surface = Color(0xFF101014);
  static const surfaceContainer = Color(0xFF1C1C22);
  static const surfaceContainerHigh = Color(0xFF2A2A32);
  static const onSurface = Color(0xFFE5E1E9); // 14.7:1
  static const onSurfaceVariant = Color(0xFFC7C5D0); // 11.1:1
  static const primary = Color(0xFFB6C4FF); // 11.1:1
  static const onPrimary = Color(0xFF17275C); // 8.3:1 on primary
  static const primaryContainer = Color(0xFF33468F); // deep tonal blue
  static const onPrimaryContainer = Color(0xFFDDE3FF); // 6.8:1
  static const outline = Color(0xFF90909A); // 6.0:1 — control edges
  static const outlineVariant = Color(0xFF46464F); // hairline dividers only
  static const error = Color(0xFFFFB4AB); // 11.2:1
  static const onError = Color(0xFF690005); // 7.7:1 on error
  static const proof = Color(0xFFB6C4FF); // the accent itself — see below
  static const proofContainer = Color(0xFF4A3800); // deep tonal amber
  static const onProofContainer = Color(0xFFFFEFC2); // 9.9:1 — the total
  static const onProofContainerMuted = Color(0xFFE6CE8F); // 7.3:1 — the labels
  static const warn = Color(0xFFFFD24A); // 13.2:1
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

  @override
  BakingColors copyWith({
    Color? proof,
    Color? proofContainer,
    Color? onProofContainer,
    Color? onProofContainerMuted,
    Color? warn,
  }) => BakingColors(
    proof: proof ?? this.proof,
    proofContainer: proofContainer ?? this.proofContainer,
    onProofContainer: onProofContainer ?? this.onProofContainer,
    onProofContainerMuted: onProofContainerMuted ?? this.onProofContainerMuted,
    warn: warn ?? this.warn,
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
    );
  }
}

/// Weight for a variable font. Setting `fontWeight` alone makes Flutter
/// synthesise a bold; the variation selects the real designed weight.
List<FontVariation> _wght(double weight) => [FontVariation('wght', weight)];

/// Lining, fixed-width digits. Every gram and percentage uses this so columns
/// of numbers line up instead of shimmering as values change.
const tabularFigures = [FontFeature.tabularFigures()];

/// The face every gram and percentage is set in. Never applied without
/// [tabularFigures] — use [numeric] rather than reaching for either directly.
const numericFont = 'IBMPlexMono';

/// Headings and the big totals. Carries the display end of the scale, where
/// Plex Sans has no cut heavy enough.
const displayFont = 'PlusJakartaSans';

/// Sets [style] as a measurement: monospaced *and* tabular, so it reads as a
/// number off a scale rather than as prose. The two always travel together —
/// this is the only place they are applied.
///
/// The weight is clamped into the four cuts `pubspec.yaml` registers for Plex
/// Mono. Mono has no variable axis, so a heavier request would be synthesised
/// into a fake bold; clamping here means the display scale stays free to go
/// past 700 without every number that borrows one of its styles going smeary.
TextStyle numeric(TextStyle? style) {
  final base = style ?? const TextStyle();
  final value = (base.fontWeight ?? FontWeight.w400).value.clamp(400, 700);
  final weight = FontWeight.values[(value ~/ 100) - 1];
  return base.copyWith(
    fontFamily: numericFont,
    fontFeatures: tabularFigures,
    fontWeight: weight,
    fontVariations: _wght(value.toDouble()),
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
    fontFamily: 'IBMPlexSans',
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
    fontFamily: family,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: _wght(weight),
    letterSpacing: letterSpacing,
    color: color ?? colors.onSurface,
  );

  // The display face, set at the weights a soft layout can carry. Headings are
  // told apart from body by size and colour, not by shouting.
  TextStyle display(double size, double weight, {double? height}) => style(
    size,
    weight,
    height: height,
    letterSpacing: -size * 0.02,
    family: displayFont,
  );

  return TextTheme(
    displaySmall: display(40, 700, height: 1.1),
    headlineMedium: display(30, 700, height: 1.15),
    headlineSmall: display(24, 700, height: 1.2),
    titleLarge: display(20, 600, height: 1.25),
    titleMedium: display(17, 600, height: 1.3),
    titleSmall: style(15, 600, height: 1.4),
    bodyLarge: style(16, 400, height: 1.5),
    bodyMedium: style(14, 400, height: 1.5, color: colors.onSurfaceVariant),
    bodySmall: style(13, 400, height: 1.45, color: colors.onSurfaceVariant),
    // Section headings and field labels. Sentence case, so the tracking goes
    // back to the small positive values that sit well under 16 px.
    labelLarge: style(15, 600, height: 1.2, letterSpacing: 0.1),
    labelMedium: style(13, 600, height: 1.2, letterSpacing: 0.1),
    labelSmall: style(
      12,
      500,
      height: 1.2,
      letterSpacing: 0.2,
      color: colors.onSurfaceVariant,
    ),
  );
}
