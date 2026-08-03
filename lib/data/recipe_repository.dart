/// Saved recipes live in one JSON document in the app's documents directory.
///
/// A home baker's library is tens of recipes, not tens of thousands, so it is
/// held in memory and searched there. Writes go to a temp file and are renamed
/// over the original, so a crash mid-write can never leave a half-written
/// library — the old file is either fully replaced or untouched.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models/saved_recipe.dart';

class RecipeStoreException implements Exception {
  RecipeStoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The storage seam. Widget tests swap in an in-memory implementation so they
/// do not have to drive real file I/O through `flutter_test`'s fake clock.
abstract class RecipeRepository {
  /// Reads the library. A missing store is an empty library, not an error.
  Future<List<SavedRecipe>> load();

  Future<void> save(List<SavedRecipe> recipes);

  static Future<RecipeRepository> open() async {
    final directory = await getApplicationDocumentsDirectory();
    return FileRecipeRepository(File('${directory.path}/recipes.json'));
  }
}

class FileRecipeRepository implements RecipeRepository {
  FileRecipeRepository(this.file);

  final File file;

  static const _formatVersion = 1;

  /// A *corrupt* file is an error the caller must surface — silently returning
  /// an empty list would look like "all my recipes vanished", and the next save
  /// would overwrite the damaged file that still holds the data.
  @override
  Future<List<SavedRecipe>> load() async {
    if (!await file.exists()) return [];
    late final String contents;
    try {
      contents = await file.readAsString();
    } on IOException catch (e) {
      throw RecipeStoreException('Could not read your recipes: $e');
    }
    if (contents.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(contents) as Map<String, dynamic>;
      return [
        for (final recipe in decoded['recipes'] as List)
          SavedRecipe.fromJson(recipe as Map<String, dynamic>),
      ];
    } on Object catch (e) {
      // Keep the damaged file so the data can be recovered by hand.
      await _quarantine();
      throw RecipeStoreException(
        'Your recipe file could not be read and has been set aside as '
        '${backupPath.split(Platform.pathSeparator).last}. '
        'Starting with an empty library. ($e)',
      );
    }
  }

  @override
  Future<void> save(List<SavedRecipe> recipes) async {
    final payload = const JsonEncoder.withIndent('  ').convert({
      'version': _formatVersion,
      'recipes': [for (final recipe in recipes) recipe.toJson()],
    });

    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(payload, flush: true);
      await temp.rename(file.path); // atomic on the same filesystem
    } on IOException catch (e) {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } on IOException {
          // Best effort; the next save overwrites it anyway.
        }
      }
      throw RecipeStoreException('Could not save your recipes: $e');
    }
  }

  String get backupPath => '${file.path}.corrupt';

  Future<void> _quarantine() async {
    try {
      await file.rename(backupPath);
    } on IOException catch (e) {
      debugPrint('Could not quarantine the recipe file: $e');
    }
  }
}
