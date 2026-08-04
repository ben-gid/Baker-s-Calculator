# Baker's Calculator

Work out bread recipes from baker's percentages, plan the bake, and keep your
loaves in one place. Everything stays on the device — no account, no network,
no analytics.

## What it does

- **Three dough methods.** Classic yeast (you give the flour weight), sourdough
  and preferment (you give the finished dough weight and the flour is solved
  for).
- **Live results.** No Calculate button — the recipe updates as you type, with
  baker's percentages beside every gram and a grams/ounces toggle.
- **Scaling.** By loaf count, by target dough weight, or by however much flour
  you actually have.
- **Flour blends, enrichment and mix-ins.** Optional, collapsed until you want
  them.
- **Recipes.** Save, search, favourite, duplicate. Seventeen built-in recipes
  ship with the app, read-only, with "Save a copy" to make one yours.
- **Bake timeline.** A schedule derived from the recipe — autolyse, bulk, folds,
  shape, proof, bake — pinned to a start time or worked backwards from "out of
  the oven by 8am", with local reminders.
- **Dough temperature.** Desired dough temperature to required water
  temperature.
- **Suggest a recipe.** Four choices compose a complete, valid recipe from
  presets. Deterministic and offline; no model involved.
- **Share and import.** As readable text, as a JSON file, or as a
  `bakerscalc://import?d=…` link that reopens in the app.

## Running it

```bash
flutter pub get
flutter run              # add -d chrome | linux | <device-id>
flutter test
flutter analyze
```

## How it is put together

```
lib/
  domain/     pure Dart — no Flutter import anywhere. The baking engine.
  data/       storage, sharing, notifications. Each one is swappable in tests.
  state/      Riverpod controllers. Immutable state, no math.
  ui/         screens and widgets. No business logic.
  core/       theme tokens and number formatting.
```

The `domain/` layer is the point of the structure: `calculate()`, `validate()`,
`buildTimeline()` and `composeRecipe()` are pure functions over immutable
inputs, so the maths is unit-tested without a widget tree and the same engine
backs the calculator, the library, the wizard and the share text.

`test/domain/legacy_goldens.json` is a regression baseline captured from this
app's original calculator before it was rewritten. Every number that version
produced is still asserted, apart from two deliberate corrections documented in
`calculator_parity_test.dart`.

## Before publishing

The application ID still needs setting. It is permanent once a build is
uploaded, so it has deliberately been left at the Flutter default rather than
guessed:

- `android/app/build.gradle.kts` — `namespace` and `applicationId`, currently
  `com.example.dough_calculator`.
- Xcode — `PRODUCT_BUNDLE_IDENTIFIER` for the iOS target.

Then `flutter build appbundle --release`.

## Licence

Bundled font: Plus Jakarta Sans, SIL Open Font License 1.1 — see
`assets/fonts/OFL.txt`.
