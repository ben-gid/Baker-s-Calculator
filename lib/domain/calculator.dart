/// The baking engine. Pure Dart — no Flutter, no globals, no I/O.
///
/// The algebra is ported verbatim from the original `quick_calculate_recipe.dart`
/// and pinned by `test/domain/legacy_parity_test.dart`. Two things changed
/// deliberately, both documented in that test's `knownLegacyBugs`:
///
///  * eggs contribute their WEIGHT to the total, not their count;
///  * a flour blend's percentages are reported against total flour, and the
///    group says so, instead of being silently main-dough-only.
library;

import 'models/dough_style.dart';
import 'models/recipe.dart';
import 'models/recipe_input.dart';

/// Thrown when a required field for [RecipeInput.style] is missing. Call
/// `validate()` first; this is the last line of defence, not the UI's error
/// path.
class MissingFieldError extends ArgumentError {
  MissingFieldError(String field) : super('Missing required field: $field');
}

double _require(double? value, String field) {
  if (value == null) throw MissingFieldError(field);
  return value;
}

Recipe calculate(RecipeInput input) {
  final recipe = switch (input.style) {
    DoughStyle.classic => _classic(input),
    DoughStyle.sourdough => _sourdough(input),
    DoughStyle.preferment => _preferment(input),
  };
  return input.loaves > 1 ? recipe.scaled(input.loaves.toDouble()) : recipe;
}

// ---------------------------------------------------------------------------
// Classic: forward. Flour weight is given; everything scales off it.
// ---------------------------------------------------------------------------

Recipe _classic(RecipeInput input) {
  final flourTotal = _require(input.flourWeight, 'flourWeight');
  final water = flourTotal * input.hydration / 100;

  final dough = <Ingredient>[
    ..._flourRows(input, flourTotal, flourTotal),
    _pct('Water', water, flourTotal),
    _pct('Yeast', flourTotal * _require(input.yeast, 'yeast') / 100, flourTotal),
    _pct('Salt', flourTotal * input.salt / 100, flourTotal),
    ..._enrichmentRows(input, flourTotal),
    ..._mixInRows(input, flourTotal),
  ];

  return _assemble(
    groups: [IngredientGroup(name: 'Dough', ingredients: dough)],
    input: input,
    totalFlour: flourTotal,
    totalWater: water,
  );
}

// ---------------------------------------------------------------------------
// Sourdough / preferment: inverse. Finished dough weight is given, so flour is
// solved by dividing by the baker's-percentage denominator. Eggs are counted
// in grams and removed BEFORE the division, because they are not a percentage
// of flour.
// ---------------------------------------------------------------------------

Recipe _sourdough(RecipeInput input) {
  final doughWeight = _require(input.totalDoughWeight, 'totalDoughWeight');
  final levainPercent = _require(input.levainPercent, 'levainPercent');
  final levainHydration = _require(input.levainHydration, 'levainHydration');
  final enrichment = input.enrichmentOrEmpty;

  final denominator =
      1 +
      input.hydration / 100 +
      input.salt / 100 +
      (enrichment.fatPercent ?? 0) / 100 +
      (enrichment.sugarPercent ?? 0) / 100;

  final flourTotal = (doughWeight - enrichment.eggGrams) / denominator;
  final waterTotal = flourTotal * input.hydration / 100;

  final levainTotal = flourTotal * levainPercent / 100;
  final levainFlour = levainTotal / (1 + levainHydration / 100);
  final levainWater = levainTotal - levainFlour;

  final mainFlour = flourTotal - levainFlour;
  final mainWater = waterTotal - levainWater;

  return _assemble(
    groups: [
      IngredientGroup(
        name: 'Levain',
        ingredients: [
          _pct('Flour', levainFlour, flourTotal),
          _pct('Water', levainWater, flourTotal),
        ],
      ),
      IngredientGroup(
        name: 'Dough',
        note: _blendNote(input, levainFlour, 'levain'),
        ingredients: [
          ..._flourRows(input, mainFlour, flourTotal),
          _pct('Water', mainWater, flourTotal),
          _pct('Salt', flourTotal * input.salt / 100, flourTotal),
          ..._enrichmentRows(input, flourTotal),
          ..._mixInRows(input, flourTotal),
        ],
      ),
    ],
    input: input,
    totalFlour: flourTotal,
    totalWater: waterTotal,
  );
}

