import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/models/recipe_model.dart';
import 'package:dough_calculator/utils/constants.dart';

final pancakesRecipe = Recipe(
  id: 'easy-pancakes',
  title: 'Fluffy Pancakes',
  description: 'Simple and delicious breakfast pancakes.',
  doughType: DoughType.classic,
  doughInputs: [
    Field(label: flourLabel, valueType: valueGram, value: 250),
    Field(
      label: hydrationLabel,
      valueType: valuePercent,
      value: 120,
      name: 'Milk',
    ),
    Field(label: saltLabel, valueType: valuePercent, value: 0.5),
    Field(
      label: yeastLabel,
      valueType: valuePercent,
      value: 0,
      name: 'Baking Powder',
    ), // Note: reusing model
  ],
  flourDispersionInputs: [],
  enrichedInputs: [
    Field(
      label: fatLabel,
      valueType: valuePercent,
      value: 15,
      name: 'Melted Butter',
    ),
    Field(label: sugarLabel, valueType: valuePercent, value: 8),
    Field(label: eggLabel, valueType: valueCount, value: 1),
  ],
  mixinInputs: [],
  instructions: [
    RecipeStep(description: 'Whisk dry ingredients', timeInMinutes: 5),
    RecipeStep(description: 'Mix in wet ingredients', timeInMinutes: 5),
    RecipeStep(description: 'Rest batter', timeInMinutes: 10),
    RecipeStep(description: 'Cook on griddle', timeInMinutes: 15),
  ],
  isDefault: true,
  colorValue: 0xFFDBEAFE, // Sky Blue
);
