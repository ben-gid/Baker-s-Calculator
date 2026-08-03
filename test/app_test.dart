/// End-to-end checks through the real widget tree: the app boots, the
/// calculator recalculates as you type, bad input blocks the result instead of
/// showing nonsense, and saving reaches the store.
///
/// Storage is in memory here. `flutter_test` runs the test body on a fake
/// clock, so real file I/O would need a `runAsync` dance around every pump —
/// the file store's own behaviour is covered directly in
/// `test/data/recipe_repository_test.dart`, where the clock is real.
library;

import 'package:bakers_calculator/app.dart';
import 'package:bakers_calculator/data/notification_service.dart';
import 'package:bakers_calculator/data/recipe_repository.dart';
import 'package:bakers_calculator/data/settings_repository.dart';
import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:bakers_calculator/domain/models/saved_recipe.dart';
import 'package:bakers_calculator/domain/timeline.dart';
import 'package:bakers_calculator/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemoryRecipeRepository implements RecipeRepository {
  InMemoryRecipeRepository({this.loadError});

  List<SavedRecipe> recipes = [];

  /// Set to simulate an unreadable store.
  final String? loadError;

  int saveCount = 0;

  @override
  Future<List<SavedRecipe>> load() async {
    if (loadError != null) throw RecipeStoreException(loadError!);
    return List.of(recipes);
  }

  @override
  Future<void> save(List<SavedRecipe> next) async {
    saveCount++;
    recipes = List.of(next);
  }
}

class FakeNotifications implements NotificationService {
  ScheduleOutcome outcome = ScheduleOutcome.scheduled;
  List<ScheduledStep>? scheduled;

  @override
  Future<ScheduleOutcome> scheduleBake({
    required String recipeName,
    required List<ScheduledStep> steps,
  }) async {
    scheduled = steps;
    return outcome;
  }

  @override
  Future<void> cancelBake() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stand-in for the shipped asset. The real file is parsed in
/// `test/state/library_controller_test.dart`, where the clock is real.
final fixtureSystemRecipes = [
  SavedRecipe(
    id: 'sys-country-sourdough',
    name: 'Country Sourdough',
    isSystem: true,
    input: const RecipeInput(
      style: DoughStyle.sourdough,
      totalDoughWeight: 900,
      hydration: 75,
      salt: 2,
      levainPercent: 20,
      levainHydration: 100,
      flourBlend: [
        FlourPart(name: 'Bread flour', percent: 90),
        FlourPart(name: 'Whole wheat', percent: 10),
      ],
    ),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
];

void main() {
  late InMemoryRecipeRepository repository;
  late SettingsRepository settings;
  late FakeNotifications notifications;

  setUp(() async {
    repository = InMemoryRecipeRepository();
    notifications = FakeNotifications();
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(await SharedPreferences.getInstance());
  });

  Widget app({RecipeRepository? store}) => ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      recipeRepositoryProvider.overrideWithValue(store ?? repository),
      systemRecipesProvider.overrideWith((ref) => fixtureSystemRecipes),
      notificationServiceProvider.overrideWithValue(notifications),
    ],
    child: const BakersCalculatorApp(),
  );

