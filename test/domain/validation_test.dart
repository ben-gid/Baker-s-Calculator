import 'package:bakers_calculator/domain/calculator.dart';
import 'package:bakers_calculator/domain/dough_temp.dart';
import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:bakers_calculator/domain/scaling.dart';
import 'package:bakers_calculator/domain/validation.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('validation', () {
    test('a complete recipe has no issues', () {
      expect(validate(_classic), isEmpty);
      expect(validate(_sourdough), isEmpty);
    });

    test('missing style-specific fields are errors, not crashes', () {
      final issues = validate(const RecipeInput(style: DoughStyle.sourdough));
      expect(issues.hasErrors, isTrue);
      expect(
        issues.map((i) => i.field),
        containsAll([
          RecipeField.totalDoughWeight,
          RecipeField.levainPercent,
          RecipeField.levainHydration,
        ]),
      );
    });

    test('fields belonging to another style are not demanded', () {
      // Classic needs yeast; sourdough must not ask for it.
      expect(validate(_sourdough).forField(RecipeField.yeast), isEmpty);
      expect(validate(_classic).forField(RecipeField.levainPercent), isEmpty);
    });

    test('a blend that does not reach 100% is an error naming the total', () {
      final issues = validate(
        _classic.copyWith(
          flourBlend: const [
            FlourPart(name: 'Bread', percent: 70),
            FlourPart(name: 'Rye', percent: 20),
          ],
        ),
      );
      final issue = issues.firstFor(RecipeField.flourBlend)!;
      expect(issue.severity, IssueSeverity.error);
      expect(issue.message, contains('90%'));
    });

    test('a blend summing to 100 passes', () {
      expect(
        validate(
          _classic.copyWith(
            flourBlend: const [
              FlourPart(name: 'Bread', percent: 80),
              FlourPart(name: 'Rye', percent: 20),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('unusual but workable values warn instead of blocking', () {
      final issues = validate(_classic.copyWith(hydration: 98));
      expect(issues.hasErrors, isFalse);
      expect(issues.firstFor(RecipeField.hydration)!.severity,
          IssueSeverity.warning);
    });

    test('errors outrank warnings for the same field', () {
      final issues = validate(_classic.copyWith(hydration: 500));
      expect(issues.firstFor(RecipeField.hydration)!.severity,
          IssueSeverity.error);
    });

    test('eggs heavier than the dough are caught before the math runs', () {
      final input = _sourdough.copyWith(
        totalDoughWeight: 80,
        enrichment: const Enrichment(eggCount: 3),
      );
      expect(validate(input).hasErrors, isTrue);
      // Without the guard this would produce a negative flour weight.
      expect(calculate(input).totalFlour, lessThan(0));
    });
  });

  group('scaling', () {
    test('classic hits the requested total weight', () {
      final scaled = scaleToTotalWeight(_classic, 1200);
      expect(calculate(scaled).totalWeight, closeTo(1200, 1e-6));
    });

    test('classic hits the target even with eggs in the mix', () {
      final enriched = _classic.copyWith(
        enrichment: const Enrichment(fatPercent: 8, eggCount: 2),
      );
      final scaled = scaleToTotalWeight(enriched, 1500);
      expect(calculate(scaled).totalWeight, closeTo(1500, 1e-6));
    });

    test('inverse styles divide the target across loaves', () {
      final scaled = scaleToTotalWeight(_sourdough.copyWith(loaves: 3), 2700);
      expect(scaled.totalDoughWeight, closeTo(900, 1e-9));
      expect(calculate(scaled).totalWeight, closeTo(2700, 1e-6));
    });

    test('scaling preserves every ratio', () {
      final original = calculate(_sourdough);
      final scaled = calculate(scaleToTotalWeight(_sourdough, 1800));
      expect(scaled.hydration, closeTo(original.hydration, 1e-9));
      expect(
        scaled.totalFlour / scaled.totalWeight,
        closeTo(original.totalFlour / original.totalWeight, 1e-9),
      );
    });

    test('scaling to available flour works both directions', () {
      expect(
        calculate(scaleToTotalFlour(_classic, 350)).totalFlour,
        closeTo(350, 1e-6),
      );
      expect(
        calculate(scaleToTotalFlour(_sourdough, 350)).totalFlour,
        closeTo(350, 1e-6),
      );
    });

    test('scaling to available flour respects loaf count', () {
      final scaled = scaleToTotalFlour(_sourdough.copyWith(loaves: 2), 1000);
      expect(calculate(scaled).totalFlour, closeTo(1000, 1e-6));
    });

    test('nonsense targets are ignored rather than producing nonsense', () {
      expect(scaleToTotalWeight(_classic, 0).flourWeight, 500);
      expect(scaleToTotalFlour(_classic, -5).flourWeight, 500);
    });
  });

  group('dough temperature', () {
    test('straight dough uses three factors', () {
      // DDT 25 x 3 = 75; 75 - (21 room + 20 flour + 2 friction) = 32
      final result = waterTemperature(
        const DoughTempInputs(
          desiredDoughTemp: 25,
          roomTemp: 21,
          flourTemp: 20,
          frictionFactor: 2,
        ),
      );
      expect(result.waterTemp, closeTo(32, 1e-9));
      expect(result.warning, isNull);
    });

    test('a preferment adds a fourth factor', () {
      // DDT 25 x 4 = 100; 100 - (21 + 20 + 23 + 2) = 34
      final result = waterTemperature(
        const DoughTempInputs(
          desiredDoughTemp: 25,
          roomTemp: 21,
          flourTemp: 20,
          prefermentTemp: 23,
          frictionFactor: 2,
        ),
      );
      expect(result.waterTemp, closeTo(34, 1e-9));
    });

    test('unreachable water temperatures come back with advice', () {
      final tooCold = waterTemperature(
        const DoughTempInputs(
          desiredDoughTemp: 22,
          roomTemp: 32,
          flourTemp: 32,
          frictionFactor: 8,
        ),
      );
      expect(tooCold.waterTemp, lessThan(0));
      expect(tooCold.warning, contains('ice'));

      final tooHot = waterTemperature(
        const DoughTempInputs(
          desiredDoughTemp: 30,
          roomTemp: 5,
          flourTemp: 5,
          frictionFactor: 0,
        ),
      );
      expect(tooHot.warning, contains('kill the yeast'));
    });
  });
}
