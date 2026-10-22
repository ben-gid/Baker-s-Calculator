import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_input.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/action_bar.dart';
import '../widgets/motion.dart';
import '../widgets/number_field.dart';
import '../widgets/starter_jar.dart';
import '../widgets/style_toggle.dart';
import 'dough_form.dart';

/// The dough being built. It rises over Home as a sheet while Home's jar flies
/// into the header, where it keeps filling to the dough's hydration as you
/// type; the total sits beside it and rolls as it changes.
///
/// One form, top to bottom: the style, the weight one loaf starts from, then
/// the percentages. "See recipe" opens the result over it — the jar flies on
/// into its bigger header there — and the loaf count lives on that page. It
/// starts blank: every box shows a typical range in grey instead of a number
/// nobody chose, and the Template menu fills the form from a built-in or saved
/// recipe.
class CalculatorPage extends ConsumerStatefulWidget {
  const CalculatorPage({super.key});

  @override
  ConsumerState<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends ConsumerState<CalculatorPage> {
  /// Bumped whenever a template replaces the whole dough, so the form starts
  /// over too — otherwise an empty Fat box the baker had opened would linger
  /// into a recipe that has no fat.
  int _generation = 0;

  /// No toast and no Undo: a template is two deliberate taps away, it fills
  /// the form in front of the baker, and Blank is always there to start over.
  void _useTemplate(String id) {
    final controller = ref.read(calculatorProvider.notifier);
    final template = id == _TemplateMenu.blank
        ? null
        : ref.read(libraryProvider.notifier).byId(id);

    if (template == null) {
      controller.reset();
    } else {
      controller.load(template.input);
    }
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(calculatorProvider);
    final issues = ref.watch(issuesProvider);
    final recipe = ref.watch(calculationProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(calculatorProvider.notifier);

    final header = _Header(
      input: input,
      recipe: recipe,
      issues: issues,
      unit: settings.unit,
    );
    final sheet = _Sheet(
      child: _Scroll(
        children: [
          RiseIn(
            delay: const Duration(milliseconds: 140),
            child: _Basics(input: input, unit: settings.unit),
          ),
          const SizedBox(height: Insets.md),
          RiseIn(
            delay: const Duration(milliseconds: 200),
            child: DoughForm(
              key: ValueKey(_generation),
              input: input,
              issues: issues,
              onChanged: controller.load,
            ),
          ),
        ],
      ),
    );

    // It came up as a sheet, so it goes back down: the back button points that
    // way. Still a BackButton underneath, for the platform and for tests.
    return ActionIconTheme(
      data: ActionIconThemeData(
        backButtonIconBuilder: (context) =>
            const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New dough'),
          actions: [
            _TemplateMenu(onSelected: _useTemplate),
            const SizedBox(width: Insets.xs),
          ],
        ),
        bottomNavigationBar: ActionBar(
          label: 'See recipe',
          icon: Icons.arrow_forward_rounded,
          onPressed: recipe == null
              ? null
              : () => context.go('/calculate/recipe'),
        ),
        body: SafeArea(
          bottom: false,
          child: MediaQuery.sizeOf(context).width >= Breakpoints.tablet
              // Wide screens keep the jar beside the form, so it never
              // scrolls away.
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Scroll(children: [header])),
                    Expanded(child: sheet),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        pageMargin(MediaQuery.sizeOf(context).width),
                        Insets.xs,
                        pageMargin(MediaQuery.sizeOf(context).width),
                        Insets.lg,
                      ),
                      child: header,
                    ),
                    Expanded(child: sheet),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The white sheet the recipe sits on. It rides the route's own animation up
/// from the bottom edge, so it arrives in step with the jar's flight.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.animation;
    final sheet = Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Radii.card + 8),
      ),
      child: child,
    );
    if (route == null || MediaQuery.disableAnimationsOf(context)) return sheet;
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: route,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      ),
      child: sheet,
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: pagePadding(context, top: Insets.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// The jar and the answer. Once the recipe works: the total, rolling as it
/// changes, over the dough's true hydration and what each loaf weighs. Until
/// then: what it still needs, and anything that blocks it.
class _Header extends StatelessWidget {
  const _Header({
    required this.input,
    required this.recipe,
    required this.issues,
    required this.unit,
  });

  final RecipeInput input;
  final Recipe? recipe;
  final List<InputIssue> issues;
  final MassUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = this.recipe;
    final hydration = recipe?.hydration ?? input.hydration;
    final errors = issues.where((i) => i.severity == IssueSeverity.error);
    final missing = [for (final e in errors) ?e.missing?.toLowerCase()];

    final List<Widget> answer;
    if (recipe != null) {
      answer = [
        Text(
          'Total dough',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        RollingText(
          formatMass(recipe.totalWeight, unit),
          style: numeric(theme.textTheme.displaySmall),
        ),
        const SizedBox(height: Insets.xs),
        RollingText(
          [
            '${formatPercent(recipe.hydration)} hydration',
            recipe.loaves > 1
                ? 'Each ${formatMass(recipe.weightPerLoaf, unit)}'
                : 'Flour ${formatMass(recipe.totalFlour, unit)}',
          ].join(' · '),
          style: numeric(theme.textTheme.bodyMedium),
        ),
      ];
    } else {
      answer = [
        if (missing.isNotEmpty)
          Text(
            'Needs ${_sentence(missing)}',
            style: theme.textTheme.titleMedium,
          ),
        for (final error in errors.where((e) => e.missing == null))
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              error.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ];
    }

    return Row(
      children: [
        Hero(
          tag: jarHeroTag,
          child: SizedBox(
            width: 76,
            height: 98,
            child: StarterJar(
              level: jarLevelFor(hydration),
              fizz: input.style == DoughStyle.classic ? 0.35 : 0.7,
            ),
          ),
        ),
        const SizedBox(width: Insets.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: answer,
          ),
        ),
      ],
    );
  }
}

