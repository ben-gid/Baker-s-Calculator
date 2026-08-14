/// The baking engine. Pure Dart — no Flutter, no globals, no I/O.
///
/// **The flour in the dough is 100%.** Every percentage the baker types —
/// hydration, salt, levain, preferment, fat, sugar, mix-ins — is a share of the
/// flour weighed into the mixing bowl, and a levain or preferment is just
/// another ingredient measured against it. That is how a written recipe reads
/// ("500 g flour, 375 g water, 100 g starter"), and it means the flour row says
/// 100% whether or not there is a preferment.
///
/// The flour and water a levain carries in are still counted in
/// [Recipe.totalFlour], [Recipe.totalWater] and [Recipe.hydration], so the
/// totals card shows the dough's true hydration, which sits a little above the
/// figure typed in.
///
/// Classic defaults *forward*: flour weight is given. The other two default
/// *inverse*: finished dough weight is given, so flour is solved by dividing
/// by the baker's-percentage denominator. Eggs are a count, not a percentage,
/// so their weight comes off before the division.
/// [RecipeInput.byFlourWeight] overrides which way any style runs — see
/// [RecipeInput.solvesForward].
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
// Classic: forward by default — flour weight is given and everything scales
// off it. [RecipeInput.byFlourWeight] can flip any style the other way; see
// `_solveDoughFlour`.
// ---------------------------------------------------------------------------

Recipe _classic(RecipeInput input) {
  final hydration = _require(input.hydration, 'hydration');
  final salt = _require(input.salt, 'salt');
  final yeast = _require(input.yeast, 'yeast');
  final doughFlour = input.solvesForward
      ? _require(input.flourWeight, 'flourWeight')
      : _solveDoughFlour(input, _denominator(input, hydration, salt, 0));
  final water = doughFlour * hydration / 100;

  final dough = <Ingredient>[
    ..._flourRows(input, doughFlour),
    _pct('Water', water, doughFlour),
    _pct('Yeast', doughFlour * yeast / 100, doughFlour),
    _pct('Salt', doughFlour * salt / 100, doughFlour),
    ..._enrichmentRows(input, doughFlour),
    ..._mixInRows(input, doughFlour),
  ];

  return _assemble(
    groups: [IngredientGroup(name: 'Dough', ingredients: dough)],
    input: input,
    totalFlour: doughFlour,
    totalWater: water,
  );
}

// ---------------------------------------------------------------------------
// Sourdough / preferment: inverse by default. The dough weighs
//
//   doughFlour * (1 + hydration + salt + levain + fat + sugar) + eggs
//
// with every term a fraction of the dough's flour, so the flour is that weight
// less the eggs, divided by the bracket. The levain enters whole — flour, water
// and yeast together — because it is weighed out as one lump. When
// [RecipeInput.byFlourWeight] flips the input the other way, flour is simply
// what was typed — the levain/preferment split below reads off it exactly the
// same either way.
// ---------------------------------------------------------------------------

Recipe _sourdough(RecipeInput input) {
  final levainPercent = _require(input.levainPercent, 'levainPercent');
  final levainHydration = _require(input.levainHydration, 'levainHydration');
  final hydration = _require(input.hydration, 'hydration');
  final salt = _require(input.salt, 'salt');

  final doughFlour = input.solvesForward
      ? _require(input.flourWeight, 'flourWeight')
      : _solveDoughFlour(
          input,
          _denominator(input, hydration, salt, levainPercent),
        );
  final water = doughFlour * hydration / 100;

  final levainTotal = doughFlour * levainPercent / 100;
  final levainFlour = levainTotal / (1 + levainHydration / 100);
  final levainWater = levainTotal - levainFlour;

  return _assemble(
    groups: [
      IngredientGroup(
        name: 'Levain',
        ingredients: [
          _pct('Flour', levainFlour, doughFlour),
          _pct('Water', levainWater, doughFlour),
        ],
      ),
      IngredientGroup(
        name: 'Dough',
        ingredients: [
          ..._flourRows(input, doughFlour),
          _pct('Water', water, doughFlour),
          _pct('Salt', doughFlour * salt / 100, doughFlour),
          ..._enrichmentRows(input, doughFlour),
          ..._mixInRows(input, doughFlour),
        ],
      ),
    ],
    input: input,
    totalFlour: doughFlour + levainFlour,
    totalWater: water + levainWater,
  );
}

