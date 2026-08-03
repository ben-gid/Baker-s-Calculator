/// Regression baseline for the baking engine.
///
/// `legacy_goldens.json` was generated from the original label-keyed
/// calculators before they were replaced. Classic doughs must still reproduce
/// every number in it, except the two deliberate corrections in
/// [knownLegacyBugs].
///
/// The inverse styles are exempt — see [rebasedStyles]. They are pinned instead
/// by the `dough flour is 100%` group below, which asserts the algebra itself
/// rather than a recorded output, so there is nothing to regenerate.
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

/// Styles whose goldens no longer describe the product, because the *meaning of
/// their inputs* changed rather than the arithmetic drifting.
///
/// The legacy engine measured everything against TOTAL flour, so a levain
/// carried part of the 100% and the dough's own flour row read 90% or less. The
/// app now measures against the flour in the dough, which is 100%, and a levain
/// or preferment is an ingredient weighed against it — the way a written recipe
/// reads. Every gram in those fixtures moves as a result, so re-recording them
/// would say nothing; the invariants in `dough flour is 100%` are asserted
/// instead. The goldens stay in the file as the historical record.
const rebasedStyles = {'sourdough', 'preferment'};

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
    if (rebasedStyles.contains(name.split('/').first)) return;

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
      expect(
        withEggs.totalWeight - withoutEggs.totalWeight,
        closeTo(100, 1e-9),
      );
    });

    test('classic and sourdough agree on what an egg weighs', () {
      double eggDelta(RecipeInput base) =>
          calculate(
            base.copyWith(enrichment: const Enrichment(eggCount: 2)),
          ).totalWeight -
          calculate(base).totalWeight;
      // Sourdough holds total weight fixed, so its delta is 0 by construction;
      // the point is that neither engine path treats a count as grams.
      expect(eggDelta(_classic), closeTo(100, 1e-9));
      expect(eggDelta(_sourdough), closeTo(0, 1e-9));
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

  group('dough flour is 100%', () {
    /// The flour rows of the group the baker actually mixes.
    List<Ingredient> doughFlourRows(Recipe recipe, RecipeInput input) {
      final dough = recipe.groups.firstWhere((g) => g.name == 'Dough');
      final names = input.flourBlend.isEmpty
          ? {'Flour'}
          : input.flourBlend.map((f) => f.name).toSet();
      return dough.ingredients.where((i) => names.contains(i.name)).toList();
    }

    for (final entry in {
      'classic': _classic,
      'sourdough': _sourdough,
      'preferment': _preferment,
    }.entries) {
      test('${entry.key}: the single flour row is exactly 100%', () {
        final rows = doughFlourRows(calculate(entry.value), entry.value);
        expect(rows.single.bakersPercent, closeTo(100, 1e-9));
      });

      test('${entry.key}: a blend splits that 100% as typed', () {
        final input = entry.value.copyWith(flourBlend: _blend([65, 25, 10]));
        final rows = doughFlourRows(calculate(input), input);
        expect(rows.map((r) => r.bakersPercent), [
          closeTo(65, 1e-9),
          closeTo(25, 1e-9),
          closeTo(10, 1e-9),
        ]);
      });
    }

    test('every percentage is a share of the dough flour, levain included', () {
      final recipe = calculate(_sourdough);
      final flour = doughFlourRows(recipe, _sourdough).single.grams;
      final dough = recipe.groups.firstWhere((g) => g.name == 'Dough');
      final levain = recipe.groups.firstWhere((g) => g.name == 'Levain');

      double gramsOf(IngredientGroup group, String name) =>
          group.ingredients.firstWhere((i) => i.name == name).grams;

      // 900 g at 75/2/20 -> 1 + 0.75 + 0.02 + 0.20 = 1.97 shares of flour.
      expect(flour, closeTo(900 / 1.97, 1e-9));
      expect(gramsOf(dough, 'Water'), closeTo(flour * 0.75, 1e-9));
      expect(gramsOf(dough, 'Salt'), closeTo(flour * 0.02, 1e-9));
      // The levain is weighed out whole, then split by its own hydration.
      expect(levain.grams, closeTo(flour * 0.20, 1e-9));
      expect(gramsOf(levain, 'Flour'), closeTo(flour * 0.10, 1e-9));
      expect(gramsOf(levain, 'Water'), closeTo(flour * 0.10, 1e-9));
      // ...and the whole thing still weighs what was asked for.
      expect(recipe.totalWeight, closeTo(900, 1e-9));
    });

    test('the totals count the flour and water the levain carries in', () {
      final recipe = calculate(_sourdough);
      final flour = doughFlourRows(recipe, _sourdough).single.grams;

      expect(recipe.totalFlour, closeTo(flour * 1.10, 1e-9));
      expect(recipe.totalWater, closeTo(flour * 0.85, 1e-9));
      // So the true hydration reads above the 75% that was typed.
      expect(recipe.hydration, closeTo(85 / 110 * 100, 1e-9));
    });

    test('a preferment carries its own yeast, not the dough denominator', () {
      final recipe = calculate(_preferment);
      final flour = doughFlourRows(recipe, _preferment).single.grams;
      final pre = recipe.groups.firstWhere((g) => g.name == 'Preferment');

      // 900 g at 72/2/30 -> 1 + 0.72 + 0.02 + 0.30 = 2.04.
      expect(flour, closeTo(900 / 2.04, 1e-9));
      expect(pre.grams, closeTo(flour * 0.30, 1e-9));
      // The lump splits 1 : 1.00 : 0.002 between flour, water and yeast.
      final prefermentFlour = pre.ingredients.first.grams;
      expect(prefermentFlour, closeTo(flour * 0.30 / 2.002, 1e-9));
      expect(pre.ingredients[1].grams, closeTo(prefermentFlour, 1e-9));
      expect(pre.ingredients[2].grams, closeTo(prefermentFlour * 0.002, 1e-9));
      expect(recipe.totalWeight, closeTo(900, 1e-9));
    });
  });
}
