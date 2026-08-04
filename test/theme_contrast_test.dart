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

      // The totals card and the dough-temp result box are both painted
      // `proofContainer`, and between them they land four different
      // foregrounds on it. A saturated container fails half of these, which is
      // exactly how a brand colour quietly breaks a warning message.
      test('everything drawn on proofContainer clears AA', () {
        final onContainer = {
          'onSurface (the total itself)': colors.onSurface,
          'onProofContainer (muted labels)': baking.onProofContainer,
          'warn (advisory text and icon)': baking.warn,
          'proof (the card border)': baking.proof,
        };
        for (final fg in onContainer.entries) {
          expectAtLeast(fg.key, fg.value, baking.proofContainer, 4.5);
        }
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

      test('numbers are set in the mono face at a weight that ships', () {
        expect(numericFont, 'IBMPlexMono');
        // pubspec registers 400/500/600/700; the text theme must not ask for a
        // weight with no file behind it, or Flutter synthesises a fake one.
        final weights = [
          theme.textTheme.bodyLarge,
          theme.textTheme.bodySmall,
          theme.textTheme.titleSmall,
          theme.textTheme.titleLarge,
          theme.textTheme.labelSmall,
          theme.textTheme.labelMedium,
          theme.textTheme.headlineSmall,
        ].map((s) => s!.fontWeight!.value);
        expect(weights, everyElement(isIn([400, 500, 600, 700])));
      });
    });
  }
}
