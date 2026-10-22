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
function to `domain/` and test it there. The calculator's table is the example:
it shows `recipe.gramsAt(typedPercent)` beside each box, and
`Recipe.doughFlour`, `leaven` and `eggs` exist so it never matches rows by name;
the `table reads the same grams as the groups` test holds that to the groups.

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
A new dough starts that way: `startingPoint` is blank (it nulls `hydration`
and `salt` explicitly, because `RecipeInput`'s constructor defaults them for old
JSON), and `setStyle` / `setByFlourWeight` never fill anything in. Numbers come
only from the baker or from the Template menu. An empty box is reported as
`InputIssue.missing`, which the calculator gathers into one "Needs …" line, and
`NumberField` deliberately does not outline it red — a blank dough would
otherwise be a page of errors.
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

`test/app_test.dart` defines these helpers, and new tests should use them
rather than reaching for widget types:

- `fieldNamed('Hydration')` — the `TextField` inside a `NumberField`/`NameField`,
  matched on its `label`. Table cells hide the printed label (`showLabel:
  false`) but keep it, so the finder still works; the Water row's box is
  labelled `Hydration`, a blend's boxes `Flour 1` and `Flour 1 share`.
- `actionBar('Plan this bake')` — the pinned primary action. The calculator's
  Save is an app-bar icon instead: `find.byTooltip('Save')`.
- `sheetButton('Save')` — a button inside the modal sheet. Scoped, because the
  sheet's confirm button and the `ActionBar` behind it carry the same word.
- `openNewDough(tester)` and `fillClassic(tester)` — the app boots onto Home and
  the calculator starts blank, so a test that needs a recipe types one: 500 g
  flour at 70/2/1, an 865 g classic loaf.
- `openRecipesTab(tester)` — the full library, behind the shelf's "See all" on
  Home. There are no tabs, so from anywhere else back out to Home first.

**Widget tests run with reduced motion.** The jar is alive for as long as it is
on screen, so `pumpAndSettle` would never settle; `usePhoneScreen` (and the
wide-screen test) call `reduceMotion(tester)`, which the jar, `RiseIn`,
`RollingText` and the batch line all honour. The one test that leaves motion on
pumps frames by time instead. A new test that pumps the app itself must call
`reduceMotion` too.

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

The look is **Starter Jar**: soft and organic, with fermentation as the hero —
chosen by the user from the design system's directions, in light and dark on
Settings' System / Light / Dark switch. A pale glass-sage page in light and a
deep forest one in dark; white (or slightly raised) panels; deep sage, or light
sage in dark, for action and selection; a honey-yellow starter for the answer.

It is still filled and tonal: no rules, no shadows and no `surfaceTint`.
Containers are told apart by their **fill**, not by a border — the page is a
tinted ground, a panel is the lighter surface on it, and a field is a darker
fill inside the panel. The calculator's recipe sits on a white sheet, so its
table panel is the sheet's own colour and only the fields show; the batch line
uses the page tone so its weight box still reads inside it.

Radii come from [lib/core/theme/spacing.dart](lib/core/theme/spacing.dart) —
`card` 24, `field` 16, `chip` 16, and `pill` for anything that reads as a
control in its own right. `Radii.pill` is 999 and relies on Flutter scaling a
radius down to fit the box. Spacing is 4/8 dp only, plus `pagePadding(context)`,
which every full-screen scroll uses. `Borders` has just `hair` and `focus`.

`colorScheme.primary` and `BakingColors.proof` are deliberately the same sage:
dough being ready *is* the brand. They stay separate names so a future change
can split them again.

`BakingColors.proofContainer` is the totals block (pale starter yellow in
light, deep honey in dark), and only **two** foregrounds are drawn on it —
`onProofContainer` and `onProofContainerMuted`. A third needs a new token and a
line in the contrast test. `starter`, `starterDeep` and `bubble` are the jar's
paint and nothing else: no text is ever drawn on the liquid, so they carry no
contrast promise.

Every colour comes from `Theme.of(context).colorScheme` or the `BakingColors`
theme extension ([lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart)).
No widget hardcodes a hex value — the shader takes its colours as uniforms.

