import 'package:bakers_calculator/domain/calculator.dart';
import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/models/recipe.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:bakers_calculator/domain/step_ingredients.dart';
import 'package:bakers_calculator/domain/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

const _classic = RecipeInput(
  style: DoughStyle.classic,
  flourWeight: 500,
  hydration: 70,
  salt: 2,
  yeast: 1,
  enrichment: Enrichment(fatPercent: 5),
  mixIns: [MixIn(name: 'Olives', percent: 10)],
);

const _sourdough = RecipeInput(
  style: DoughStyle.sourdough,
  totalDoughWeight: 900,
  hydration: 75,
  salt: 2,
  levainPercent: 20,
  levainHydration: 100,
  flourBlend: [
    FlourPart(name: 'Bread flour', percent: 90),
    FlourPart(name: 'Whole wheat', percent: 10),
  ],
  mixIns: [MixIn(name: 'Seeds', percent: 8)],
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

List<List<Ingredient>> rows(
  RecipeInput input, {
  Set<StepKind> skip = const {},
}) {
  final steps = buildTimeline(input).steps;
  return stepIngredients(
    calculate(input),
    steps,
    skipped: [for (final s in steps) skip.contains(s.kind)],
  );
}

List<Ingredient> at(
  RecipeInput input,
  StepKind kind, [
  Set<StepKind> skip = const {},
]) {
  final steps = buildTimeline(input).steps;
  return rows(input, skip: skip)[steps.indexWhere((s) => s.kind == kind)];
}

Iterable<String> names(List<Ingredient> rows) => rows.map((i) => i.name);

double grams(Iterable<Ingredient> rows) =>
    rows.fold(0.0, (sum, i) => sum + i.grams);

void main() {
  group('every gram of dough goes in exactly once', () {
    for (final input in [_classic, _sourdough, _preferment]) {
      test(input.style.name, () {
        final recipe = calculate(input);
        // The levain feed is built on its own and goes in as one lump at the
        // mix, so the dough's weight is everything except the feed rows.
        final steps = buildTimeline(input).steps;
        final all = rows(input);
        final weighedIn = [
          for (var i = 0; i < steps.length; i++)
            if (steps[i].kind != StepKind.levain &&
                steps[i].kind != StepKind.preferment)
              ...all[i],
        ];
        expect(grams(weighedIn), closeTo(recipe.totalWeight, 1e-6));
      });
    }
  });

  test('the autolyse is flour and water; the mix brings the rest', () {
    expect(names(at(_sourdough, StepKind.autolyse)), [
      'Bread flour',
      'Whole wheat',
      'Water',
    ]);
    expect(names(at(_sourdough, StepKind.mix)), ['Levain', 'Salt']);
    expect(names(at(_classic, StepKind.autolyse)), ['Flour', 'Water']);
    expect(names(at(_classic, StepKind.mix)), [
      'Yeast',
      'Salt',
      'Fat',
      'Olives',
    ]);
  });

  test('a sourdough takes its mix-ins with the first fold', () {
    expect(names(at(_sourdough, StepKind.fold)), ['Seeds']);
  });

  test('the levain lump at the mix weighs what the levain group does', () {
    final levain = at(
      _sourdough,
      StepKind.mix,
    ).firstWhere((i) => i.role == IngredientRole.leaven);
    expect(levain.grams, closeTo(calculate(_sourdough).leaven!.grams, 1e-9));
  });

  test('a skipped autolyse hands its flour and water to the mix', () {
    final mix = at(_classic, StepKind.mix, {StepKind.autolyse});
    expect(names(mix), ['Flour', 'Water', 'Yeast', 'Salt', 'Fat', 'Olives']);
    expect(at(_classic, StepKind.autolyse, {StepKind.autolyse}), isEmpty);
  });

  test('skipping the mix too carries everything on to the next step', () {
    final bulk = at(_classic, StepKind.bulk, {StepKind.autolyse, StepKind.mix});
    expect(grams(bulk), closeTo(calculate(_classic).totalWeight, 1e-6));
  });

  test('a skipped levain feed is dropped: the mix lists the levain whole', () {
    final skip = {StepKind.levain};
    expect(at(_sourdough, StepKind.levain, skip), isEmpty);
    expect(names(at(_sourdough, StepKind.autolyse, skip)), [
      'Bread flour',
      'Whole wheat',
      'Water',
    ]);
    expect(names(at(_sourdough, StepKind.mix, skip)), contains('Levain'));
  });

  test('the preferment build lists its own flour, water and yeast', () {
    expect(names(at(_preferment, StepKind.preferment)), [
      'Flour',
      'Water',
      'Yeast',
    ]);
  });

  group('levainFeed', () {
    // 900 g at 75%: 500 g of dough flour carrying a 100 g levain.
    test('feeds 1:2:2 with a little extra to keep back', () {
      final levain = calculate(_sourdough).leaven!.grams;
      final feed = levainFeed(calculate(_sourdough), FeedRatio.r122)!;
      final build = levain * (1 + feedExtra);
      expect(feed.starter + feed.flour + feed.water, closeTo(build, 1e-9));
      expect(feed.flour, closeTo(feed.starter * 2, 1e-9));
      expect(feed.water, closeTo(feed.starter * 2, 1e-9));
      expect(feed.keepBack, closeTo(levain * feedExtra, 1e-9));
    });

    test(
      '100 g of levain at 1:2:2 is 22 g starter, 44 g flour, 44 g water',
      () {
        const recipe = Recipe(
          groups: [
            IngredientGroup(
              name: 'Levain',
              ingredients: [
                Ingredient(
                  name: 'Flour',
                  grams: 50,
                  role: IngredientRole.flour,
                ),
                Ingredient(
                  name: 'Water',
                  grams: 50,
                  role: IngredientRole.water,
                ),
              ],
            ),
            IngredientGroup(name: 'Dough', ingredients: []),
          ],
          totalWeight: 100,
          totalFlour: 50,
          totalWater: 50,
          hydration: 100,
          loaves: 1,
          doughFlour: 0,
        );
        final feed = levainFeed(recipe, FeedRatio.r122)!;
        expect(feed.starter, closeTo(22, 1e-9));
        expect(feed.flour, closeTo(44, 1e-9));
        expect(feed.water, closeTo(44, 1e-9));
        expect(feed.keepBack, closeTo(10, 1e-9));
      },
    );

    test('a stiff levain comes out at its own hydration', () {
      final stiff = calculate(_sourdough.copyWith(levainHydration: 60));
      for (final ratio in FeedRatio.values) {
        final feed = levainFeed(stiff, ratio)!;
        final flour = feed.starter / 2 + feed.flour;
        final water = feed.starter / 2 + feed.water;
        expect(water / flour * 100, closeTo(60, 1e-9), reason: ratio.label);
      }
    });

    test('there is nothing to feed without a levain', () {
      expect(levainFeed(calculate(_classic), FeedRatio.r122), isNull);
      expect(levainFeed(calculate(_preferment), FeedRatio.r122), isNull);
    });
  });
}
