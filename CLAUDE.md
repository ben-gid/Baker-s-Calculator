# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app (`bakers_calculator`) that turns baker's percentages into a
gram-by-gram bread recipe, plans the bake, and stores a recipe library. Offline
only — no backend, no network calls, no analytics. Targets Android/iOS/web/
desktop; Android is the configured publish target.

## Commands

```bash
flutter pub get
flutter run                     # add -d chrome | linux | <device-id>
flutter analyze                 # must stay clean
dart format lib test
flutter test
flutter test test/domain/       # the engine only — fast, no widget tree
flutter test test/app_test.dart --plain-name 'saving a recipe stores it and lists it'
dart run flutter_launcher_icons  # regenerate icons from assets/app_icon.png
```

## Architecture

Four layers, and the dependency direction is strict: `ui` → `state` → `data`,
everything → `domain`, and **`domain` imports nothing from the others**.

```
lib/
  domain/   pure Dart. calculator, validation, scaling, dough_temp, timeline,
            wizard, models. No `package:flutter` import anywhere in here.
  data/     recipe_repository, system_recipes, recipe_share,
            settings_repository, notification_service.
  state/    providers.dart — every Riverpod provider and controller.
  ui/       router.dart, shell.dart, and one directory per screen.
  core/     theme/ (colours, type, spacing tokens) and formatting.dart.
```

### The domain is the product

`calculate(RecipeInput) -> Recipe` in [lib/domain/calculator.dart](lib/domain/calculator.dart)
is the whole app in one function. `RecipeInput` is immutable and serialisable;
`Recipe` is display-ready with grams **and** baker's percentage per ingredient.

