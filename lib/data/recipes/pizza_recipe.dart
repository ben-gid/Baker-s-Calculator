import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/models/recipe_model.dart';
import 'package:dough_calculator/utils/constants.dart';

final pizzaRecipe = Recipe(
  id: 'pizza-dough',
  title: 'Neapolitan Pizza Dough',
  description: 'Traditional pizza dough for high-heat ovens.',
  doughType: DoughType.classic,
  doughInputs: [
    Field(label: flourLabel, valueType: valueGram, value: 1000),
    Field(label: hydrationLabel, valueType: valuePercent, value: 65),
    Field(label: saltLabel, valueType: valuePercent, value: 3),
    Field(label: yeastLabel, valueType: valuePercent, value: 0.1),
  ],
  flourDispersionInputs: [],
  enrichedInputs: [],
  mixinInputs: [],
  instructions: [
    RecipeStep(description: 'Initial mix and rest', timeInMinutes: 20),
    RecipeStep(description: 'Bulk at room temp', timeInMinutes: 480),
    RecipeStep(description: 'Cold ferment in balls', timeInMinutes: 1440),
  ],
  isDefault: true,
  colorValue: 0xFFFED7AA, // Peach/Terracotta
);
