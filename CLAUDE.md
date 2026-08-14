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
which only warns when it misses. `ensureVisible` cannot reach an item a lazy
`ListView` has not built yet; `scrollUntilVisible` can.

`test/app_test.dart` defines four finders, and new tests should use them rather
than reaching for widget types:

- `fieldNamed('Hydration')` — the `TextField` inside a `NumberField`/`NameField`.
  The label is a *sibling* of the box now, not inside its decoration, so
  `find.widgetWithText(TextField, …)` does not reach it.
- `actionBar('Save')` — the pinned primary action.
- `sheetButton('Save')` — a button inside the modal sheet. Scoped, because the
  sheet's confirm button and the `ActionBar` behind it carry the same word.
- `openRecipesTab(tester)`.

`NumberField` keeps a real `TextField` inside it rather than rebuilding on
`EditableText` — that is what preserves text selection, context menus and
autofill, and it is not worth trading away for a custom caret.

### Library mutations are serialised

`LibraryController` reads-modifies-writes the whole recipe list. Two overlapping
mutations would both read the same starting list and the second would discard
the first, so every mutation goes through `_serialised()`, and `_ready()` waits
for the first load before writing — saving from the calculator routinely beats
the file read.

### Theme

The design is **soft and tonal**: filled surfaces, generous radii, no rules,
no shadows and no `surfaceTint` anywhere. Containers are told apart by their
**fill**, not by a border — the page is a slightly grey ground, a panel is the
lighter surface sitting on it, and a field is a slightly darker fill inside the
panel, the way a grouped iOS list or a Material 3 filled card works. That is why
`surface` is `0xFFF2F2F7` and not white: panels are white and have to sit on
something.

Radii come from [lib/core/theme/spacing.dart](lib/core/theme/spacing.dart) —
`card` 20, `field` 14, `chip` 12, and `pill` for anything that reads as a control
in its own right. `Radii.pill` is 999 and relies on Flutter scaling a radius down
to fit the box, so it works on any height. Spacing is 4/8 dp only, plus
`pagePadding(context)`, which every full-screen scroll uses. `Borders` has just
`hair` and `focus`: a border is the exception here, for a divider or for the one
control holding the keyboard.

Blue carries action and selection, a warm amber carries the result, and red and
amber stay reserved for the two states that warn. Every accent has a *container*
pair — a pale tint in light and a deep one in dark — because tonal containers are
the point of this look: a filled block should belong to the surface it sits on
rather than punch through it. `colorScheme.outline` is a mid grey used only where
a control genuinely needs an edge; `outlineVariant` draws hairline dividers.

Earlier looks that were built and rejected: warm artisan/terracotta (the user's
call), an emerald "instrument" palette, and a hard-edged Bauhaus one with 2 dp
ink rules and uppercase labels. Do not reintroduce any of them as a "fix" —
in particular, do not put borders back on containers.

`colorScheme.primary` and `BakingColors.proof` are deliberately the same blue:
dough being ready *is* the brand, so "ready" and "accent" are one colour. They
stay separate names so a future change can split them again.

`BakingColors.proofContainer` is the totals block, and only **two** foregrounds
are drawn on it — `onProofContainer` for the total and `onProofContainerMuted`
for the labels. Both are their own tokens because `onSurface` and
`onSurfaceVariant` are tuned against the page rather than against a warm amber
fill and miss AA on it. `warn` and `proof` are deliberately kept *off* the block:
the dough-temp advisory sits below it, where it reads better anyway. A third
foreground needs a new token and a line in the contrast test, not a `copyWith`
at the call site.

Every colour comes from `Theme.of(context).colorScheme` or the `BakingColors`
theme extension ([lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart)).
No widget hardcodes a hex value.

Three faces. **Plus Jakarta Sans** (variable) is the display face for everything
`titleMedium` and above, at 600–700 with slight negative tracking. **IBM Plex
Sans** (variable) for body and labels. **IBM Plex Mono** for every gram,
percentage and clock time — applied *only* through `numeric(style)`, which sets
the family and `tabularFigures` together and clamps the weight into the
400/500/600/700 that `pubspec.yaml` registers. Mono has no variable cut, so the
clamp is what keeps the display scale free to go heavier without a number that
borrows one of its styles being synthesised into a fake bold. Never reach for
`numericFont` or `tabularFigures` directly.

Nothing is uppercased. Headings are told from body text by size, weight and
colour — `SectionLabel` in [lib/ui/widgets/panel.dart](lib/ui/widgets/panel.dart)
is the section heading, and it sets `Semantics(header: true)` so the structure
still reaches a screen reader.

`test/theme_contrast_test.dart` re-measures every ratio the palette claims in
its comments — AA (4.5:1) for text on all three surfaces, and 3:1 for
`outline`, which draws the boundary of controls the baker operates.
`outlineVariant` is exempt: panel dividers only. It also asserts the `numeric()`
clamp, that the two faces land on the styles they are meant to, and that the
tonal containers really do differ between the modes.

### Material 3 is the substrate, not the look

`MaterialApp`, `Scaffold`, routing, both platform pickers, `AlertDialog`,
`showModalBottomSheet`, `SnackBar`, `ListTile`, `Chip` and `PopupMenuButton` all
stay Material and are covered by `ThemeData` sub-themes. What was replaced is
only the handful of widgets that *read* as Material, and each lives in
[lib/ui/widgets/](lib/ui/widgets/):

| Widget | Replaced |
|---|---|
| `Panel` / `DisclosurePanel` | `Card`, `ExpansionTile` |
| `StyleToggle` | `SegmentedButton` (a sliding thumb instead of a checkmark) |
| `AppNavBar` | `NavigationBar` / `NavigationRail` (the pill indicator) |
| `ActionBar` | `FloatingActionButton.extended` |
| `NumberField` / `NameField` | the floating-label `InputDecoration` |

`Panel` is a `Material`, not a `DecoratedBox` — a `ListTile` or `InkWell` inside
it paints ink on the nearest `Material` ancestor, so a plain coloured box both
hides that ink and lets it bleed past the panel's rounded edge.

Do **not** go further and drop `package:flutter/material.dart` for `WidgetsApp`:
that means hand-rebuilding both pickers, dialogs, sheets, menus, nine snackbar
sites, text-selection toolbars and autofill, for no visible gain over what is
already here.

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
