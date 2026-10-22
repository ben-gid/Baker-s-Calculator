import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/models/recipe.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/action_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/loaf_stepper.dart';
import '../widgets/motion.dart';
import '../widgets/panel.dart';
import '../widgets/recipe_table.dart';
import '../widgets/starter_jar.dart';
import 'save_recipe_sheet.dart';

/// The dough the form describes, laid out to weigh. The calculator's jar flies
/// up into the big header here, beside the numbers a baker reads first; under
/// it, how many loaves, then the table. Back returns to the form with
/// everything still typed in, and Save keeps it.
class DoughResultPage extends ConsumerWidget {
  const DoughResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(calculatorProvider);
    final issues = ref.watch(issuesProvider);
    final recipe = ref.watch(calculationProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(calculatorProvider.notifier);

    // Only reachable by link before the form works; there is nothing to weigh.
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.edit_note,
          title: 'Nothing to weigh yet',
          message: 'Fill in the dough first.',
          actionLabel: 'Back to the dough',
          onAction: () => context.go('/calculate'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your recipe'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: ActionBar(
        secondaryLabel: 'Back',
        onSecondary: () => context.pop(),
        label: 'Save',
        icon: Icons.bookmark_add_outlined,
        onPressed: () => showSaveRecipeSheet(context, ref, input),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                recipe: recipe,
                fizz: input.style == DoughStyle.classic ? 0.35 : 0.7,
                unit: settings.unit,
              ),
              const SizedBox(height: Insets.xl),
              RiseIn(
                delay: const Duration(milliseconds: 140),
                child: Panel(
                  children: [
                    LoafStepper(
                      loaves: input.loaves,
                      onChanged: (loaves) =>
                          controller.change((i) => i.copyWith(loaves: loaves)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
              RiseIn(
                delay: const Duration(milliseconds: 200),
                child: RecipeTable(
                  input: input,
                  recipe: recipe,
                  unit: settings.unit,
                  showBakersPercent: settings.showBakersPercent,
                ),
              ),
              _Warnings(issues: issues),
            ],
          ),
        ),
      ),
    );
  }
}

/// The calculator's header, grown: a bigger jar, the total, and the facts that
/// used to sit in a panel of their own — flour, water, the dough's true
/// hydration and, for a batch, what each loaf weighs.
class _Header extends StatelessWidget {
  const _Header({required this.recipe, required this.fizz, required this.unit});

  final Recipe recipe;
  final double fizz;
  final MassUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Hero(
          tag: jarHeroTag,
          child: SizedBox(
            width: 112,
            height: 146,
            child: StarterJar(level: jarLevelFor(recipe.hydration), fizz: fizz),
          ),
        ),
        const SizedBox(width: Insets.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total dough', style: muted),
              RollingText(
                formatMass(recipe.totalWeight, unit),
                style: numeric(theme.textTheme.displaySmall),
              ),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.lg,
                runSpacing: Insets.xs,
                children: [
                  _Fact('Flour', formatMass(recipe.totalFlour, unit)),
                  _Fact('Water', formatMass(recipe.totalWater, unit)),
                  // "Total", because it counts the flour and water a levain
                  // carries in and so reads a little above the typed figure.
                  _Fact('Total hydration', formatPercent(recipe.hydration)),
                  if (recipe.loaves > 1)
                    _Fact('Each', formatMass(recipe.weightPerLoaf, unit)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        RollingText(value, style: numeric(theme.textTheme.titleSmall)),
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
