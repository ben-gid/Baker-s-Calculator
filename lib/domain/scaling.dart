/// Resizing a recipe without touching its ratios.
library;

import 'calculator.dart';
import 'models/recipe_input.dart';

/// Adjusts the recipe so the finished dough weighs [targetGrams] in total,
/// across all loaves. Every baker's percentage is unchanged.
///
/// For the inverse styles the dough weight is an input, so this is a division.
/// For classic, total weight is linear in flour weight apart from the fixed egg
/// weight, so the new flour weight is read off the current result rather than
/// re-deriving the denominator — one less copy of the algebra to keep in sync.
RecipeInput scaleToTotalWeight(RecipeInput input, double targetGrams) {
  if (targetGrams <= 0) return input;
  final loaves = input.loaves < 1 ? 1 : input.loaves;

  if (!input.solvesForward) {
    return input.copyWith(totalDoughWeight: targetGrams / loaves);
  }

  final eggGrams = input.enrichmentOrEmpty.eggGrams * loaves;
  final current = calculate(input).totalWeight;
  final currentFlourPart = current - eggGrams;
  final targetFlourPart = targetGrams - eggGrams;
  if (currentFlourPart <= 0 || targetFlourPart <= 0) return input;

  return input.copyWith(
    flourWeight: input.flourWeight! * targetFlourPart / currentFlourPart,
  );
}

/// "I only have this much flour" — sizes the recipe to [flourGrams] of total
/// flour across all loaves.
RecipeInput scaleToTotalFlour(RecipeInput input, double flourGrams) {
  if (flourGrams <= 0) return input;
  final loaves = input.loaves < 1 ? 1 : input.loaves;

  if (input.solvesForward) {
    return input.copyWith(flourWeight: flourGrams / loaves);
  }

  // Per loaf, flour = (doughWeight - eggWeight) / denominator, so flour is
  // linear in dough weight once the eggs are set aside.
  final currentFlourPerLoaf = calculate(input).totalFlour / loaves;
  if (currentFlourPerLoaf <= 0) return input;
  final eggGrams = input.enrichmentOrEmpty.eggGrams;
  final currentDough = input.totalDoughWeight! - eggGrams;

  return input.copyWith(
    totalDoughWeight:
        eggGrams + currentDough * (flourGrams / loaves) / currentFlourPerLoaf,
  );
}
