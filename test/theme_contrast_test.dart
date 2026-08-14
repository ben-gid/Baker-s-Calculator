/// Measures every contrast ratio the palette in `core/theme/app_theme.dart`
/// claims in its comments, so a future colour tweak cannot quietly drop a pair
/// below WCAG AA. Plain `test()` — no widget tree, no clock, no I/O.
library;

import 'dart:math' as math;

import 'package:bakers_calculator/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 relative luminance. Components are already 0..1 doubles.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    final name = brightness.name;
    final theme = buildTheme(brightness);
    final colors = theme.colorScheme;
    final baking = theme.extension<BakingColors>()!;

    /// Every background a foreground colour can land on.
    final backdrops = {
      'surface': colors.surface,
      'surfaceContainer': colors.surfaceContainer,
      'surfaceContainerHigh': colors.surfaceContainerHigh,
    };

    void expectAtLeast(String label, Color fg, Color bg, double minimum) {
      final ratio = _ratio(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(minimum),
        reason:
            '$name: $label is ${ratio.toStringAsFixed(2)}:1, '
            'needs $minimum:1',
      );
    }

    group('$name contrast', () {
      test('body and label text clears AA on every surface', () {
        final foregrounds = {
          'onSurface': colors.onSurface,
          'onSurfaceVariant': colors.onSurfaceVariant,
          'primary': colors.primary,
          'error': colors.error,
          'proof': baking.proof,
          'warn': baking.warn,
        };
        for (final fg in foregrounds.entries) {
          for (final bg in backdrops.entries) {
            expectAtLeast('${fg.key} on ${bg.key}', fg.value, bg.value, 4.5);
          }
        }
      });

      test('text on filled containers clears AA', () {
        expectAtLeast(
          'onPrimary on primary',
          colors.onPrimary,
          colors.primary,
          4.5,
        );
        expectAtLeast(
          'onPrimaryContainer on primaryContainer',
          colors.onPrimaryContainer,
          colors.primaryContainer,
          4.5,
        );
      });

      // The totals block is a warm tonal fill, and only two foregrounds are
      // drawn on it. Both are their own tokens because `onSurface` and
      // `onSurfaceVariant` are tuned against the page, not against amber, and
      // miss AA on it. `warn` and `proof` are deliberately kept off the block —
      // the dough-temp advisory sits below it. A third foreground here needs a
      // token and a line in this test, not a copyWith at the call site.
      test('both foregrounds on the proofContainer fill clear AA', () {
        expectAtLeast(
          'onProofContainer (the total)',
          baking.onProofContainer,
          baking.proofContainer,
          4.5,
        );
        expectAtLeast(
          'onProofContainerMuted (the labels)',
          baking.onProofContainerMuted,
          baking.proofContainer,
          4.5,
        );
      });

      // Every tonal container is a pale tint in light and a deep one in dark.
      // A pair that came out the same in both modes would mean one of them was
      // never designed against its own surface.
      test('tonal containers differ between the two modes', () {
        final other = buildTheme(
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
        );
        expect(
          colors.primaryContainer,
          isNot(other.colorScheme.primaryContainer),
        );
        expect(
          baking.proofContainer,
          isNot(other.extension<BakingColors>()!.proofContainer),
        );
      });

      // 1.4.11: the boundary of a control the baker can actually operate —
      // field borders, outlined and segmented buttons — is a non-text contrast
      // requirement. `outlineVariant` is exempt: it only draws card edges and
      // dividers, which carry no information on their own.
      test('interactive outlines clear the 3:1 non-text minimum', () {
        for (final bg in backdrops.entries) {
          expectAtLeast('outline on ${bg.key}', colors.outline, bg.value, 3.0);
        }
      });

      // pubspec registers Plex Mono at 400/500/600/700 only. The display scale
      // uses 800, which is fine for the variable faces but has no file behind
      // it in mono — so `numeric()` clamps rather than the text theme being
      // held back. This asserts the clamp, since that is what actually protects
      // the numbers now: every style is fed through it, including the heaviest.
      test('numbers are set in the mono face at a weight that ships', () {
        expect(numericFont, 'IBMPlexMono');
        for (final style in [
          theme.textTheme.displaySmall,
          theme.textTheme.headlineMedium,
          theme.textTheme.headlineSmall,
          theme.textTheme.titleLarge,
          theme.textTheme.titleMedium,
          theme.textTheme.titleSmall,
          theme.textTheme.bodyLarge,
          theme.textTheme.bodySmall,
          theme.textTheme.labelMedium,
          theme.textTheme.labelSmall,
        ]) {
          final measured = numeric(style);
          expect(measured.fontFamily, numericFont);
          expect(measured.fontFeatures, tabularFigures);
          expect(
            measured.fontWeight!.value,
            isIn([400, 500, 600, 700]),
            reason: 'mono has no file for w${measured.fontWeight!.value}',
          );
          // The variation has to agree with the weight, or a variable fallback
          // would render a different cut from the one asked for.
          expect(
            measured.fontVariations!.single.value,
            measured.fontWeight!.value.toDouble(),
          );
        }
      });

      // Two faces, and each is asked only for weights it can really draw.
      test('the display scale uses the geometric face', () {
        for (final style in [
          theme.textTheme.displaySmall,
          theme.textTheme.headlineMedium,
          theme.textTheme.headlineSmall,
          theme.textTheme.titleLarge,
          theme.textTheme.titleMedium,
        ]) {
          expect(style!.fontFamily, displayFont);
        }
        // Body and labels take the text face `ThemeData.fontFamily` applies.
        for (final style in [
          theme.textTheme.bodyLarge,
          theme.textTheme.bodySmall,
          theme.textTheme.labelMedium,
        ]) {
          expect(style!.fontFamily, 'IBMPlexSans');
        }
      });
    });
  }
}