**One face: Nunito** (variable, wght 200–1000), for headings, body and every
number. Its digits are all one width by design, so columns of grams line up
without a monospace face; `numeric(style)` still marks every measurement and
pins the weight variation, so a figures face would have one place to land.
Every text style names the family itself rather than relying on
`ThemeData.fontFamily`, because the button themes take their styles before
`ThemeData` applies it and would otherwise fall back to the platform font.

Nothing is uppercased. Headings are told from body text by size, weight and
colour — `SectionLabel` in [lib/ui/widgets/panel.dart](lib/ui/widgets/panel.dart)
is the section heading, and it sets `Semantics(header: true)`.

`test/theme_contrast_test.dart` re-measures every ratio the palette claims —
AA (4.5:1) for text on all three surfaces, 3:1 for `outline` — and asserts that
every style is set in Nunito at a weight its variation agrees with, and that the
tonal containers differ between the modes.

### The jar and motion

[lib/ui/widgets/starter_jar.dart](lib/ui/widgets/starter_jar.dart) is the app's
one living visual: a fragment shader
([shaders/starter_jar.frag](shaders/starter_jar.frag), registered under
`flutter: shaders:`) draws the glass, lid, a waving surface, rising bubbles and
a glass highlight. The widget eases `level` and `dome` to new values and feeds
the shader the time; uniform order in the `.frag` and the `setFloat` calls must
stay in step. A painted still jar stands in while the shader loads. The ticker
only runs while the jar's route is showing, and stops under reduced motion.

What the jar means is decided by its screen, never inside it. Home: a bake under
way rises with `ActiveBake.riseAt(now)` (fermenting time elapsed, domes when
ready); otherwise the dough being built fills to its hydration; otherwise an
empty jar. The calculator's header jar fills to the hydration as you type. Home's
jar and the calculator's share `jarHeroTag`, so one flies into the other.

Motion is spent on the jar and on moving between places; cards, lists and text
stay still. The vocabulary in [lib/ui/widgets/motion.dart](lib/ui/widgets/motion.dart)
is `RiseIn` (a section drifts up as it fades in, with a short stagger) and
`RollingText` (a changed total rolls up into place). Everything honours
`MediaQuery.disableAnimationsOf`. Do not add motion elsewhere without a reason
the baker would notice.

### Material 3 is the substrate, not the look

`MaterialApp`, `Scaffold`, routing, both platform pickers, `AlertDialog`,
`showModalBottomSheet`, `SnackBar`, `ListTile`, `Chip` and `PopupMenuButton` all
stay Material and are covered by `ThemeData` sub-themes. What was replaced is
only the handful of widgets that *read* as Material, and each lives in
[lib/ui/widgets/](lib/ui/widgets/):

| Widget | Replaced |
|---|---|
| `Panel` | `Card` |
| `RecipeTable` / `RecipeSummary` | the form *and* the result — one table, editable in the calculator, read-only everywhere else |
| `StyleToggle` | `SegmentedButton` (a sliding thumb instead of a checkmark) |
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

One `go_router` stack and **no tab bar**. Home (`/`) is the hub: the jar, the
New dough button and a horizontal recipe shelf whose "See all" opens the
library (`/recipes`). The calculator (`/calculate`) and the library are children
of `/`, so `context.go` to either keeps Home underneath, and backing out lands
there. The calculator has its own transition: the page fades while its sheet
rises on the route's animation and the jar flies into its header.
`/recipe/:id`, `/recipe/:id/plan`, `/import`, `/suggest` and `/settings` are
top-level so a shared link opens straight onto content.

Tools live where they are used, not on a screen of their own. Suggest and
Import sit on the empty jar until the baker has saved a recipe, then at the end
of the shelf — one place at a time. The dough-temperature card is at the foot
of the bake plan.

The calculator shows only the rows its style needs; fat, sugar, eggs, blends
and mix-ins wait behind "Add ingredient". The batch (which weight drives it, and
how many loaves) folds to one line — "500 g flour · 1 loaf" — once it has a
weight, and opens on a tap; a new dough starts with it open. Tests reach it with
`find.byKey(const Key('batch'))`.

"Start bake" saves an `ActiveBake` (the schedule exactly as started, edited
durations included) to `SharedPreferences` through `SettingsRepository`, and
Home's jar reads it. It is recorded even when notification permission is
refused, and "Stop bake" clears it and cancels the reminders.
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
