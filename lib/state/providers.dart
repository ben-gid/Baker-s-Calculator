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
import '../domain/models/active_bake.dart';
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

/// Written by the dough-temperature card, read by a bake's mixing step.
class DoughTempsController extends Notifier<DoughTemps> {
  @override
  DoughTemps build() => ref.read(settingsRepositoryProvider).readDoughTemps();

  void set(DoughTemps temps) {
    state = temps;
    ref.read(settingsRepositoryProvider).writeDoughTemps(temps);
  }
}

final doughTempsProvider = NotifierProvider<DoughTempsController, DoughTemps>(
  DoughTempsController.new,
);

// ---------------------------------------------------------------------------
// The recipe being edited
// ---------------------------------------------------------------------------

/// A blank dough. Nothing is filled in for the baker: every box starts empty
/// with a typical range as its hint, and a template is one tap away for anyone
/// who wants numbers to start from.
///
/// Hydration and salt are nulled explicitly because [RecipeInput]'s own
/// constructor defaults them for JSON written before they were optional.
const startingPoint = RecipeInput(
  style: DoughStyle.classic,
  hydration: null,
  salt: null,
);

class CalculatorController extends Notifier<RecipeInput> {
  @override
  RecipeInput build() => startingPoint;

  void load(RecipeInput input) => state = input;

  void change(RecipeInput Function(RecipeInput) edit) => state = edit(state);

  /// Switching style keeps everything already typed — fields belonging to
  /// another style are simply not read, so flipping back and forth loses
  /// nothing. Whatever the new style needs and does not have stays empty.
  void setStyle(DoughStyle style) => state = state.copyWith(style: style);

  /// Flips which weight drives the recipe, independent of style. Like
  /// [setStyle], it leaves both weights exactly as typed.
  void setByFlourWeight(bool value) =>
      state = state.copyWith(byFlourWeight: value);

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
// The bake in progress
// ---------------------------------------------------------------------------

/// Set by "Start bake" and read by Home and the live plan. Starting a new bake
/// replaces the old one, the same way the reminders do.
///
/// Every change is a pure [ActiveBake] operation at the moment it happened,
/// saved, then the reminders set again quietly — the forecast after a Done is
/// a different one. A reminder's button arrives here too while the app runs.
class ActiveBakeController extends Notifier<ActiveBake?> {
  @override
  ActiveBake? build() {
    final presses = ref
        .read(notificationServiceProvider)
        .actions
        .listen((r) => _change((b, now) => b.apply(r.action, r.step, now)));
    ref.onDispose(presses.cancel);
    return ref.read(settingsRepositoryProvider).readActiveBake();
  }

  /// Recorded whatever happens to the reminders: a refused permission still
  /// leaves a bake under way, and Home can still count it down.
  Future<ScheduleOutcome> start(ActiveBake bake) async {
    state = bake;
    await ref.read(settingsRepositoryProvider).writeActiveBake(bake);
    return ref.read(notificationServiceProvider).scheduleBake(bake);
  }

  void done(int step) => _change((b, now) => b.done(step, now));
  void foldSetDone(int step) => _change((b, now) => b.foldSetDone(step, now));
  void skipTo(int step) => _change((b, now) => b.skipTo(step, now));
  void extend(int step) => _change((b, now) => b.extend(step, now));
  void tick(int step) => _change((b, now) => b.tick(step, now));
  void retime(int step, Duration duration) =>
      _change((b, _) => b.retime(step, duration));
  void goBackTo(int step, {required bool resetLater}) =>
      _change((b, now) => b.goBackTo(step, now, resetLater: resetLater));

  /// Ticking a row as weighed moves no time, so the reminders stay.
  void toggleWeighed(String key) =>
      _change((b, _) => b.toggleWeighed(key), reschedule: false);

  void _change(
    ActiveBake Function(ActiveBake bake, DateTime now) operation, {
    bool reschedule = true,
  }) {
    final bake = state;
    if (bake == null) return;
    final next = operation(bake, DateTime.now());
    state = next;
    ref.read(settingsRepositoryProvider).writeActiveBake(next);
    if (reschedule) {
      ref
          .read(notificationServiceProvider)
          .scheduleBake(next, askPermission: false);
    }
  }

  Future<void> stop() async {
    state = null;
    await ref.read(settingsRepositoryProvider).writeActiveBake(null);
    await ref.read(notificationServiceProvider).cancelBake();
  }
}

final activeBakeProvider = NotifierProvider<ActiveBakeController, ActiveBake?>(
  ActiveBakeController.new,
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
