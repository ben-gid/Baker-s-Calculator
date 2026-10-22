import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_input.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/motion.dart';
import '../widgets/number_field.dart';
import '../widgets/recipe_table.dart';
import '../widgets/starter_jar.dart';
import '../widgets/style_toggle.dart';
import 'save_recipe_sheet.dart';

/// The dough being built. It rises over Home as a sheet while Home's jar flies
/// into the header, where it keeps filling to the dough's hydration as you
/// type; the totals sit beside it and roll as they change.
///
/// It starts blank. Every box shows a typical range in grey instead of a
/// number nobody chose, and the Template menu loads a built-in or saved recipe
/// for anyone who wants a starting point. Only the rows the style needs show;
/// fat, sugar, eggs, blends and mix-ins wait behind "Add ingredient".
class CalculatorPage extends ConsumerStatefulWidget {
  const CalculatorPage({super.key});

  @override
  ConsumerState<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends ConsumerState<CalculatorPage> {
  /// Bumped whenever a template replaces the whole dough, so the table starts
  /// over too — otherwise an empty Fat row the baker had opened would linger
  /// into a recipe that has no fat.
  int _generation = 0;

  void _useTemplate(String id) {
    final controller = ref.read(calculatorProvider.notifier);
    final previous = ref.read(calculatorProvider);
    final template = id == _TemplateMenu.blank
        ? null
        : ref.read(libraryProvider.notifier).byId(id);

    if (template == null) {
      controller.reset();
    } else {
      controller.load(template.input);
    }
    setState(() => _generation++);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            template == null
                ? 'Cleared the dough'
                : 'Loaded "${template.name}"',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              controller.load(previous);
              if (mounted) setState(() => _generation++);
            },
          ),
        ),
      );
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
    final controls = _Controls(
      key: ValueKey(_generation),
      input: input,
      issues: issues,
    );
    final table = RecipeTable(
      key: ValueKey(_generation),
      input: input,
      recipe: recipe,
      unit: settings.unit,
      issues: issues,
      onChanged: controller.load,
    );
    final warnings = _Warnings(issues: issues);

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
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Save',
              onPressed: recipe == null
                  ? null
                  : () => showSaveRecipeSheet(context, ref, input),
            ),
            const SizedBox(width: Insets.xs),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: MediaQuery.sizeOf(context).width >= Breakpoints.tablet
              // Wide screens put the jar and the batch beside the table, so
              // nothing is ever below anything else.
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Scroll(
                        children: [
                          header,
                          const SizedBox(height: Insets.xl),
                          controls,
                        ],
                      ),
                    ),
                    Expanded(
                      child: _Sheet(
                        child: _Scroll(children: [table, warnings]),
                      ),
                    ),
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
                    Expanded(
                      child: _Sheet(
                        child: _Scroll(
                          children: [
                            RiseIn(
                              delay: const Duration(milliseconds: 140),
                              child: controls,
                            ),
                            const SizedBox(height: Insets.md),
                            RiseIn(
                              delay: const Duration(milliseconds: 200),
                              child: table,
                            ),
                            warnings,
                          ],
                        ),
                      ),
                    ),
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

/// Advice under the table. Never blocks, never takes the totals' place.
class _Warnings extends StatelessWidget {
  const _Warnings({required this.issues});

  final List<InputIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final warning in issues.where(
          (i) => i.severity == IssueSeverity.warning,
        ))
          Padding(
            padding: const EdgeInsets.only(top: Insets.sm, left: Insets.xs),
            child: Text(
              warning.message,
              style: theme.textTheme.bodySmall?.copyWith(color: baking.warn),
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

/// The style, then the batch: which weight drives it and how many loaves. The
/// batch folds to one line once it has a weight — "500 g flour · 1 loaf" — and
/// opens on a tap. A new dough starts with it open, since that is the first
/// thing to type. Grams or ounces is a Settings choice, not something to flip
/// mid-recipe.
class _Controls extends ConsumerStatefulWidget {
  const _Controls({super.key, required this.input, required this.issues});

  final RecipeInput input;
  final List<InputIssue> issues;

  @override
  ConsumerState<_Controls> createState() => _ControlsState();
}

class _ControlsState extends ConsumerState<_Controls> {
  late bool _open = _weight == null;

  double? get _weight => widget.input.solvesForward
      ? widget.input.flourWeight
      : widget.input.totalDoughWeight;

  void _setLoaves(int loaves) {
    HapticFeedback.selectionClick();
    ref
        .read(calculatorProvider.notifier)
        .change((i) => i.copyWith(loaves: loaves));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final controller = ref.read(calculatorProvider.notifier);
    final input = widget.input;
    final issues = widget.issues;
    final forward = input.solvesForward;
    final weight = _weight;
    final loaves = '${input.loaves} ${input.loaves == 1 ? 'loaf' : 'loaves'}';
    final still = MediaQuery.disableAnimationsOf(context);
    final Widget batch = !_open
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.md,
            ),
            child: Column(
              children: [
                Row(
                  children: [
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
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      // One box for whichever weight is driving, so
                      // the row never holds a number the recipe is
                      // not reading.
                      child: forward
                          ? NumberField(
                              label: 'Flour weight',
                              showLabel: false,
                              dense: true,
                              hint: '400–600',
                              suffix: 'g',
                              value: input.flourWeight,
                              issue: issues.firstFor(RecipeField.flourWeight),
                              onChanged: (v) => controller.change(
                                (i) => i.copyWith(flourWeight: v),
                              ),
                            )
                          : NumberField(
                              label: 'Dough weight',
                              showLabel: false,
                              dense: true,
                              hint: '700–1000',
                              suffix: 'g',
                              value: input.totalDoughWeight,
                              issue: issues.firstFor(
                                RecipeField.totalDoughWeight,
                              ),
                              onChanged: (v) => controller.change(
                                (i) => i.copyWith(totalDoughWeight: v),
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                Row(
                  children: [
                    // Expanded rather than Spacer: at narrow widths
                    // the label has to give way to the stepper.
                    Expanded(
                      child: Text('Loaves', style: theme.textTheme.bodyMedium),
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.remove),
                      tooltip: 'One fewer loaf',
                      onPressed: input.loaves <= 1
                          ? null
                          : () => _setLoaves(input.loaves - 1),
                    ),
                    SizedBox(
                      width: 40,
                      child: RollingText(
                        '${input.loaves}',
                        textAlign: TextAlign.center,
                        style: numeric(theme.textTheme.titleLarge),
                      ),
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.add),
                      tooltip: 'One more loaf',
                      onPressed: () => _setLoaves(input.loaves + 1),
                    ),
                  ],
                ),
              ],
            ),
          );
    final summary = weight == null
        ? 'Set the batch'
        : '${formatMass(weight, ref.watch(settingsProvider).unit)} '
              '${forward ? 'flour' : 'dough'} · $loaves';

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
        const SizedBox(height: Insets.md),
        // The page tone, so the weight box's own fill still reads inside it.
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(Radii.field),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: const Key('batch'),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.scale_outlined,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          summary,
                          style: numeric(theme.textTheme.titleSmall),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Zero-length AnimatedSize trips over itself, so reduced motion
              // simply swaps the panel in.
              if (still)
                batch
              else
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: batch,
                ),
            ],
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