Recipe _preferment(RecipeInput input) {
  final prefermentPercent = _require(
    input.prefermentPercent,
    'prefermentPercent',
  );
  final prefermentHydration = _require(
    input.prefermentHydration,
    'prefermentHydration',
  );
  final prefermentYeast = _require(input.prefermentYeast, 'prefermentYeast');
  final hydration = _require(input.hydration, 'hydration');
  final salt = _require(input.salt, 'salt');

  final doughFlour = input.solvesForward
      ? _require(input.flourWeight, 'flourWeight')
      : _solveDoughFlour(
          input,
          _denominator(input, hydration, salt, prefermentPercent),
        );
  final water = doughFlour * hydration / 100;

  // The preferment's own hydration and yeast are shares of ITS flour, so the
  // lump splits three ways in the ratio 1 : hydration : yeast.
  final prefermentTotal = doughFlour * prefermentPercent / 100;
  final prefermentFlour =
      prefermentTotal / (1 + prefermentHydration / 100 + prefermentYeast / 100);
  final prefermentWater = prefermentFlour * prefermentHydration / 100;
  final prefermentYeastWeight = prefermentFlour * prefermentYeast / 100;

  return _assemble(
    groups: [
      IngredientGroup(
        name: 'Preferment',
        ingredients: [
          _pct('Flour', prefermentFlour, doughFlour),
          _pct('Water', prefermentWater, doughFlour),
          _pct('Yeast', prefermentYeastWeight, doughFlour),
        ],
      ),
      IngredientGroup(
        name: 'Dough',
        ingredients: [
          ..._flourRows(input, doughFlour),
          _pct('Water', water, doughFlour),
          _pct('Salt', doughFlour * salt / 100, doughFlour),
          ..._enrichmentRows(input, doughFlour),
          ..._mixInRows(input, doughFlour),
        ],
      ),
    ],
    input: input,
    totalFlour: doughFlour + prefermentFlour,
    totalWater: water + prefermentWater,
  );
}

/// Everything the dough weighs, per gram of dough flour. Mix-ins are left out
/// on purpose: "total dough weight" is the dough, and seeds or olives are added
/// on top of it. [input.yeast] only has a value for [DoughStyle.classic] — it
/// is null, hence 0, for the other two styles' own denominator.
double _denominator(
  RecipeInput input,
  double hydration,
  double salt,
  double leavenPercent,
) {
  final enrichment = input.enrichmentOrEmpty;
  return 1 +
      hydration / 100 +
      salt / 100 +
      leavenPercent / 100 +
      (input.yeast ?? 0) / 100 +
      (enrichment.fatPercent ?? 0) / 100 +
      (enrichment.sugarPercent ?? 0) / 100;
}

/// Solves dough flour from [RecipeInput.totalDoughWeight] when the input runs
/// inverse — the shared half of the algebra in the module comment, factored
/// out so classic can use it too now that any style can go either direction.
double _solveDoughFlour(RecipeInput input, double denominator) {
  final doughWeight = _require(input.totalDoughWeight, 'totalDoughWeight');
  return (doughWeight - input.enrichmentOrEmpty.eggGrams) / denominator;
}

// ---------------------------------------------------------------------------
// Shared row builders
// ---------------------------------------------------------------------------

Ingredient _pct(String name, double grams, double doughFlour) => Ingredient(
  name: name,
  grams: grams,
  bakersPercent: doughFlour == 0 ? null : grams / doughFlour * 100,
);

/// Splits [doughFlour] across the blend, or emits a single "Flour" row when the
/// baker did not specify one. Either way the rows add up to 100%.
List<Ingredient> _flourRows(RecipeInput input, double doughFlour) {
  if (input.flourBlend.isEmpty) {
    return [_pct('Flour', doughFlour, doughFlour)];
  }
  return [
    for (final part in input.flourBlend)
      _pct(
        part.name,
        doughFlour * _require(part.percent, 'flourBlend.percent') / 100,
        doughFlour,
      ),
  ];
}

List<Ingredient> _enrichmentRows(RecipeInput input, double doughFlour) {
  final enrichment = input.enrichment;
  if (enrichment == null || enrichment.isEmpty) return const [];
  return [
    if (enrichment.fatPercent != null)
      _pct('Fat', doughFlour * enrichment.fatPercent! / 100, doughFlour),
    if (enrichment.sugarPercent != null)
      _pct('Sugar', doughFlour * enrichment.sugarPercent! / 100, doughFlour),
    if (enrichment.eggCount != null)
      Ingredient(
        name: 'Eggs',
        grams: enrichment.eggGrams,
        bakersPercent: doughFlour == 0
            ? null
            : enrichment.eggGrams / doughFlour * 100,
        count: enrichment.eggCount,
      ),
  ];
}

List<Ingredient> _mixInRows(RecipeInput input, double doughFlour) => [
  for (final mixIn in input.mixIns)
    _pct(
      mixIn.name,
      doughFlour * _require(mixIn.percent, 'mixIns.percent') / 100,
      doughFlour,
    ),
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
