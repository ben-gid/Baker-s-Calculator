import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_input.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/number_field.dart';
import '../widgets/panel.dart';
import '../widgets/recipe_table.dart';
import '../widgets/style_toggle.dart';
import 'save_recipe_sheet.dart';

/// One screen, sized to fit a phone: the style, the batch, and the recipe as a
/// single table whose weights fill in beside the percentages as you type.
///
/// It starts blank. Every box shows a typical range in grey instead of a
/// number nobody chose, and the Template menu loads a built-in or saved recipe
/// for anyone who wants a starting point.
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

    final controls = _Controls(input: input, issues: issues);
    final table = RecipeTable(
      key: ValueKey(_generation),
      input: input,
      recipe: recipe,
      unit: settings.unit,
      issues: issues,
      onChanged: controller.load,
    );
    final result = _Result(recipe: recipe, issues: issues, unit: settings.unit);

    return Scaffold(
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
        child: MediaQuery.sizeOf(context).width >= Breakpoints.tablet
            // Wide screens put the table beside the batch and the totals, so
            // nothing is ever below anything else.
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _Scroll(children: [table])),
                  Expanded(
                    child: _Scroll(
                      children: [
                        controls,
                        const SizedBox(height: Insets.md),
                        result,
                      ],
                    ),
                  ),
                ],
              )
            : _Scroll(
                children: [
                  controls,
                  const SizedBox(height: Insets.md),
                  table,
                  const SizedBox(height: Insets.md),
                  result,
                ],
              ),
      ),
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: pagePadding(context, top: Insets.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
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

/// Style, which weight drives the batch, and how many loaves. Grams or ounces
/// is a Settings choice, not something to flip mid-recipe.
class _Controls extends ConsumerWidget {
  const _Controls({required this.input, required this.issues});

  final RecipeInput input;
  final List<InputIssue> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);
    final forward = input.solvesForward;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StyleToggle<DoughStyle>(
          options: [
            for (final option in DoughStyle.values)
              ToggleOption(value: option, label: option.label),
          ],
          selected: input.style,
          onChanged: controller.setStyle,
        ),
        const SizedBox(height: Insets.md),
        Panel(
          padding: const EdgeInsets.all(Insets.md),
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
                  // One box for whichever weight is driving, so the row
                  // never holds a number the recipe is not reading.
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
                          issue: issues.firstFor(RecipeField.totalDoughWeight),
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
                // Expanded rather than Spacer: at narrow widths the label has
                // to give way to the stepper, not push it off the panel.
                Expanded(
                  child: Text(
                    'Loaves',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  tooltip: 'One fewer loaf',
                  onPressed: input.loaves <= 1
                      ? null
                      : () => controller.change(
                          (i) => i.copyWith(loaves: i.loaves - 1),
                        ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${input.loaves}',
                    textAlign: TextAlign.center,
                    style: numeric(Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  tooltip: 'One more loaf',
                  onPressed: () => controller.change(
                    (i) => i.copyWith(loaves: i.loaves + 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The totals once the recipe works; until then, what it still needs. Warnings
/// sit underneath either way — they are advice and never take the totals'
/// place.
class _Result extends StatelessWidget {
  const _Result({
    required this.recipe,
    required this.issues,
    required this.unit,
  });

  final Recipe? recipe;
  final List<InputIssue> issues;
  final MassUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    final recipe = this.recipe;
    final errors = issues.where((i) => i.severity == IssueSeverity.error);
    final missing = [for (final e in errors) ?e.missing?.toLowerCase()];
    final warnings = issues.where((i) => i.severity == IssueSeverity.warning);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recipe != null)
          TotalsPanel(recipe: recipe, unit: unit)
        else
          Panel(
            children: [
              if (missing.isNotEmpty)
                Text(
                  'Needs ${_sentence(missing)}',
                  style: theme.textTheme.bodyMedium,
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
            ],
          ),
        for (final warning in warnings)
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

/// `salt`, `salt and yeast`, `hydration, salt and yeast`.
String _sentence(List<String> items) => items.length == 1
    ? items.single
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
