import 'package:bakers_calculator/domain/calculator.dart';
import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/timeline.dart';
import 'package:bakers_calculator/domain/validation.dart';
import 'package:bakers_calculator/domain/wizard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every combination the wizard can produce is a valid recipe', () {
    var checked = 0;
    for (final character in BreadCharacter.values) {
      for (final style in DoughStyle.values) {
        for (final flour in FlourChoice.values) {
          for (final addIns in [
            <AddIn>{},
            {AddIn.seeds},
            {AddIn.walnuts, AddIn.raisins, AddIn.herbs},
          ]) {
            final input = composeRecipe(
              WizardChoices(
                character: character,
                style: style,
                flour: flour,
                addIns: addIns,
              ),
            );

            // Warnings are fine (a 78% hearth loaf IS slack); errors are not.
            expect(
              validate(input).hasErrors,
              isFalse,
              reason: '${character.name}/${style.name}/${flour.name}',
            );

            // And it actually produces sane weights, not just valid inputs.
            final recipe = calculate(input);
            expect(recipe.totalFlour, greaterThan(0));
            expect(recipe.totalWeight, greaterThan(recipe.totalFlour));
            for (final group in recipe.groups) {
              for (final ingredient in group.ingredients) {
                expect(
                  ingredient.grams,
                  greaterThanOrEqualTo(0),
                  reason: '${character.name} -> ${ingredient.name}',
                );
              }
            }

            // Every generated recipe can also be planned.
            expect(buildTimeline(input).steps, isNotEmpty);
            checked++;
          }
        }
      }
    }
    expect(checked, 5 * 3 * 4 * 3);
  });

  test('enriched doughs are not flagged as too stiff', () {
    // Their eggs and butter are liquid that the hydration figure ignores.
    final brioche = composeRecipe(
      const WizardChoices(character: BreadCharacter.enriched),
    );
    expect(brioche.hydration, lessThan(50));
    expect(validate(brioche), isEmpty);
  });

  test('flour blends always add up to 100%', () {
    for (final flour in FlourChoice.values) {
      if (flour.blend.isEmpty) continue;
      final total = flour.blend.fold(0.0, (sum, part) => sum + part.percent);
      expect(total, 100, reason: flour.name);
    }
  });

  test('character drives hydration and enrichment', () {
    final hearth = composeRecipe(
      const WizardChoices(character: BreadCharacter.hearth),
    );
    final rich = composeRecipe(
      const WizardChoices(character: BreadCharacter.enriched),
    );

    expect(hearth.hydration, greaterThan(rich.hydration));
    expect(hearth.enrichment, isNull);
    expect(rich.enrichment!.fatPercent, greaterThan(0));
    expect(rich.enrichment!.eggCount, greaterThan(0));
  });

  test('method drives the leavening fields and nothing else', () {
    const choices = WizardChoices(character: BreadCharacter.everyday);

    final classic = composeRecipe(choices.copyWith(style: DoughStyle.classic));
    final sourdough = composeRecipe(
      choices.copyWith(style: DoughStyle.sourdough),
    );
    final preferment = composeRecipe(
      choices.copyWith(style: DoughStyle.preferment),
    );

    expect(classic.yeast, isNotNull);
    expect(classic.flourWeight, isNotNull);
    expect(sourdough.levainPercent, isNotNull);
    expect(preferment.prefermentYeast, isNotNull);

    // The character-driven parts are identical across methods.
    expect(sourdough.hydration, classic.hydration);
    expect(preferment.salt, classic.salt);
  });

  test('add-ins become mix-ins with sensible percentages', () {
    final input = composeRecipe(
      const WizardChoices(addIns: {AddIn.walnuts, AddIn.seeds}),
    );

    expect(input.mixIns.map((m) => m.name), containsAll(['Walnuts', 'Mixed seeds']));
    expect(input.mixIns.every((m) => m.percent > 0 && m.percent <= 30), isTrue);
  });

  test('the suggested name reads like something a person would write', () {
    expect(
      const WizardChoices(
        character: BreadCharacter.hearth,
        style: DoughStyle.sourdough,
      ).suggestedName,
      'Sourdough crusty hearth loaf',
    );

    expect(
      const WizardChoices(
        character: BreadCharacter.everyday,
        style: DoughStyle.sourdough,
        addIns: {AddIn.walnuts, AddIn.raisins},
      ).suggestedName,
      'Sourdough everyday loaf with raisins and walnuts',
    );

    expect(
      const WizardChoices(
        character: BreadCharacter.sandwich,
        style: DoughStyle.classic,
        addIns: {AddIn.seeds, AddIn.herbs, AddIn.cheese},
      ).suggestedName,
      'Soft sandwich loaf with cheese, herbs and mixed seeds',
    );
  });

  test('loaf count carries through to the recipe', () {
    final input = composeRecipe(const WizardChoices(loaves: 3));
    expect(input.loaves, 3);
    expect(
      calculate(input).totalWeight,
      closeTo(calculate(composeRecipe(const WizardChoices())).totalWeight * 3, 1e-6),
    );
  });
}
