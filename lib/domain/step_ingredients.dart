/// What goes into the bowl at each step of a bake.
///
/// Every row comes from the recipe the calculator produced, matched by
/// [IngredientRole] rather than by name. Each ingredient has a home step — the
/// flour and water at the autolyse, the levain and salt at the mix, seeds with
/// the first fold — and a step left out hands its rows to the next one, so
/// nothing is ever forgotten. The one exception is a skipped levain feed or
/// preferment build: the baker already has one ripe, and the mix lists it
/// whole.
library;

import 'models/recipe.dart';
import 'timeline.dart';

/// A levain feed is built a little bigger than the dough needs: some always
/// sticks to the jar, and what is left over can seed the next bake.
const feedExtra = 0.1;

/// How to feed the levain for [recipe] at [ratio]. The ripe starter is taken
/// to be at 100% hydration, and the feed is balanced so the finished levain
/// lands on the recipe's own levain hydration. Null for a dough without one.
({double starter, double flour, double water, double keepBack})? levainFeed(
  Recipe recipe,
  FeedRatio ratio,
) {
  final levain = recipe.leaven;
  if (levain == null || !_isLevain(levain)) return null;
  final flour = _sum(levain, IngredientRole.flour) * (1 + feedExtra);
  final water = _sum(levain, IngredientRole.water) * (1 + feedExtra);
  // The starter carries half its weight as flour: starter / 2 + parts *
  // starter is all the flour in the build.
  final starter = flour / (ratio.parts + 0.5);
  return (
    starter: starter,
    flour: flour - starter / 2,
    water: water - starter / 2,
    keepBack: levain.grams * feedExtra,
  );
}

/// One list of rows per step of [steps], in the same order. A skipped step's
/// list is empty and its rows appear on the next step that is not skipped.
List<List<Ingredient>> stepIngredients(
  Recipe recipe,
  List<BakeStep> steps, {
  required List<bool> skipped,
  FeedRatio ratio = FeedRatio.r122,
}) {
  final kinds = steps.map((s) => s.kind).toSet();
  final dough = recipe.groups.last.ingredients;
  final leaven = recipe.leaven;
  final firstFold = steps.indexWhere((s) => s.kind == StepKind.fold);
  final sourdough = leaven != null && _isLevain(leaven);

  bool any(Ingredient i, Set<IngredientRole> roles) => roles.contains(i.role);

  List<Ingredient> home(int index) {
    final kind = steps[index].kind;
    final mixInsHere = sourdough && firstFold >= 0
        ? index == firstFold
        : kind == StepKind.mix;
    return [
      if (kind == StepKind.levain) ..._feedRows(recipe, ratio),
      if (kind == StepKind.preferment && leaven != null) ...leaven.ingredients,
      if (kind == StepKind.autolyse ||
          (kind == StepKind.mix && !kinds.contains(StepKind.autolyse)))
        ...dough.where(
          (i) => any(i, {IngredientRole.flour, IngredientRole.water}),
        ),
      if (kind == StepKind.mix) ...[
        if (leaven != null)
          Ingredient(
            name: sourdough ? 'Levain' : 'Preferment',
            grams: leaven.grams,
            role: IngredientRole.leaven,
          ),
        ...dough.where(
          (i) => any(i, {
            IngredientRole.salt,
            IngredientRole.yeast,
            IngredientRole.fat,
            IngredientRole.sugar,
            IngredientRole.eggs,
          }),
        ),
      ],
      if (mixInsHere) ...dough.where((i) => i.role == IngredientRole.mixIn),
    ];
  }

  final out = <List<Ingredient>>[];
  var carried = <Ingredient>[];
  for (var i = 0; i < steps.length; i++) {
    final feed =
        steps[i].kind == StepKind.levain ||
        steps[i].kind == StepKind.preferment;
    final rows = [...carried, if (!(skipped[i] && feed)) ...home(i)];
    if (skipped[i]) {
      carried = rows;
      out.add(const []);
    } else {
      carried = [];
      out.add(rows);
    }
  }
  return out;
}

List<Ingredient> _feedRows(Recipe recipe, FeedRatio ratio) {
  final feed = levainFeed(recipe, ratio);
  if (feed == null) return const [];
  return [
    Ingredient(
      name: 'Ripe starter',
      grams: feed.starter,
      role: IngredientRole.starter,
    ),
    Ingredient(name: 'Flour', grams: feed.flour, role: IngredientRole.flour),
    Ingredient(name: 'Water', grams: feed.water, role: IngredientRole.water),
  ];
}

// A preferment carries yeast; a levain is only flour and water.
bool _isLevain(IngredientGroup group) =>
    !group.ingredients.any((i) => i.role == IngredientRole.yeast);

double _sum(IngredientGroup group, IngredientRole role) => group.ingredients
    .where((i) => i.role == role)
    .fold(0.0, (sum, i) => sum + i.grams);
