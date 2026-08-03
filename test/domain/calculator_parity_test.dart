/// Regression baseline for the baking engine.
///
/// `legacy_goldens.json` was generated from the original label-keyed
/// calculators before they were replaced, so every number the old app produced
/// is still asserted here. The engine must reproduce all of them except the two
/// deliberate corrections in [knownLegacyBugs].
///
/// Fixture, blend and mix-in names mirror the old UI-generated labels so the
/// two flat maps can be compared key-for-key.
library;

import 'dart:convert';
import 'dart:io';

import 'package:bakers_calculator/domain/calculator.dart';
import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/models/recipe.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Map<String, double>> loadGoldens() {
  final raw =
      jsonDecode(File('test/domain/legacy_goldens.json').readAsStringSync())
          as Map<String, dynamic>;
  return raw.map(
    (fixture, values) => MapEntry(
      fixture,
      (values as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    ),
  );
}

/// Where the engine deliberately departs from the recorded behaviour.
///
/// The old classic-dough path summed the egg COUNT into the total weight
/// instead of the egg weight, because it compared keys against `eggLabel`
/// ("Eggs") while enrichment stored them under `eggOutputLabel`. Sourdough and
/// preferment used the right constant, so an identical recipe totalled
/// differently depending on dough style.
///
/// Value = what the engine must now produce (count x 50 g).
const knownLegacyBugs = <String, Map<String, double>>{
  // 2 eggs: 937 - 2 + 100
  'classic/enriched': {'Total / Total Dough Weight': 1035.0},
  // 2 eggs: 997 - 2 + 100
  'classic/everything': {'Total / Total Dough Weight': 1095.0},
};

List<FlourPart> _blend(List<double> percents) => [
  for (var i = 0; i < percents.length; i++)
    FlourPart(name: 'Flour ${i + 1} (%):', percent: percents[i]),
];

List<MixIn> _mixIns(List<double> percents) => [
  for (var i = 0; i < percents.length; i++)
    MixIn(name: 'Mixin ${i + 1}(%)', percent: percents[i]),
];

const _classic = RecipeInput(
  style: DoughStyle.classic,
  flourWeight: 500,
  hydration: 70,
  salt: 2,
  yeast: 1,
);

const _sourdough = RecipeInput(
  style: DoughStyle.sourdough,
  totalDoughWeight: 900,
  hydration: 75,
  salt: 2,
  levainPercent: 20,
  levainHydration: 100,
);

const _preferment = RecipeInput(
  style: DoughStyle.preferment,
  totalDoughWeight: 900,
  hydration: 72,
  salt: 2,
  prefermentPercent: 30,
  prefermentHydration: 100,
  prefermentYeast: 0.2,
);

final inputs = <String, RecipeInput>{
  'classic/basic': _classic,
  'classic/enriched': _classic.copyWith(
    enrichment: const Enrichment(fatPercent: 8, sugarPercent: 6, eggCount: 2),
  ),
  'classic/blend': _classic.copyWith(flourBlend: _blend([60, 40])),
  'classic/mixins': _classic.copyWith(mixIns: _mixIns([15, 5])),
  'classic/everything': _classic.copyWith(
    enrichment: const Enrichment(fatPercent: 8, sugarPercent: 6, eggCount: 2),
    flourBlend: _blend([70, 20, 10]),
    mixIns: _mixIns([12]),
  ),

  'sourdough/basic': _sourdough,
  'sourdough/enriched': _sourdough.copyWith(
    enrichment: const Enrichment(fatPercent: 5, sugarPercent: 4, eggCount: 1),
  ),
  'sourdough/blend': _sourdough.copyWith(flourBlend: _blend([80, 20])),
  'sourdough/mixins': _sourdough.copyWith(mixIns: _mixIns([10, 8])),
  'sourdough/everything': _sourdough.copyWith(
    enrichment: const Enrichment(fatPercent: 5, sugarPercent: 4, eggCount: 1),
    flourBlend: _blend([65, 25, 10]),
    mixIns: _mixIns([10]),
  ),

  'preferment/basic': _preferment,
  'preferment/enriched': _preferment.copyWith(
    enrichment: const Enrichment(fatPercent: 10, sugarPercent: 8, eggCount: 3),
  ),
  'preferment/blend': _preferment.copyWith(flourBlend: _blend([75, 25])),
  'preferment/mixins': _preferment.copyWith(mixIns: _mixIns([20])),
  'preferment/everything': _preferment.copyWith(
    enrichment: const Enrichment(fatPercent: 10, sugarPercent: 8, eggCount: 3),
    flourBlend: _blend([50, 30, 20]),
    mixIns: _mixIns([6, 4]),
  ),
};

/// Re-labels a [Recipe] into the legacy engine's flat key space so the two can
/// be diffed. Test-only: the app never uses these names.
Map<String, double> toLegacyShape(Recipe recipe, DoughStyle style) {
  final flat = <String, double>{};
  for (final group in recipe.groups) {
    final prefixed = group.name == 'Levain' || group.name == 'Preferment';
    for (final ingredient in group.ingredients) {
      final name = switch (ingredient.name) {
        // Legacy stored the egg COUNT under this label; the corrected total is
        // what knownLegacyBugs asserts on.
        'Eggs' => "'Large' Eggs (about 50.0 each)",
        final n when prefixed => '${group.name} $n',
        final n => n,
      };
      flat['${group.name} / $name'] = ingredient.count ?? ingredient.grams;
    }
    if (prefixed) flat['${group.name} / ${group.name} Total'] = group.grams;
  }
  flat['Total / Total Dough Weight'] = recipe.totalWeight;
  if (!style.isForward) {
    flat['Total / Flour Total'] = recipe.totalFlour;
    flat['Total / Water Total'] = recipe.totalWater;
  }
  return flat;
}

void main() {
  final goldens = loadGoldens();

  test('every golden has a domain fixture', () {
    expect(inputs.keys.toSet(), goldens.keys.toSet());
  });

  goldens.forEach((name, golden) {
    test('domain parity: $name', () {
      final input = inputs[name]!;
      final actual = toLegacyShape(calculate(input), input.style);
      final expected = {...golden, ...?knownLegacyBugs[name]};

      expect(actual.keys.toSet(), expected.keys.toSet());
      for (final entry in expected.entries) {
        expect(
          actual[entry.key],
          closeTo(entry.value, 1e-9),
          reason: '$name -> ${entry.key}',
        );
      }
    });
  });

  group('regressions the port fixes', () {
    test('egg weight, not egg count, lands in the total', () {
      final withEggs = calculate(
        _classic.copyWith(enrichment: const Enrichment(eggCount: 2)),
      );
      final withoutEggs = calculate(_classic);
      expect(withEggs.totalWeight - withoutEggs.totalWeight, closeTo(100, 1e-9));
    });

    test('classic and sourdough agree on what an egg weighs', () {
      double eggDelta(RecipeInput base) =>
          calculate(base.copyWith(enrichment: const Enrichment(eggCount: 2)))
              .totalWeight -
          calculate(base).totalWeight;
      // Sourdough holds total weight fixed, so its delta is 0 by construction;
      // the point is that neither engine path treats a count as grams.
      expect(eggDelta(_classic), closeTo(100, 1e-9));
      expect(eggDelta(_sourdough), closeTo(0, 1e-9));
    });

    test('blended flours report percentages against total flour', () {
      final recipe = calculate(_sourdough.copyWith(flourBlend: _blend([80, 20])));
      final dough = recipe.groups.firstWhere((g) => g.name == 'Dough');
      final percents = dough.ingredients
          .where((i) => i.name.startsWith('Flour '))
          .map((i) => i.bakersPercent!)
          .toList();
      // 80/20 of the MAIN flour, which is 90% of total flour once the levain's
      // share is set aside -> 72% and 18%, and the group says so.
      expect(percents, [closeTo(72, 1e-6), closeTo(18, 1e-6)]);
      expect(dough.note, contains('in the levain'));
    });

    test('loaves scales every weight but not the percentages', () {
      final one = calculate(_sourdough);
      final three = calculate(_sourdough.copyWith(loaves: 3));
      expect(three.totalWeight, closeTo(one.totalWeight * 3, 1e-9));
      expect(three.hydration, closeTo(one.hydration, 1e-9));
      expect(
        three.groups.first.ingredients.first.bakersPercent,
        closeTo(one.groups.first.ingredients.first.bakersPercent!, 1e-9),
      );
    });

    test('missing required fields throw instead of crashing on null', () {
      expect(
        () => calculate(const RecipeInput(style: DoughStyle.classic)),
        throwsA(isA<MissingFieldError>()),
      );
    });
  });
}
