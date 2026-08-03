/// Library behaviour without a widget tree: ordering, races, and the rules
/// about built-in recipes.
library;

import 'package:bakers_calculator/data/recipe_repository.dart';
import 'package:bakers_calculator/data/settings_repository.dart';
import 'package:bakers_calculator/domain/models/saved_recipe.dart';
import 'package:bakers_calculator/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStore implements RecipeRepository {
  FakeStore({this.seed = const []});

  List<SavedRecipe> recipes = [];
  final List<SavedRecipe> seed;
  int saveCount = 0;

  @override
  Future<List<SavedRecipe>> load() async {
    recipes = List.of(seed);
    return List.of(recipes);
  }

  @override
  Future<void> save(List<SavedRecipe> next) async {
    saveCount++;
    recipes = List.of(next);
  }
}

SavedRecipe existing(String name) => SavedRecipe(
  id: name,
  name: name,
  input: startingPoint,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStore store;
  late ProviderContainer container;

  Future<void> setUpContainer({List<SavedRecipe> seed = const []}) async {
    store = FakeStore(seed: seed);
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(store),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(await SharedPreferences.getInstance()),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  LibraryController controller() => container.read(libraryProvider.notifier);

  test('loads saved and built-in recipes', () async {
    await setUpContainer(seed: [existing('Last week')]);

    final state = await container.read(libraryProvider.future);

    expect(state.saved.map((r) => r.name), ['Last week']);
    expect(state.system, isNotEmpty);
    expect(state.system.every((r) => r.isSystem), isTrue);
  });

  test('saving before the first load completes keeps both recipes', () async {
    await setUpContainer(seed: [existing('Last week')]);

    // No await on the load: this is the calculator saving on a fresh start,
    // before anyone has opened the Recipes tab.
    await controller().add(name: 'Saturday loaf', input: startingPoint);

    expect(store.recipes.map((r) => r.name), containsAll(
      ['Last week', 'Saturday loaf'],
    ));
    expect(store.recipes, hasLength(2));
  });

  test('two quick saves both survive', () async {
    await setUpContainer();

    await Future.wait([
      controller().add(name: 'One', input: startingPoint),
      controller().add(name: 'Two', input: startingPoint),
    ]);

    expect(store.recipes.map((r) => r.name), containsAll(['One', 'Two']));
    expect(store.recipes, hasLength(2));
  });

  test('recipes are listed newest first', () async {
    await setUpContainer();

    await controller().add(name: 'First', input: startingPoint);
    await controller().add(name: 'Second', input: startingPoint);

    final state = container.read(libraryProvider).value!;
    expect(state.saved.map((r) => r.name), ['Second', 'First']);
  });

  test('deleting removes it from the store', () async {
    await setUpContainer();
    final recipe = await controller().add(name: 'Gone', input: startingPoint);

    await controller().delete(recipe.id);

    expect(store.recipes, isEmpty);
    expect(container.read(libraryProvider).value!.saved, isEmpty);
  });

  test('built-in recipes cannot be favourited or edited in place', () async {
    await setUpContainer();
    final state = await container.read(libraryProvider.future);
    final builtIn = state.system.first;

    await controller().toggleFavourite(builtIn.id);

    expect(store.saveCount, 0);
    expect(controller().byId(builtIn.id)!.isFavorite, isFalse);
  });

  test('duplicating a built-in produces an editable copy', () async {
    await setUpContainer();
    final state = await container.read(libraryProvider.future);
    final builtIn = state.system.first;

    final copy = await controller().duplicate(builtIn, name: builtIn.name);

    expect(copy.isSystem, isFalse);
    expect(copy.id, isNot(builtIn.id));
    expect(copy.input.hydration, builtIn.input.hydration);
    expect(store.recipes.single.name, builtIn.name);
  });

  test('search matches name, style and tags', () async {
    await setUpContainer();
    await container.read(libraryProvider.future);

    controller().search('rye');
    final byTag = container.read(libraryProvider).value!;
    expect(byTag.visibleSystem.map((r) => r.name), contains('Light Rye Sourdough'));

    controller().search('preferment');
    final byStyle = container.read(libraryProvider).value!;
    expect(byStyle.visibleSystem.map((r) => r.name), contains('Ciabatta (Biga)'));

    controller().search('zzzz');
    expect(container.read(libraryProvider).value!.visibleSystem, isEmpty);
  });

  test('the favourites filter hides built-ins and unfavourited recipes',
      () async {
    await setUpContainer();
    final recipe = await controller().add(name: 'Keeper', input: startingPoint);
    await controller().toggleFavourite(recipe.id);
    await controller().add(name: 'Ordinary', input: startingPoint);

    controller().toggleFavouritesFilter();
    final state = container.read(libraryProvider).value!;

    expect(state.visibleSaved.map((r) => r.name), ['Keeper']);
    expect(state.visibleSystem, isEmpty);
  });
}