**The flour in the dough is 100%.** Every percentage the baker types is a share
of the flour weighed into the bowl, and a levain or preferment is just another
ingredient measured against it — the way a written recipe reads ("500 g flour,
375 g water, 100 g starter"). So the flour row says 100% whether or not there
is a preferment, and a blend splits exactly that 100%.

- **Classic** is *forward*: flour weight is given, everything scales off it.
- **Sourdough / preferment** are *inverse*: finished dough weight is given, so
  flour is solved by dividing by the baker's-percentage denominator, which
  includes the levain/preferment percentage because the lump is weighed out
  whole. Egg weight is subtracted **before** the division because eggs are a
  count, not a percentage of flour. Mix-ins are deliberately *outside* the
  denominator: "total dough weight" is the dough, and seeds go on top of it.
- `Recipe.totalFlour`, `totalWater` and `hydration` still count what the levain
  carries in, so the totals card shows the dough's **true** hydration, a little
  above the figure typed in. It is labelled "Total hydration" for that reason —
  the two numbers differing is correct, not a rounding bug.

Do not put math in `state/` or `ui/`. If a screen needs a number, add a pure
function to `domain/` and test it there.

### The regression baseline is load-bearing

`test/domain/legacy_goldens.json` was generated from the app's original
label-keyed calculator before it was deleted. `calculator_parity_test.dart`
asserts every **classic** number still comes out of the new engine, except two
documented corrections in `knownLegacyBugs` (the old classic path summed the egg
*count* into total weight instead of the egg *weight*).

The sourdough and preferment goldens are exempt via `rebasedStyles`: the legacy
engine measured against *total* flour, and the app now measures against the
dough's flour, so the meaning of those inputs changed and every gram moved.
Re-recording them would assert nothing, so the `dough flour is 100%` group
asserts the algebra itself instead. The goldens stay in the file as the record.

**Never regenerate the goldens to make a test pass.** If a change moves a
number, either it is a bug, or it is a deliberate correction that belongs in
`knownLegacyBugs` with the arithmetic spelled out in a comment.

### Validation is separate from calculation

`validate(RecipeInput)` returns `List<InputIssue>` tagged with a `RecipeField`
so the UI attaches each message to the right control. `IssueSeverity.error`
means `calculate()` would be wrong or throw; `IssueSeverity.warning` is
advisory and **must never block anything**. `calculationProvider` returns null
only on errors.

Every numeric input is nullable and an empty box means **null, not zero**.
`NumberField` only rewrites its controller when state disagrees with what is
typed, so coercing a blank to a number in `onChanged` types that number straight
back in and the field can never be cleared — you would have to backspace 900
down to 9, type 1000, then delete the 9. That is why `RecipeInput.copyWith`
takes an `_unset` sentinel rather than `??`, so `copyWith(x: null)` clears.
`validate()` then errors on the null and the recipe is blocked until it is
refilled. Do not reintroduce `?? 0` in an `onChanged`.

### Testing seams, and the fake clock

`flutter_test` runs `testWidgets` bodies on a fake clock, so **real file I/O and
`rootBundle` never complete inside one**. That is why `RecipeRepository`,
`systemRecipesProvider` and `NotificationService` are all injectable:

- widget tests (`test/app_test.dart`) override all three with in-memory fakes;
- the real file store is tested in `test/data/recipe_repository_test.dart` using
  plain `test()`, where the clock is real;
- the real asset is parsed in `test/state/library_controller_test.dart`.

Do not reintroduce real I/O into widget tests. Long forms sit below the fold on
the 375x812 test phone — use the `tapVisible` helper rather than bare `tap`,
which only warns when it misses.

### Library mutations are serialised

`LibraryController` reads-modifies-writes the whole recipe list. Two overlapping
mutations would both read the same starting list and the second would discard
the first, so every mutation goes through `_serialised()`, and `_ready()` waits
for the first load before writing — saving from the calculator routinely beats
the file read.

### Theme

The palette is *instrument*, not artisan: near-black ink on cool paper with a
single emerald accent, and saturation otherwise reserved for the two colours
that warn (`warn` amber, `error` red). Brown and cream were tried and rejected —
the app is a measuring tool, so it is dressed as one.

The signature is `0xFF34D399`, and it is the **dark-mode** accent only. Light
mode uses `0xFF047857` from the same family, because `34D399` measures 1.8:1 on
paper and cannot carry text or a filled button there. Per-mode accent values are
expected here, not a mistake to "fix" by unifying them.

Every colour comes from `Theme.of(context).colorScheme` or the `BakingColors`
theme extension ([lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart)).
No widget hardcodes a hex value. Spacing and radii come from
[lib/core/theme/spacing.dart](lib/core/theme/spacing.dart) — 4/8 dp only, plus
`pagePadding(context)`, which every full-screen scroll uses.

`colorScheme.primary` and `BakingColors.proof` are deliberately the same
emerald: dough being ready *is* the brand, so "ready" and "accent" are one
colour. They stay separate names so a future change can split them again.

`BakingColors.proofContainer` is a **tint**, not the accent, and that is load
bearing. The totals card and the dough-temp result box are both painted with
it, and between them they put four foregrounds on it — the total, muted labels,
advisory amber, and the card border. Painting it the saturated `34D399` was
tried and drops `warn` to 2.6:1. Muted text on it must use `onProofContainer`;
`onSurfaceVariant` fails in both modes.

Two faces. **IBM Plex Sans** (bundled variable font) for everything, with
weights selected via `FontVariation`, not `fontWeight` alone. **IBM Plex Mono**
for every gram, percentage and clock time — applied as
`fontFamily: numericFont, fontFeatures: tabularFigures` together, always both.
Mono has no variable cut, so `pubspec.yaml` registers static 400/500/600/700;
the text theme must not ask for a weight outside that set or Flutter
synthesises a fake one.

`test/theme_contrast_test.dart` re-measures every ratio the palette claims in
its comments — AA (4.5:1) for text on all three surfaces, and 3:1 for
`outline`, which draws the boundary of controls the baker operates.
`outlineVariant` is exempt: card edges and dividers only.

### Navigation

`go_router` with a three-branch `StatefulShellRoute` (Calculate / Recipes /
Tools). `/recipe/:id`, `/recipe/:id/plan`, `/import`, `/suggest` and `/settings`
sit outside the shell so a shared link opens straight onto content.
`bakerscalc://import?d=<base64url>` is registered in the Android manifest and
iOS `Info.plist`.

## Conventions

- Imported and pasted recipe JSON is untrusted: decode through
  `RecipeInput.fromJson` (which throws `FormatException`) and run `validate()`
  before offering to save. `isSystem` is never read from JSON.
- A failed *load* of the recipe file surfaces as an error banner and the damaged
  file is renamed `.corrupt` — never silently start with an empty library.
- Notification permission is requested at "Start bake", never at launch, and a
  refusal must leave the plan on screen and everything else working.

## Not yet done

Application ID is still `com.example.dough_calculator` in
`android/app/build.gradle.kts`; it is permanent after the first upload, so it
was left rather than guessed. Same for the iOS bundle identifier.
