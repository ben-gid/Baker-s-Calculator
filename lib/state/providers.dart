/// Riverpod wiring. Controllers hold immutable state and delegate every
/// calculation to `domain/` — there is no math in this layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatting.dart';
import '../data/notification_service.dart';
import '../data/recipe_repository.dart';
import '../data/settings_repository.dart';
import '../data/system_recipes.dart';
import '../domain/calculator.dart';
import '../domain/models/dough_style.dart';
import '../domain/models/recipe.dart';
import '../domain/models/recipe_input.dart';
import '../domain/models/saved_recipe.dart';
import '../domain/validation.dart';

/// Overridden in `main()` once the platform stores are open, so no widget ever
/// has to wait on an async settings read.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// Bake reminders. Overridden in tests so nothing touches the platform.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// Built-in recipes, read from the asset bundle.
///
/// A provider rather than a direct call so widget tests can supply a fixture —
/// `rootBundle` does real I/O, which never completes on `flutter_test`'s fake
/// clock. The real asset is exercised in `test/state/library_controller_test`.
final systemRecipesProvider = FutureProvider<List<SavedRecipe>>(
  (ref) => loadSystemRecipes(),
);

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.read(settingsRepositoryProvider).read();

  void _update(Settings next) {
    state = next;
    // Fire and forget: a failed preference write is not worth interrupting the
    // baker over, and the value is already applied in memory.
    ref.read(settingsRepositoryProvider).write(next);
  }

  void setUnit(MassUnit unit) => _update(state.copyWith(unit: unit));
  void setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));
  void toggleBakersPercent() =>
      _update(state.copyWith(showBakersPercent: !state.showBakersPercent));
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

// ---------------------------------------------------------------------------
// The recipe being edited
// ---------------------------------------------------------------------------

/// A real loaf, not a wall of empty fields. Whichever style the baker picks
/// first already shows workable numbers.
const startingPoint = RecipeInput(
  style: DoughStyle.sourdough,
  totalDoughWeight: 900,
  hydration: 75,
  salt: 2,
  levainPercent: 20,
  levainHydration: 100,
);

class CalculatorController extends Notifier<RecipeInput> {
  @override
  RecipeInput build() => startingPoint;

  void load(RecipeInput input) => state = input;

  void change(RecipeInput Function(RecipeInput) edit) => state = edit(state);

  /// Switching style keeps everything already typed — fields belonging to
  /// another style are simply not read — and fills in defaults for whatever the
  /// new style needs but does not yet have.
  void setStyle(DoughStyle style) {
    state = switch (style) {
      DoughStyle.classic => state.copyWith(
        style: style,
        flourWeight: state.flourWeight ?? 500,
        yeast: state.yeast ?? 1,
      ),
      DoughStyle.sourdough => state.copyWith(
        style: style,
        totalDoughWeight: state.totalDoughWeight ?? 900,
        levainPercent: state.levainPercent ?? 20,
        levainHydration: state.levainHydration ?? 100,
      ),
      DoughStyle.preferment => state.copyWith(
        style: style,
        totalDoughWeight: state.totalDoughWeight ?? 900,
        prefermentPercent: state.prefermentPercent ?? 30,
        prefermentHydration: state.prefermentHydration ?? 100,
        prefermentYeast: state.prefermentYeast ?? 0.2,
      ),
    };
  }

  /// Flips which weight drives the recipe, independent of style. Mirrors
  /// [setStyle]: fills in a default for the field the new mode needs if the
  /// baker has never typed one, and leaves the other field exactly as typed
  /// so flipping back and forth loses nothing.
  void setByFlourWeight(bool value) => state = value
      ? state.copyWith(
          byFlourWeight: value,
          flourWeight: state.flourWeight ?? 500,
        )
      : state.copyWith(
          byFlourWeight: value,
          totalDoughWeight: state.totalDoughWeight ?? 900,
        );

  void reset() => state = startingPoint;
}

final calculatorProvider = NotifierProvider<CalculatorController, RecipeInput>(
  CalculatorController.new,
);

/// The live result. Null while the input has errors, so the UI shows the
/// problem instead of a nonsense recipe.
final calculationProvider = Provider<Recipe?>((ref) {
  final input = ref.watch(calculatorProvider);
  if (validate(input).hasErrors) return null;
  return calculate(input);
});

final issuesProvider = Provider<List<InputIssue>>(
  (ref) => validate(ref.watch(calculatorProvider)),
);

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

class LibraryState {
  const LibraryState({
    this.saved = const [],
    this.system = const [],
    this.query = '',
    this.favouritesOnly = false,
    this.error,
  });

  final List<SavedRecipe> saved;
  final List<SavedRecipe> system;
  final String query;
  final bool favouritesOnly;

  /// Surfaced once as a banner; a failed load must not look like data loss.
  final String? error;

