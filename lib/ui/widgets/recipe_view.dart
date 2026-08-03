import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/recipe.dart';
import 'section_card.dart';

/// The calculated recipe: one card per group, one row per ingredient.
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
          SectionCard(
            title: group.name,
            note: group.note,
            trailing: Text(
              formatMass(group.grams, unit),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFeatures: tabularFigures,
              ),
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
        _TotalsCard(recipe: recipe, unit: unit),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  primary,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFeatures: tabularFigures,
                  ),
                ),
                if (secondary != null)
                  Text(
                    secondary,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFeatures: tabularFigures,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.recipe, required this.unit});

  final Recipe recipe;
  final MassUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;

    return Card(
      color: baking.proofContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: baking.proof.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text('Total dough', style: theme.textTheme.titleMedium),
                ),
                Text(
                  formatMass(recipe.totalWeight, unit),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.lg,
              runSpacing: Insets.xs,
              children: [
                _Stat(
                  label: 'Flour',
                  value: formatMass(recipe.totalFlour, unit),
                ),
                _Stat(
                  label: 'Water',
                  value: formatMass(recipe.totalWater, unit),
                ),
                _Stat(
                  label: 'Hydration',
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
        ),
      ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: theme.textTheme.bodySmall),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}
