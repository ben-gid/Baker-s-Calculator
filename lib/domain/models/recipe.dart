/// The calculator's output: a flat, display-ready ingredient list.
///
/// Everything here is already in grams. Unlike the original engine, an egg's
/// [Ingredient.grams] is its *weight*, with the count carried separately in
/// [Ingredient.count] purely for display — so totals can never accidentally
/// sum a count as if it were a weight.
library;

class Ingredient {
  const Ingredient({
    required this.name,
    required this.grams,
    this.bakersPercent,
    this.count,
  });

  final String name;
  final double grams;

  /// Weight as a percentage of the flour in the dough, which is 100%. Null only
  /// when there is no flour to divide by.
  final double? bakersPercent;

  /// Set for ingredients counted rather than weighed (eggs). Display shows the
  /// count; [grams] is still the authoritative weight.
  final double? count;

  Ingredient scaled(double factor) => Ingredient(
    name: name,
    grams: grams * factor,
    bakersPercent: bakersPercent,
    count: count == null ? null : count! * factor,
  );
}

class IngredientGroup {
  const IngredientGroup({required this.name, required this.ingredients});

  final String name;
  final List<Ingredient> ingredients;

  double get grams =>
      ingredients.fold(0.0, (sum, ingredient) => sum + ingredient.grams);

  IngredientGroup scaled(double factor) => IngredientGroup(
    name: name,
    ingredients: [for (final i in ingredients) i.scaled(factor)],
  );
}

class Recipe {
  const Recipe({
    required this.groups,
    required this.totalWeight,
    required this.totalFlour,
    required this.totalWater,
    required this.hydration,
    required this.loaves,
  });

  final List<IngredientGroup> groups;

  /// Weight of everything, for all [loaves].
  final double totalWeight;
  final double totalFlour;
  final double totalWater;

  /// Effective hydration, recomputed from the output rather than echoed back.
  final double hydration;

  final int loaves;

  double get weightPerLoaf => loaves == 0 ? totalWeight : totalWeight / loaves;

  Recipe scaled(double factor) => Recipe(
    groups: [for (final g in groups) g.scaled(factor)],
    totalWeight: totalWeight * factor,
    totalFlour: totalFlour * factor,
    totalWater: totalWater * factor,
    hydration: hydration,
    loaves: loaves,
  );
}
