import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/models/recipe_model.dart';
import 'package:dough_calculator/utils/constants.dart';

final sourdoughRecipe = Recipe(
  id: 'beginner-sourdough',
  title: 'Beginner Sourdough',
  description: 'A reliable high-hydration sourdough loaf.',
  doughType: DoughType.sourdough,
  doughInputs: [
    Field(label: doughLabel, valueType: valueGram, value: 1000),
    Field(label: hydrationLabel, valueType: valuePercent, value: 70),
    Field(label: saltLabel, valueType: valuePercent, value: 2),
    Field(label: levainLabel, valueType: valuePercent, value: 20),
    Field(label: levainHydrationLabel, valueType: valuePercent, value: 100),
  ],
  flourDispersionInputs: [],
  enrichedInputs: [],
  mixinInputs: [],
  instructions: [
    RecipeStep(
      description: 'Mix flour and water (Autolyse)',
      timeInMinutes: 60,
    ),
    RecipeStep(description: 'Add levain and salt', timeInMinutes: 30),
    RecipeStep(description: 'Bulk fermentation with folds', timeInMinutes: 240),
    RecipeStep(description: 'Shape and cold proof', timeInMinutes: 720),
  ],
  isDefault: true,
  colorValue: 0xFFD1FAE5, // Sage Green
);