/// Blank, the built-in recipes, then the baker's own.
class _TemplateMenu extends ConsumerWidget {
  const _TemplateMenu({required this.onSelected});

  final ValueChanged<String> onSelected;

  /// Not a recipe id — those are generated, and never this.
  static const blank = '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider).value;

    PopupMenuEntry<String> heading(String text) => PopupMenuItem(
      enabled: false,
      height: Insets.xl,
      child: Text(text, style: theme.textTheme.labelSmall),
    );

    return PopupMenuButton<String>(
      tooltip: 'Start from a template',
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(value: blank, child: Text('Blank')),
        if (library != null && library.system.isNotEmpty) ...[
          heading('Built in'),
          for (final recipe in library.system)
            PopupMenuItem(value: recipe.id, child: Text(recipe.name)),
        ],
        if (library != null && library.saved.isNotEmpty) ...[
          heading('Your recipes'),
          for (final recipe in library.saved)
            PopupMenuItem(value: recipe.id, child: Text(recipe.name)),
        ],
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Template',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// The top of the form: the style, then the weight one loaf starts from, in
/// the column of boxes, with flour or finished dough switched beside it. The weight is
/// typed in the unit Settings chose and kept in grams, which is all the engine
/// knows.
class _Basics extends ConsumerWidget {
  const _Basics({required this.input, required this.unit});

  final RecipeInput input;
  final MassUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(calculatorProvider.notifier);
    final forward = input.solvesForward;
    final weight = forward ? input.flourWeight : input.totalDoughWeight;
    final ounces = unit == MassUnit.ounces;

    void setWeight(double? typed) {
      final grams = typed == null ? null : toGrams(typed, unit);
      controller.change(
        (i) => forward
            ? i.copyWith(flourWeight: grams)
            : i.copyWith(totalDoughWeight: grams),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StyleToggle<DoughStyle>(
          options: [
            for (final option in DoughStyle.values)
              ToggleOption(value: option, label: option.label),
          ],
          selected: input.style,
          onChanged: (style) {
            HapticFeedback.selectionClick();
            controller.setStyle(style);
          },
        ),
        const SizedBox(height: Insets.sm),
        // The weight in the column of boxes, and what it weighs — flour or
        // the finished dough — switched where the other rows have a name.
        Row(
          children: [
            SizedBox(
              width: fieldBoxWidth,
              // One box for whichever weight is driving, so the form never
              // holds a number the recipe is not reading.
              child: NumberField(
                key: ValueKey(forward),
                label: forward ? 'Flour weight' : 'Dough weight',
                showLabel: false,
                dense: true,
                hint: switch ((forward, ounces)) {
                  (true, false) => '400–600',
                  (true, true) => '14–21',
                  (false, false) => '700–1000',
                  (false, true) => '25–35',
                },
                suffix: unit.symbol,
                value: weight == null ? null : fromGrams(weight, unit),
                onChanged: setWeight,
              ),
            ),
            const SizedBox(width: Insets.md),
            SizedBox(
              width: 148,
              child: StyleToggle<bool>(
                compact: true,
                options: const [
                  ToggleOption(value: true, label: 'Flour'),
                  ToggleOption(value: false, label: 'Dough'),
                ],
                selected: forward,
                onChanged: controller.setByFlourWeight,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        Padding(
          padding: const EdgeInsets.only(left: Insets.xs),
          child: Text(
            'For one loaf. How many is on the recipe.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// `salt`, `salt and yeast`, `hydration, salt and yeast`.
String _sentence(List<String> items) => items.length == 1
    ? items.single
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