  /// A small phone, so the tests exercise the single-column layout most people
  /// will see. `flutter_test` otherwise defaults to 800x600, which trips the
  /// tablet breakpoint.
  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Boots into the default 900 g sourdough, which every test starts from.
  Future<void> boot(WidgetTester tester, {RecipeRepository? store}) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(app(store: store));
    await tester.pumpAndSettle();
  }

  Future<void> openRecipesTab(WidgetTester tester) async {
    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
  }

  /// Scrolls a control into view before tapping it. Long forms on a 375x812
  /// phone put plenty below the fold, and a missed tap only warns.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('boots straight into a calculated recipe', (tester) async {
    await boot(tester);

    expect(find.text("Baker's Calculator"), findsOneWidget);
    // Not an empty form: the starting values already make a real loaf.
    expect(find.text('Levain'), findsWidgets);
    expect(find.text('Total dough'), findsOneWidget);
    expect(find.text('900 g'), findsOneWidget);
  });

  testWidgets('typing a new dough weight recalculates without a button', (
    tester,
  ) async {
    await boot(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Total dough weight'),
      '1800',
    );
    await tester.pumpAndSettle();

    expect(find.text('1800 g'), findsOneWidget);
  });

  testWidgets('an unusable value blocks the recipe and says why', (
    tester,
  ) async {
    await boot(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Total dough weight'),
      '0',
    );
    await tester.pumpAndSettle();

    expect(find.text('Total dough'), findsNothing);
    expect(find.textContaining('greater than zero'), findsWidgets);
  });

  testWidgets('a field can be emptied and retyped', (tester) async {
    await boot(tester);
    final field = find.widgetWithText(TextField, 'Total dough weight');

    await tester.enterText(field, '');
    await tester.pumpAndSettle();

    // The box stays empty instead of typing the old value back in — otherwise
    // 900 -> 1000 means backspacing to "9", typing "1000", and deleting the 9.
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(find.text('Total dough'), findsNothing);
    expect(find.textContaining('Dough weight is required'), findsWidgets);

    await tester.enterText(field, '1000');
    await tester.pumpAndSettle();

    expect(find.text('1000 g'), findsOneWidget);
  });

  testWidgets('an unusual but workable value warns without blocking', (
    tester,
  ) async {
    await boot(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Hydration'), '99');
    await tester.pumpAndSettle();

    expect(find.textContaining('Very slack dough'), findsOneWidget);
    // Still calculated — a warning must never stop the baker.
    expect(find.text('Total dough'), findsOneWidget);
  });

  testWidgets('switching dough style swaps the fields it needs', (
    tester,
  ) async {
    await boot(tester);
    expect(find.widgetWithText(TextField, 'Levain'), findsOneWidget);

    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Levain'), findsNothing);
    expect(find.widgetWithText(TextField, 'Flour weight'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Yeast'), findsOneWidget);
    expect(find.text('Total dough'), findsOneWidget);
  });

  testWidgets('the loaf stepper scales the batch', (tester) async {
    await boot(tester);

    // The batch card sits below the fold on a phone.
    await tester.ensureVisible(find.byTooltip('One more loaf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('One more loaf'));
    await tester.pumpAndSettle();

    expect(find.text('1800 g'), findsOneWidget);
    expect(find.textContaining('Each'), findsOneWidget);
  });

  testWidgets('the library ships with built-in recipes and no saved ones', (
    tester,
  ) async {
    await boot(tester);
    await openRecipesTab(tester);

    expect(find.text('Built in'), findsOneWidget);
    expect(find.text('Country Sourdough'), findsOneWidget);
    expect(find.text('Your recipes'), findsNothing);
  });

  testWidgets('saving a recipe stores it and lists it', (tester) async {
    await boot(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Saturday loaf',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await openRecipesTab(tester);

    expect(find.text('Your recipes'), findsOneWidget);
    expect(find.text('Saturday loaf'), findsOneWidget);

    // And it really reached the store, not just the screen.
    expect(repository.saveCount, 1);
    expect(repository.recipes.single.name, 'Saturday loaf');
    expect(repository.recipes.single.input.totalDoughWeight, 900);
  });

  testWidgets('saving before the library has loaded does not lose recipes', (
    tester,
  ) async {
    // The baker may save from the calculator without ever opening Recipes, so
    // the write can beat the first read. Both must survive.
    repository.recipes = [
      SavedRecipe(
        id: 'existing',
        name: 'Last week',
        input: startingPoint,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];

    await boot(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.recipes.map((r) => r.name), contains('Last week'));
    expect(repository.recipes, hasLength(2));
  });

  testWidgets('a store that cannot be read is reported, not swallowed', (
    tester,
  ) async {
    await boot(
      tester,
      store: InMemoryRecipeRepository(
        loadError: 'Your recipe file could not be read.',
      ),
    );
    await openRecipesTab(tester);

    expect(find.textContaining('could not be read'), findsOneWidget);
    // Built-ins still work, so the app stays useful.
    expect(find.text('Country Sourdough'), findsOneWidget);
  });

  testWidgets('opening a saved recipe loads it into the calculator', (
    tester,
  ) async {
    await boot(tester);
    await openRecipesTab(tester);

    await tester.tap(find.text('Country Sourdough'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Built-in recipe'), findsOneWidget);

    await tester.tap(find.byTooltip('Open in calculator'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Total dough weight'),
      findsOneWidget,
    );
    // The built-in is a 90/10 blend, so the calculator should show both flours.
    expect(find.text('Bread flour'), findsWidgets);
  });

  testWidgets('the dough temperature tool computes as you change inputs', (
    tester,
  ) async {
    await boot(tester);

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();

    // Scrolls the dough-temperature card into view.
    await tester.ensureVisible(find.text('Mixer'));
    await tester.pumpAndSettle();

    // 25 x 3 - (21 + 20 + 1) = 33
    expect(find.text('33.0 °C'), findsOneWidget);

    await tapVisible(tester, find.text('Mixer'));

    // Friction 5 instead of 1 takes 4 degrees off the water.
    expect(find.text('29.0 °C'), findsOneWidget);
  });

  testWidgets('planning a bake lays out the steps and sets reminders', (
    tester,
  ) async {
    await boot(tester);
    await openRecipesTab(tester);

    await tester.tap(find.text('Country Sourdough'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Plan this bake'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Timing'), findsOneWidget);
    expect(find.text('Autolyse'), findsOneWidget);

    // The list is long; the later steps are built as it scrolls.
    await tester.scrollUntilVisible(find.text('Cold proof'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Cold proof'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Start bake'));
    await tester.pumpAndSettle();

    expect(notifications.scheduled, isNotNull);
    expect(find.textContaining('Reminders set'), findsOneWidget);
  });

  testWidgets('a refused notification permission does not break the plan', (
    tester,
  ) async {
    notifications.outcome = ScheduleOutcome.permissionDenied;

    await boot(tester);
    await openRecipesTab(tester);
    await tester.tap(find.text('Country Sourdough'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Plan this bake'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Start bake'));
    await tester.pumpAndSettle();

    expect(find.textContaining('still here to follow'), findsOneWidget);
    // The plan is untouched.
    expect(find.text('Autolyse'), findsOneWidget);
  });

  testWidgets('the wizard composes a recipe and saves it', (tester) async {
    await boot(tester);

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Suggest a recipe'));

    await tapVisible(tester, find.text('Rich and sweet'));
    await tapVisible(tester, find.text('Classic'));

    // The composed recipe is on screen straight away, no Generate button.
    await tester.ensureVisible(find.text('Total dough'));
    await tester.pumpAndSettle();
    expect(find.text('Total dough'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Save this recipe'),
    );
    await tester.pumpAndSettle();

    expect(repository.recipes.single.name, 'Rich and sweet');
    expect(repository.recipes.single.input.enrichment, isNotNull);
    expect(repository.recipes.single.input.style, DoughStyle.classic);
  });

  testWidgets('wide screens show the form and the result side by side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // A rail instead of a bottom bar, and the recipe visible without scrolling.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Total dough'), findsOneWidget);
  });
}
