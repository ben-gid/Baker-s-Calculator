import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/repositories/data_to_calculate.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/utils/quick_calculate_recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateYeastDough', () {
    setUp(() {
      CalculateData.clearAll();
    });

    test('calculates by flour weight (default)', () {
      // Setup
      CalculateData.doughInput.add(
        Field(label: flourLabel, value: 500, valueType: valueGram),
      );
      CalculateData.doughInput.add(
        Field(label: hydrationLabel, value: 70, valueType: valuePercent),
      );
      CalculateData.doughInput.add(
        Field(label: yeastLabel, value: 1, valueType: valuePercent),
      );
      CalculateData.doughInput.add(
        Field(label: saltLabel, value: 2, valueType: valuePercent),
      );

      // Execute
      final result = calculateYeastDough(isDoughWeightMode: false);
      final doughGroup = result.firstWhere((g) => g.name == doughName);
      final totalGroup = result.firstWhere((g) => g.name == "Total");

      // Verify
      expect(doughGroup.values["Flour"], 500);
      expect(doughGroup.values["Water"], 350); // 500 * 0.7
      expect(
        totalGroup.values["Total Dough Weight"],
        500 + 350 + 5 + 10,
      ); // 500 + 350 + (500*0.01) + (500*0.02) = 865
    });

    test('calculates by total dough weight', () {
      // Setup
      // Total Dough Target: 1000g
      // Hydration: 70%, Yeast: 1%, Salt: 2%
      // Total % = 100 + 70 + 1 + 2 = 173%
      // Expected Flour = 1000 / 1.73 = 578.03...

      CalculateData.doughInput.add(
        Field(label: doughLabel, value: 1000, valueType: valueGram),
      ); // Label is misleading in input logic but value matters
      // Wait, getField searches by label. In my code I use doughLabel ("Total Dough Weight (grams)") for lookup in mode=true.
      // So I must add a field with that label.

      CalculateData.doughInput.add(
        Field(label: hydrationLabel, value: 70, valueType: valuePercent),
      );
      CalculateData.doughInput.add(
        Field(label: yeastLabel, value: 1, valueType: valuePercent),
      );
      CalculateData.doughInput.add(
        Field(label: saltLabel, value: 2, valueType: valuePercent),
      );

      // Execute
      final result = calculateYeastDough(isDoughWeightMode: true);
      final doughGroup = result.firstWhere((g) => g.name == doughName);
      final totalGroup = result.firstWhere((g) => g.name == "Total");

      // Verify
      final flour = doughGroup.values["Flour"]!;
      final water = doughGroup.values["Water"]!;
      final total = totalGroup.values["Total Dough Weight"]!;

      expect(flour, closeTo(578.03, 0.1));
      expect(water, closeTo(404.62, 0.1));
      expect(total, closeTo(1000, 0.1));
    });
  });
}
