import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models/saved_recipe.dart';

/// Recipes shipped inside the app. Read-only — the library offers "Save a copy"
/// rather than editing in place, so a built-in can always be got back.
///
/// A malformed asset is a build-time mistake, not a user problem, so a bad
/// entry is skipped rather than taking the whole list down.
Future<List<SavedRecipe>> loadSystemRecipes() async {
  final raw = await rootBundle.loadString('assets/recipes/system_recipes.json');
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final recipes = <SavedRecipe>[];
  for (final entry in decoded['recipes'] as List) {
    try {
      recipes.add(
        SavedRecipe.fromJson(entry as Map<String, dynamic>, isSystem: true),
      );
    } on FormatException catch (e) {
      assert(false, 'Bad system recipe: $e');
    }
  }
  return recipes;
}