  List<SavedRecipe> get visibleSaved => saved
      .where((r) => r.matches(query))
      .where((r) => !favouritesOnly || r.isFavorite)
      .toList();

  List<SavedRecipe> get visibleSystem => favouritesOnly
      ? const []
      : system.where((r) => r.matches(query)).toList();

  LibraryState copyWith({
    List<SavedRecipe>? saved,
    List<SavedRecipe>? system,
    String? query,
    bool? favouritesOnly,
    String? error,
    bool clearError = false,
  }) => LibraryState(
    saved: saved ?? this.saved,
    system: system ?? this.system,
    query: query ?? this.query,
    favouritesOnly: favouritesOnly ?? this.favouritesOnly,
    error: clearError ? null : (error ?? this.error),
  );
}

class LibraryController extends AsyncNotifier<LibraryState> {
  @override
  Future<LibraryState> build() async {
    final system = await ref.watch(systemRecipesProvider.future);
    try {
      final saved = await ref.read(recipeRepositoryProvider).load();
      return LibraryState(saved: _sorted(saved), system: system);
    } on RecipeStoreException catch (e) {
      return LibraryState(system: system, error: e.message);
    }
  }

  static List<SavedRecipe> _sorted(List<SavedRecipe> recipes) =>
      recipes..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  LibraryState get _state => state.value ?? const LibraryState();

  /// Waits for the first load before mutating.
  ///
  /// Saving from the calculator can easily beat the file read — the baker may
  /// never have opened the Recipes tab. Without this, the write would be based
  /// on an empty list and the load landing afterwards would wipe it.
  Future<LibraryState> _ready() async {
    if (state.hasValue) return state.value!;
    return future;
  }

  Future<void> _pending = Future.value();

  /// Runs mutations one at a time.
  ///
  /// Each one reads the current list, changes it, and writes the whole thing
  /// back. Two overlapping mutations would both read the same starting list and
  /// the second would silently discard the first — a fast double tap on Save is
  /// enough to lose a recipe.
  Future<T> _serialised<T>(Future<T> Function() mutate) {
    final result = _pending.then((_) => mutate());
    // Swallow failures here only so one failed write does not block the next;
    // the error still reaches the caller through `result`.
    _pending = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _persist(List<SavedRecipe> saved) async {
    final current = await _ready();
    state = AsyncData(
      current.copyWith(saved: _sorted(saved), clearError: true),
    );
    try {
      await ref.read(recipeRepositoryProvider).save(saved);
    } on RecipeStoreException catch (e) {
      state = AsyncData(_state.copyWith(error: e.message));
    }
  }

  void search(String query) => state = AsyncData(_state.copyWith(query: query));

  void toggleFavouritesFilter() => state = AsyncData(
    _state.copyWith(favouritesOnly: !_state.favouritesOnly),
  );

  void dismissError() => state = AsyncData(_state.copyWith(clearError: true));

  SavedRecipe? byId(String id) {
    for (final recipe in [..._state.saved, ..._state.system]) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  Future<SavedRecipe> add({
    required String name,
    required RecipeInput input,
    List<String> tags = const [],
    String? notes,
  }) => _serialised(() async {
    final existing = (await _ready()).saved;
    final now = DateTime.now();
    final recipe = SavedRecipe(
      id: _newId(),
      name: name.trim().isEmpty ? 'Untitled recipe' : name.trim(),
      input: input,
      tags: tags,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await _persist([...existing, recipe]);
    return recipe;
  });

  Future<void> delete(String id) => _serialised(() async {
    await _persist([
      for (final recipe in (await _ready()).saved)
        if (recipe.id != id) recipe,
    ]);
  });

  Future<void> toggleFavourite(String id) => _serialised(() async {
    final saved = (await _ready()).saved;
    // Built-in recipes are never in `saved`, so a system id matches nothing —
    // the read-only rule is structural, and nothing is written.
    if (!saved.any((r) => r.id == id)) return;
    await _persist([
      for (final recipe in saved)
        if (recipe.id == id)
          recipe.copyWith(
            isFavorite: !recipe.isFavorite,
            updatedAt: DateTime.now(),
          )
        else
          recipe,
    ]);
  });

  /// Used for both "duplicate" and "save a copy of a built-in".
  Future<SavedRecipe> duplicate(SavedRecipe source, {String? name}) => add(
    name: name ?? '${source.name} copy',
    input: source.input,
    tags: source.tags,
    notes: source.notes,
  );
}

final libraryProvider = AsyncNotifierProvider<LibraryController, LibraryState>(
  LibraryController.new,
);

int _idCounter = 0;

/// Unique within this install, which is all an offline library needs. The
/// counter breaks ties when two recipes are created in the same microsecond.
String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_idCounter++}';
