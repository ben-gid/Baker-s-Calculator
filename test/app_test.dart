/// End-to-end checks through the real widget tree: the app boots, the
/// calculator recalculates as you type, bad input blocks the result instead of
/// showing nonsense, and saving reaches the store.
///
/// Storage is in memory here. `flutter_test` runs the test body on a fake
/// clock, so real file I/O would need a `runAsync` dance around every pump —
/// the file store's own behaviour is covered directly in
/// `test/data/recipe_repository_test.dart`, where the clock is real.
library;

import 'dart:async';

import 'package:bakers_calculator/app.dart';
import 'package:bakers_calculator/core/formatting.dart';
import 'package:bakers_calculator/data/notification_service.dart';
import 'package:bakers_calculator/data/recipe_repository.dart';
import 'package:bakers_calculator/data/settings_repository.dart';
import 'package:bakers_calculator/domain/models/active_bake.dart';
import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:bakers_calculator/domain/models/saved_recipe.dart';
import 'package:bakers_calculator/state/providers.dart';
import 'package:bakers_calculator/ui/widgets/action_bar.dart';
import 'package:bakers_calculator/ui/widgets/number_field.dart';
import 'package:bakers_calculator/ui/widgets/starter_jar.dart';
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
  ActiveBake? scheduled;
  int permissionAsks = 0;

  @override
  Future<ScheduleOutcome> scheduleBake(
    ActiveBake bake, {
    bool askPermission = true,
  }) async {
    scheduled = bake;
    if (askPermission) permissionAsks++;
    return outcome;
  }

  final _presses = StreamController<BakeResponse>.broadcast();

  /// A reminder's button, pressed while the app is open.
  void press(BakeAction action, int step) =>
      _presses.add((action: action, step: step));

  @override
  Stream<BakeResponse> get actions => _presses.stream;

  bool cancelled = false;

  @override
  Future<void> cancelBake() async => cancelled = true;

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

  /// The jar is alive — its surface and bubbles move for as long as it is on
  /// screen — so `pumpAndSettle` would never settle. These tests ask for
  /// reduced motion, which the jar and every entrance animation honour; the
  /// moving path has its own test below.
  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// A small phone, so the tests exercise the single-column layout most people
  /// will see. `flutter_test` otherwise defaults to 800x600, which trips the
  /// tablet breakpoint.
  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    reduceMotion(tester);
  }

  /// Boots onto Home.
  Future<void> boot(WidgetTester tester, {RecipeRepository? store}) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(app(store: store));
    await tester.pumpAndSettle();
  }

  /// The text box inside the [NumberField] or [NameField] carrying this label.
  /// The label sits *above* the box now rather than floating inside its border,
  /// so it is a sibling of the `TextField` and `find.widgetWithText` no longer
  /// reaches it.
  Finder fieldNamed(String label) => find.descendant(
    of: find.byWidgetPredicate(
      (w) =>
          (w is NumberField && w.label == label) ||
          (w is NameField && w.label == label),
    ),
    matching: find.byType(TextField),
  );

  /// The pinned primary action, which replaced the floating action button.
  Finder actionBar(String label) =>
      find.byWidgetPredicate((w) => w is ActionBar && w.label == label);

  /// A button inside the modal sheet. Scoped, because the sheet's confirm button
  /// and the [ActionBar] behind it deliberately carry the same word.
  Finder sheetButton(String label) => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.widgetWithText(FilledButton, label),
  );

  Future<void> openNewDough(WidgetTester tester) async {
    await tester.tap(find.text('New dough'));
    await tester.pumpAndSettle();
  }

  /// 500 g flour at 70% water, 2% salt, 1% yeast: an 865 g classic loaf.
  Future<void> fillClassic(WidgetTester tester) async {
    await tester.enterText(fieldNamed('Flour weight'), '500');
    await tester.enterText(fieldNamed('Total hydration'), '70');
    await tester.enterText(fieldNamed('Salt'), '2');
    await tester.enterText(fieldNamed('Yeast'), '1');
    await tester.pumpAndSettle();
  }

  /// The full library, behind the shelf's "See all" on Home.
  Future<void> openRecipesTab(WidgetTester tester) async {
    await tester.tap(find.text('See all'));
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

  testWidgets('boots onto Home', (tester) async {
    await boot(tester);

    expect(find.text("Baker's Calculator"), findsOneWidget);
    expect(find.text('New dough'), findsOneWidget);
    // Nothing saved yet, so the carousel offers the built-ins instead.
    expect(find.text('Built in'), findsOneWidget);
    expect(find.text('Country Sourdough'), findsOneWidget);
  });

  testWidgets('with motion on, the jar lives and flies into the calculator', (
    tester,
  ) async {
    // No reduceMotion here: this is the path every other test skips. The jar
    // never settles, so frames are pumped by time instead of pumpAndSettle.
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(StarterJar), findsWidgets);

    await tester.tap(find.text('New dough'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Arrived: the calculator's own jar, the sheet, and the blank dough.
    expect(
      find.text('Needs flour weight, yeast, total hydration and salt'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new dough starts blank and says what it needs', (
    tester,
  ) async {
    await boot(tester);
    await openNewDough(tester);

    expect(
      tester.widget<TextField>(fieldNamed('Flour weight')).controller!.text,
      isEmpty,
    );
    expect(find.text('Total dough'), findsNothing);
    expect(
      find.text('Needs flour weight, yeast, total hydration and salt'),
      findsOneWidget,
    );
    // Nothing to weigh yet, so no way on to the recipe.
    expect(tester.widget<ActionBar>(actionBar('See recipe')).onPressed, isNull);

    expect(
      tester.widget<TextField>(fieldNamed('Total hydration')).controller!.text,
      isEmpty,
    );
  });

  testWidgets('filling in the blanks calculates without a button', (
    tester,
  ) async {
    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);

    // 500 + 350 + 10 + 5, rolling in the header while the dough is typed.
    expect(find.text('865 g'), findsOneWidget);
    expect(find.text('Total dough'), findsOneWidget);

    // And the recipe lays out each weight beside its percentage.
    await tester.tap(actionBar('See recipe'));
    await tester.pumpAndSettle();
    expect(find.text('350 g'), findsWidgets);
    expect(actionBar('Save'), findsOneWidget);

    // Back is the form again, still filled in.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(fieldNamed('Total hydration')).controller!.text,
      '70',
    );
  });

  testWidgets('an unusable value blocks the recipe and says why', (
    tester,
  ) async {
    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);

    await tester.enterText(fieldNamed('Flour weight'), '0');
    await tester.pumpAndSettle();

    expect(find.text('Total dough'), findsNothing);
    expect(find.textContaining('greater than zero'), findsOneWidget);
    expect(tester.widget<ActionBar>(actionBar('See recipe')).onPressed, isNull);
  });

  testWidgets('a field can be emptied and retyped', (tester) async {
    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);
    final field = fieldNamed('Flour weight');

    await tester.enterText(field, '');
    await tester.pumpAndSettle();

    // The box stays empty instead of typing the old value back in — otherwise
    // 500 -> 1000 means backspacing to "5", typing "1000", and deleting the 5.
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(find.text('Total dough'), findsNothing);
    expect(find.text('Needs flour weight'), findsOneWidget);

    await tester.enterText(field, '1000');
    await tester.pumpAndSettle();

    expect(find.text('1730 g'), findsOneWidget);
  });

  testWidgets('an unusual but workable value warns without blocking', (
    tester,
  ) async {
    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);

    await tester.enterText(fieldNamed('Total hydration'), '99');
    await tester.pumpAndSettle();

    expect(find.textContaining('Very slack dough'), findsOneWidget);
    // Still calculated — a warning must never stop the baker.
    expect(find.text('Total dough'), findsOneWidget);
  });

  testWidgets('switching style swaps the rows and keeps what was typed', (
    tester,
  ) async {
    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);

    await tester.tap(find.text('Sourdough'));
    await tester.pumpAndSettle();

    // Sourdough solves from the dough weight, and nothing is filled in for it.
    expect(fieldNamed('Dough weight'), findsOneWidget);
    expect(
      find.text('Needs dough weight, levain and levain hydration'),
      findsOneWidget,
    );

    expect(fieldNamed('Yeast'), findsNothing);
    expect(fieldNamed('Levain'), findsOneWidget);
    expect(
      tester.widget<TextField>(fieldNamed('Total hydration')).controller!.text,
      '70',
    );

    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();
    expect(find.text('865 g'), findsOneWidget);
  });

  testWidgets('the loaf stepper scales the batch', (tester) async {
    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);
    await tester.tap(actionBar('See recipe'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('One more loaf'));
    await tester.pumpAndSettle();

    expect(find.text('1730 g'), findsOneWidget);
    expect(find.textContaining('Each'), findsOneWidget);
  });

  testWidgets('a template fills the form, and Blank empties it', (
    tester,
  ) async {
    await boot(tester);
    await openNewDough(tester);

    await tester.tap(find.text('Template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Country Sourdough').last);
    await tester.pumpAndSettle();

    // Onto the form, filled in, with nothing popping up over it.
    expect(find.text('Total dough'), findsOneWidget);
    expect(find.text('900 g'), findsOneWidget);
    expect(find.text('Bread flour'), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank'));
    await tester.pumpAndSettle();

    expect(find.text('Total dough'), findsNothing);
    expect(find.text('Bread flour'), findsNothing);
  });

  testWidgets('ingredients are added as rows, and an empty one stays put', (
    tester,
  ) async {
    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);

    await tapVisible(tester, find.text('Add ingredient'));
    await tester.tap(find.text('Fat').last);
    await tester.pumpAndSettle();

    // Added empty: the box is there, and the recipe still works without it.
    expect(fieldNamed('Fat'), findsOneWidget);
    expect(find.text('Total dough'), findsOneWidget);

    await tester.enterText(fieldNamed('Fat'), '10');
    await tester.pumpAndSettle();
    expect(find.text('915 g'), findsOneWidget);

    // Clearing the box must not take the row away mid-edit.
    await tester.enterText(fieldNamed('Fat'), '');
    await tester.pumpAndSettle();
    expect(fieldNamed('Fat'), findsOneWidget);

    await tapVisible(tester, find.text('Add ingredient'));
    await tester.tap(find.text('Mix-in').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Name every mix-in'), findsOneWidget);

    await tester.enterText(fieldNamed('Mix-in 1'), 'Seeds');
    await tester.enterText(fieldNamed('Mix-in 1 share'), '10');
    await tester.pumpAndSettle();
    expect(find.text('915 g'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Remove Seeds'));
    expect(find.text('865 g'), findsOneWidget);
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
    await openNewDough(tester);
    await fillClassic(tester);

    await tester.tap(actionBar('See recipe'));
    await tester.pumpAndSettle();
    await tester.tap(actionBar('Save'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('save-recipe-name')),
      'Saturday loaf',
    );
    await tester.tap(sheetButton('Save'));
    await tester.pumpAndSettle();

    // Back to the form, down to Home, then the whole library.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openRecipesTab(tester);

    expect(find.text('Your recipes'), findsOneWidget);
    expect(find.text('Saturday loaf'), findsOneWidget);

    // And it really reached the store, not just the screen.
    expect(repository.saveCount, 1);
    expect(repository.recipes.single.name, 'Saturday loaf');
    expect(repository.recipes.single.input.flourWeight, 500);
  });

  testWidgets('Home leads back to the dough and lists what was saved', (
    tester,
  ) async {
    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);
    await tester.tap(actionBar('See recipe'));
    await tester.pumpAndSettle();
    await tester.tap(actionBar('Save'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('save-recipe-name')),
      'Saturday loaf',
    );
    await tester.tap(sheetButton('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Saturday loaf'), findsOneWidget);

    await tester.tap(find.text('Back to your 865 g dough'));
    await tester.pumpAndSettle();
    // Back onto the form, as it was left.
    expect(find.text('865 g'), findsOneWidget);
    expect(actionBar('See recipe'), findsOneWidget);
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
        input: fixtureSystemRecipes.single.input,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];

    await boot(tester);
    await openNewDough(tester);
    await fillClassic(tester);
    await tester.tap(actionBar('See recipe'));
    await tester.pumpAndSettle();
    await tester.tap(actionBar('Save'));
    await tester.pumpAndSettle();
    await tester.tap(sheetButton('Save'));
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

    // Onto the form, filled in — a 90/10 blend, so both flours are there.
    expect(find.text('900 g'), findsOneWidget);
    expect(find.text('Bread flour'), findsWidgets);
    expect(fieldNamed('Dough weight'), findsOneWidget);
    expect(fieldNamed('Flour 1 share'), findsOneWidget);
  });

  testWidgets('the plan works out the water temperature as inputs change', (
    tester,
  ) async {
    await boot(tester);
    await openRecipesTab(tester);
    await tester.tap(find.text('Country Sourdough'));
    await tester.pumpAndSettle();
    await tester.tap(actionBar('Plan this bake'));
    await tester.pumpAndSettle();

    // The card sits at the foot of the plan, past the lazily built steps.
    await tester.scrollUntilVisible(find.text('Mixer'), 300);
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
    await tester.tap(actionBar('Plan this bake'));
    await tester.pumpAndSettle();

    expect(find.text('Timing'), findsOneWidget);
    expect(find.text('Feed the levain'), findsOneWidget);

    // The list is long; the later steps are built as it scrolls.
    await tester.scrollUntilVisible(find.text('Cold proof'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Cold proof'), findsOneWidget);

    await tester.tap(actionBar('Start bake'));
    await tester.pumpAndSettle();

    expect(notifications.scheduled, isNotNull);
    expect(find.textContaining('Reminders set'), findsOneWidget);

    // Home now shows the bake under way, until it is stopped: back out of the
    // plan, the recipe and the library.
    for (var i = 0; i < 3; i++) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(find.text('Stop bake'), findsOneWidget);
    expect(find.textContaining('Feed the levain'), findsOneWidget);
    expect(settings.readActiveBake()?.recipeName, 'Country Sourdough');

    await tester.tap(find.text('Stop bake'));
    await tester.pumpAndSettle();

    expect(find.text('Stop bake'), findsNothing);
    expect(notifications.cancelled, isTrue);
    expect(settings.readActiveBake(), isNull);
  });

  testWidgets('a refused notification permission does not break the plan', (
    tester,
  ) async {
    notifications.outcome = ScheduleOutcome.permissionDenied;

    await boot(tester);
    await openRecipesTab(tester);
    await tester.tap(find.text('Country Sourdough'));
    await tester.pumpAndSettle();
    await tester.tap(actionBar('Plan this bake'));
    await tester.pumpAndSettle();
    await tester.tap(actionBar('Start bake'));
    await tester.pumpAndSettle();

    expect(find.textContaining('still here to follow'), findsOneWidget);
    // The plan is untouched.
    expect(find.text('Autolyse'), findsOneWidget);
  });

  /// Opens Country Sourdough's plan, before anything is started.
  Future<void> openPlan(WidgetTester tester) async {
    await boot(tester);
    await openRecipesTab(tester);
    await tester.tap(find.text('Country Sourdough'));
    await tester.pumpAndSettle();
    await tester.tap(actionBar('Plan this bake'));
    await tester.pumpAndSettle();
  }

  /// The card of the plan's step with this title.
  Finder stepCard(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Card));

  testWidgets('leaving out the autolyse moves its flour and water to the mix', (
    tester,
  ) async {
    await openPlan(tester);
    await tester.scrollUntilVisible(find.text('Autolyse'), 200);
    await tester.pumpAndSettle();

    // Before: the flour is weighed at the autolyse.
    expect(
      find.descendant(
        of: stepCard('Autolyse'),
        matching: find.text('Bread flour'),
      ),
      findsOneWidget,
    );

    await tapVisible(
      tester,
      find.descendant(of: stepCard('Autolyse'), matching: find.byType(Switch)),
    );

    await tester.scrollUntilVisible(find.text('Left out'), -200);
    expect(find.text('Left out'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Add levain and salt'), 200);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: stepCard('Add levain and salt'),
        matching: find.text('Bread flour'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the levain feed is weighed out on the plan', (tester) async {
    await openPlan(tester);
    expect(find.text('Ripe starter'), findsOneWidget);

    await tapVisible(tester, find.textContaining('1:5:5'));
    expect(
      find.descendant(
        of: stepCard('Feed the levain'),
        matching: find.text('10 h'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the step under way opens on Home, and Done moves the bake on', (
    tester,
  ) async {
    await openPlan(tester);
    await tester.tap(actionBar('Start bake'));
    await tester.pumpAndSettle();
    expect(notifications.permissionAsks, 1);
    for (var i = 0; i < 3; i++) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    // Collapsed: the headline and the dots, no grams yet.
    expect(find.text('Ripe starter'), findsNothing);
    await tester.tap(find.textContaining('Feed the levain'));
    await tester.pumpAndSettle();

    expect(find.text('Ripe starter'), findsOneWidget);
    expect(find.textContaining('back for your jar'), findsOneWidget);

    // Ticking a row as weighed holds nothing up.
    await tapVisible(tester, find.bySemanticsLabel(RegExp('Ripe starter')));
    expect(settings.readActiveBake()!.weighed, hasLength(1));

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Done'));

    expect(find.text('Feed the levain done'), findsOneWidget);
    expect(find.textContaining('Autolyse'), findsWidgets);
    final saved = settings.readActiveBake()!;
    expect(saved.records.first.status, StepStatus.done);
    // The reminders moved with it, without asking again.
    expect(notifications.scheduled!.records.first.status, StepStatus.done);
    expect(notifications.permissionAsks, 1);
  });

  testWidgets('a reminder\'s Done button moves the bake on', (tester) async {
    await openPlan(tester);
    await tester.tap(actionBar('Start bake'));
    await tester.pumpAndSettle();

    notifications.press(BakeAction.done, 0);
    await tester.pumpAndSettle();

    expect(settings.readActiveBake()!.records.first.status, StepStatus.done);
  });

  testWidgets('the live plan skips ahead and goes back', (tester) async {
    await openPlan(tester);
    await tester.tap(actionBar('Start bake'));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).first;

    // The plan is now the bake's checklist, the step under way open as its
    // card. Feed the levain, then autolyse.
    expect(actionBar('Stop bake'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Done'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Done'));
    var bake = settings.readActiveBake()!;
    expect(bake.records[0].status, StepStatus.done);
    expect(bake.records[1].status, StepStatus.done);

    // Skip the mix, straight to the folds.
    await tester.scrollUntilVisible(
      find.text('Stretch and fold'),
      200,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Stretch and fold'));
    await tapVisible(tester, find.text('Skip to this step'));

    bake = settings.readActiveBake()!;
    expect(bake.records[2].status, StepStatus.skipped);
    expect(bake.currentAt(DateTime.now()), 3);
    expect(find.text('Set done'), findsOneWidget);

    // Back to the levain. The autolyse after it was ticked, so it asks
    // whether to do that again.
    await tester.scrollUntilVisible(
      find.text('Feed the levain'),
      -200,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Feed the levain'));
    await tapVisible(tester, find.text('Go back to this step'));
    expect(find.text('Go back to feed the levain?'), findsOneWidget);
    await tapVisible(tester, find.text('Do them again'));

    bake = settings.readActiveBake()!;
    expect(bake.currentAt(DateTime.now()), 0);
    expect(bake.records.every((r) => r.status == StepStatus.pending), isTrue);
  });

  testWidgets('the wizard composes a recipe and saves it', (tester) async {
    await boot(tester);

    // Nothing saved yet, so the tools sit on the empty jar.
    await tapVisible(tester, find.text('Suggest a recipe'));

    await tapVisible(tester, find.text('Rich and sweet'));
    await tapVisible(tester, find.text('Classic'));

    // The composed recipe is there straight away, no Generate button — but it
    // is the last thing in a lazy list, so it has to be scrolled into being.
    await tester.scrollUntilVisible(find.text('Total dough'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Total dough'), findsOneWidget);

    await tester.tap(actionBar('Save this recipe'));
    await tester.pumpAndSettle();

    expect(repository.recipes.single.name, 'Rich and sweet');
    expect(repository.recipes.single.input.enrichment, isNotNull);
    expect(repository.recipes.single.input.style, DoughStyle.classic);
  });

  testWidgets('wide screens keep the jar beside the form', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    reduceMotion(tester);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openNewDough(tester);
    await tester.tap(find.text('Template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Country Sourdough').last);
    await tester.pumpAndSettle();

    // The jar beside the form, visible without scrolling.
    expect(find.text('Total dough'), findsWidgets);
    expect(find.text('Bread flour'), findsWidgets);
  });

  testWidgets('a recipe page scales for one bake without changing the recipe', (
    tester,
  ) async {
    await boot(tester);
    await openRecipesTab(tester);
    await tester.tap(find.text('Country Sourdough'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byTooltip('One more loaf'));
    expect(find.text('1800 g'), findsWidgets);

    // The calculator takes the count on screen, not the saved one.
    await tester.tap(find.byTooltip('Open in calculator'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Each 900 g'), findsOneWidget);

    // Back on the page, it is the saved recipe again.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openRecipesTab(tester);
    await tester.tap(find.text('Country Sourdough'));
    await tester.pumpAndSettle();
    expect(find.text('1800 g'), findsNothing);
  });

  testWidgets('the wizard saves the loaves it was asked for', (tester) async {
    await boot(tester);
    await tapVisible(tester, find.text('Suggest a recipe'));

    await tester.scrollUntilVisible(find.byTooltip('One more loaf'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('One more loaf'));
    await tester.pumpAndSettle();

    await tester.tap(actionBar('Save this recipe'));
    await tester.pumpAndSettle();

    expect(repository.recipes.single.input.loaves, 2);
  });

  testWidgets('in ounces, the weight is typed and shown in ounces', (
    tester,
  ) async {
    await settings.write(const Settings(unit: MassUnit.ounces));
    await boot(tester);
    await openNewDough(tester);

    expect(find.text('oz'), findsOneWidget);
    await tester.enterText(fieldNamed('Flour weight'), '20');
    await tester.enterText(fieldNamed('Total hydration'), '70');
    await tester.enterText(fieldNamed('Salt'), '2');
    await tester.enterText(fieldNamed('Yeast'), '1');
    await tester.pumpAndSettle();

    // 20 oz of flour at 173% all told.
    expect(find.text('34.60 oz'), findsOneWidget);

    // Kept in grams underneath, the box still reads what was typed.
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(fieldNamed('Flour weight')).controller!.text,
      '20',
    );
  });
}
