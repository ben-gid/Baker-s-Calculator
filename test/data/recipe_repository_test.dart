/// Storage behaviour, tested against the real filesystem.
///
/// These are plain `test()` cases rather than `testWidgets`, so there is no
/// fake clock in the way and file I/O behaves normally.
library;

import 'dart:convert';
import 'dart:io';

import 'package:bakers_calculator/data/recipe_repository.dart';
import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:bakers_calculator/domain/models/saved_recipe.dart';
import 'package:flutter_test/flutter_test.dart';

SavedRecipe recipe(String name) => SavedRecipe(
  id: name,
  name: name,
  input: const RecipeInput(
    style: DoughStyle.sourdough,
    totalDoughWeight: 900,
    hydration: 75,
    salt: 2,
    levainPercent: 20,
    levainHydration: 100,
  ),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late Directory dir;
  late FileRecipeRepository store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recipe_store_test');
    store = FileRecipeRepository(File('${dir.path}/recipes.json'));
  });

  tearDown(() => dir.delete(recursive: true));

  test('a missing file is an empty library, not an error', () async {
    expect(await store.load(), isEmpty);
  });

  test('an empty file is an empty library', () async {
    await store.file.writeAsString('   ');
    expect(await store.load(), isEmpty);
  });

  test('recipes survive a save and reload unchanged', () async {
    await store.save([recipe('Country'), recipe('Rye')]);
    final loaded = await store.load();

    expect(loaded.map((r) => r.name), ['Country', 'Rye']);
    expect(loaded.first.input.hydration, 75);
    expect(loaded.first.input.levainHydration, 100);
    expect(loaded.first.createdAt, DateTime.utc(2026));
  });

  test('saving replaces the previous contents rather than appending', () async {
    await store.save([recipe('First')]);
    await store.save([recipe('Second')]);
    expect((await store.load()).single.name, 'Second');
  });

  test('a save leaves no temp file behind', () async {
    await store.save([recipe('Country')]);
    expect(File('${store.file.path}.tmp').existsSync(), isFalse);
  });

  test('a corrupt file is quarantined and reported', () async {
    await store.file.writeAsString('{not json');

    await expectLater(
      store.load,
      throwsA(
        isA<RecipeStoreException>().having(
          (e) => e.message,
          'message',
          contains('could not be read'),
        ),
      ),
    );

    // The damaged data is kept, not destroyed.
    expect(File(store.backupPath).readAsStringSync(), '{not json');
    expect(store.file.existsSync(), isFalse);
  });

  test(
    'a recipe with an unreadable entry is reported, not silently dropped',
    () async {
      await store.file.writeAsString(
        jsonEncode({
          'version': 1,
          'recipes': [
            {'id': 'x', 'name': 'Broken'}, // no input
          ],
        }),
      );

      await expectLater(store.load, throwsA(isA<RecipeStoreException>()));
    },
  );

  test('an unknown dough style is rejected rather than guessed', () async {
    await store.file.writeAsString(
      jsonEncode({
        'version': 1,
        'recipes': [
          {
            'id': 'x',
            'name': 'Alien',
            'input': {'style': 'ciabatta', 'hydration': 70, 'salt': 2},
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      }),
    );

    await expectLater(store.load, throwsA(isA<RecipeStoreException>()));
  });

  test('an imported recipe cannot claim to be built in', () {
    final parsed = SavedRecipe.fromJson({
      'id': 'x',
      'name': 'Sneaky',
      'isSystem': true,
      'input': recipe('x').input.toJson(),
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    });
    expect(parsed.isSystem, isFalse);
  });
}
