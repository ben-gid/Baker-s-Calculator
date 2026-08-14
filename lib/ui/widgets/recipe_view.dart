import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/recipe.dart';
import 'panel.dart';

/// The calculated recipe: one block per group, one row per ingredient, and the
/// totals in the single saturated block in the app.
///
/// Weights use tabular figures so the column stays still while values change
/// as the baker types.
class RecipeView extends StatelessWidget {
  const RecipeView({
    super.key,
    required this.recipe,
    required this.unit,
    this.showBakersPercent = true,
  });

  final Recipe recipe;
  final MassUnit unit;
  final bool showBakersPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in recipe.groups) ...[
          Panel(
            title: group.name,
            trailing: Text(
              formatMass(group.grams, unit),
              style: numeric(Theme.of(context).textTheme.labelMedium),
            ),
            children: [
              for (final ingredient in group.ingredients)
                _IngredientRow(
                  ingredient: ingredient,
                  unit: unit,
                  showBakersPercent: showBakersPercent,
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
        ],
        _TotalsPanel(recipe: recipe, unit: unit),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.unit,
    required this.showBakersPercent,
  });

  final Ingredient ingredient;
  final MassUnit unit;
  final bool showBakersPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = ingredient.count;

    // Eggs are bought by the piece, so lead with the count and show the weight
    // underneath rather than asking anyone to weigh 2.4 eggs.
    final primary = count != null
        ? formatCount(count, 'egg', 'eggs')
        : formatMass(ingredient.grams, unit);
    final secondary = count != null ? formatMass(ingredient.grams, unit) : null;

    return Semantics(
      label: '${ingredient.name}, $primary',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: Borders.hair,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(ingredient.name, style: theme.textTheme.bodyLarge),
            ),
            if (showBakersPercent && ingredient.bakersPercent != null) ...[
              SizedBox(
                width: 64,
                child: Text(
                  formatPercent(ingredient.bakersPercent!),
                  textAlign: TextAlign.right,
                  style: numeric(theme.textTheme.bodySmall),
                ),
              ),
              const SizedBox(width: Insets.md),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(primary, style: numeric(theme.textTheme.titleSmall)),
                if (secondary != null)
                  Text(secondary, style: numeric(theme.textTheme.labelSmall)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The answer. A warm tonal panel, the one place the app raises its voice.
///
/// Only two foregrounds are drawn here — the total and the stat labels — and
/// both come from [BakingColors]. `onSurfaceVariant` is tuned against the page
/// rather than against a warm fill and misses AA on it; see the note in
/// `core/theme/app_theme.dart`.
class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({required this.recipe, required this.unit});

  final Recipe recipe;
  final MassUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;

    return Panel(
      fill: baking.proofContainer,
      children: [
        Text(
          'Total dough',
          style: theme.textTheme.labelLarge?.copyWith(
            color: baking.onProofContainerMuted,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          formatMass(recipe.totalWeight, unit),
          style: numeric(
            theme.textTheme.displaySmall,
          ).copyWith(color: baking.onProofContainer),
        ),
        const SizedBox(height: Insets.md),
        Wrap(
          spacing: Insets.lg,
          runSpacing: Insets.xs,
          children: [
            _Stat(label: 'Flour', value: formatMass(recipe.totalFlour, unit)),
            _Stat(label: 'Water', value: formatMass(recipe.totalWater, unit)),
            // "Total", because it counts the flour and water a levain carries
            // in and so reads a little above the typed figure.
            _Stat(
              label: 'Total hydration',
              value: formatPercent(recipe.hydration),
            ),
            if (recipe.loaves > 1)
              _Stat(
                label: 'Each',
                value: formatMass(recipe.weightPerLoaf, unit),
              ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: baking.onProofContainerMuted,
          ),
        ),
        Text(
          value,
          style: numeric(
            theme.textTheme.labelMedium,
          ).copyWith(color: baking.onProofContainer),
        ),
      ],
    );
  }
}
