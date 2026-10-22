import 'package:dough_calculator/data/recipes/challah_recipe.dart';
import 'package:dough_calculator/data/recipes/pancakes_recipe.dart';
import 'package:dough_calculator/data/recipes/pizza_recipe.dart';
import 'package:dough_calculator/data/recipes/sourdough_recipe.dart';
import 'package:dough_calculator/models/recipe_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecipeNotifier extends Notifier<List<Recipe>> {
  @override
  List<Recipe> build() {
    return [sourdoughRecipe, pizzaRecipe, challahRecipe, pancakesRecipe];
  }

  void addRecipe(Recipe recipe) {
    state = [...state, recipe];
  }

  void removeRecipe(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void updateRecipe(Recipe recipe) {
    state = state.map((r) => r.id == recipe.id ? recipe : r).toList();
  }
}

final recipeProvider = NotifierProvider<RecipeNotifier, List<Recipe>>(
  RecipeNotifier.new,
);

final baseRecipesProvider = Provider<List<Recipe>>((ref) {
  return ref.watch(recipeProvider).where((r) => r.isDefault).toList();
});

final userRecipesProvider = Provider<List<Recipe>>((ref) {
  return ref.watch(recipeProvider).where((r) => !r.isDefault).toList();
});
