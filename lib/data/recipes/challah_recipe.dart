import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/models/recipe_model.dart';
import 'package:dough_calculator/utils/constants.dart';

final challahRecipe = Recipe(
  id: 'classic-challah',
  title: 'Classic Challah',
  description: 'Rich, eggy, and slightly sweet braided bread.',
  doughType: DoughType.classic,
  doughInputs: [
    Field(label: flourLabel, valueType: valueGram, value: 1000),
    Field(label: hydrationLabel, valueType: valuePercent, value: 45),
    Field(label: saltLabel, valueType: valuePercent, value: 1.5),
    Field(label: yeastLabel, valueType: valuePercent, value: 1.5),
  ],
  flourDispersionInputs: [],
  enrichedInputs: [
    Field(label: fatLabel, valueType: valuePercent, value: 10),
    Field(label: sugarLabel, valueType: valuePercent, value: 12),
    Field(label: eggLabel, valueType: valueCount, value: 2),
  ],
  mixinInputs: [],
  instructions: [
    RecipeStep(description: 'Mix until smooth', timeInMinutes: 15),
    RecipeStep(description: 'First rise', timeInMinutes: 90),
    RecipeStep(description: 'Braid', timeInMinutes: 20),
    RecipeStep(description: 'Final proof', timeInMinutes: 60),
  ],
  isDefault: true,
  colorValue: 0xFFFEF08A, // Soft Gold
);