Recipe _preferment(RecipeInput input) {
  final doughWeight = _require(input.totalDoughWeight, 'totalDoughWeight');
  final prefermentPercent =
      _require(input.prefermentPercent, 'prefermentPercent');
  final prefermentHydration =
      _require(input.prefermentHydration, 'prefermentHydration');
  final prefermentYeast = _require(input.prefermentYeast, 'prefermentYeast');
  final enrichment = input.enrichmentOrEmpty;

  // The yeast living inside the preferment is a percentage of the preferment's
  // flour, so it has to be re-expressed against TOTAL flour before it can join
  // the denominator: preferment share -> its flour share -> its yeast share.
  final prefermentYeastOfTotalFlour =
      prefermentPercent /
      100 /
      (1 + prefermentYeast / 100 + prefermentHydration / 100) *
      prefermentYeast /
      100;

  final denominator =
      1 +
      input.hydration / 100 +
      input.salt / 100 +
      prefermentYeastOfTotalFlour +
      (enrichment.fatPercent ?? 0) / 100 +
      (enrichment.sugarPercent ?? 0) / 100;

  final flourTotal = (doughWeight - enrichment.eggGrams) / denominator;
  final waterTotal = flourTotal * input.hydration / 100;

  final prefermentTotal = flourTotal * prefermentPercent / 100;
  final prefermentFlour =
      prefermentTotal /
      (1 + prefermentHydration / 100 + prefermentYeast / 100);
  final prefermentWater = prefermentFlour * prefermentHydration / 100;
  final prefermentYeastWeight = prefermentFlour * prefermentYeast / 100;

  final mainFlour = flourTotal - prefermentFlour;
  final mainWater = waterTotal - prefermentWater;

  return _assemble(
    groups: [
      IngredientGroup(
        name: 'Preferment',
        ingredients: [
          _pct('Flour', prefermentFlour, flourTotal),
          _pct('Water', prefermentWater, flourTotal),
          _pct('Yeast', prefermentYeastWeight, flourTotal),
        ],
      ),
      IngredientGroup(
        name: 'Dough',
        note: _blendNote(input, prefermentFlour, 'preferment'),
        ingredients: [
          ..._flourRows(input, mainFlour, flourTotal),
          _pct('Water', mainWater, flourTotal),
          _pct('Salt', flourTotal * input.salt / 100, flourTotal),
          ..._enrichmentRows(input, flourTotal),
          ..._mixInRows(input, flourTotal),
        ],
      ),
    ],
    input: input,
    totalFlour: flourTotal,
    totalWater: waterTotal,
  );
}

// ---------------------------------------------------------------------------
// Shared row builders
// ---------------------------------------------------------------------------

Ingredient _pct(String name, double grams, double totalFlour) => Ingredient(
  name: name,
  grams: grams,
  bakersPercent: totalFlour == 0 ? null : grams / totalFlour * 100,
);

/// Splits [flourHere] across the blend, or emits a single "Flour" row when the
/// baker did not specify a blend. Percentages are always reported against
/// [totalFlour] so every number on screen shares one denominator.
List<Ingredient> _flourRows(
  RecipeInput input,
  double flourHere,
  double totalFlour,
) {
  if (input.flourBlend.isEmpty) {
    return [_pct('Flour', flourHere, totalFlour)];
  }
  return [
    for (final part in input.flourBlend)
      _pct(part.name, flourHere * part.percent / 100, totalFlour),
  ];
}

/// Explains that the flour percentages shown exclude the flour already used in
/// the levain/preferment — the original UI showed neither the note nor the
/// percentages, which made blended recipes impossible to read.
String? _blendNote(RecipeInput input, double flourElsewhere, String where) {
  if (input.flourBlend.isEmpty) return null;
  return 'Blend applies to the dough flour. '
      '${flourElsewhere.toStringAsFixed(0)} g of flour is in the $where above.';
}

List<Ingredient> _enrichmentRows(RecipeInput input, double totalFlour) {
  final enrichment = input.enrichment;
  if (enrichment == null || enrichment.isEmpty) return const [];
  return [
    if (enrichment.fatPercent != null)
      _pct('Fat', totalFlour * enrichment.fatPercent! / 100, totalFlour),
    if (enrichment.sugarPercent != null)
      _pct('Sugar', totalFlour * enrichment.sugarPercent! / 100, totalFlour),
    if (enrichment.eggCount != null)
      Ingredient(
        name: 'Eggs',
        grams: enrichment.eggGrams,
        bakersPercent:
            totalFlour == 0 ? null : enrichment.eggGrams / totalFlour * 100,
        count: enrichment.eggCount,
      ),
  ];
}

List<Ingredient> _mixInRows(RecipeInput input, double totalFlour) => [
  for (final mixIn in input.mixIns)
    _pct(mixIn.name, totalFlour * mixIn.percent / 100, totalFlour),
];

Recipe _assemble({
  required List<IngredientGroup> groups,
  required RecipeInput input,
  required double totalFlour,
  required double totalWater,
}) {
  final totalWeight = groups.fold(0.0, (sum, group) => sum + group.grams);
  return Recipe(
    groups: groups,
    totalWeight: totalWeight,
    totalFlour: totalFlour,
    totalWater: totalWater,
    hydration: totalFlour == 0 ? 0 : totalWater / totalFlour * 100,
    loaves: input.loaves,
  );
}
