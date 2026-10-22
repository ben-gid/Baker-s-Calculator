import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/calculator.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_input.dart';
import 'panel.dart';

/// The recipe as one table: ingredient, baker's percentage, weight.
///
/// Read-only, so a recipe looks the same wherever it appears — the
/// calculator's last step, a recipe's page, the wizard and an import. The
/// calculator types into `DoughForm` instead.
///
/// Weights come from [recipe], which is null while the input is blocked. Every
/// weight then reads "—" rather than the rows disappearing.
class RecipeTable extends StatelessWidget {
  const RecipeTable({
    super.key,
    required this.input,
    required this.recipe,
    required this.unit,
    this.showBakersPercent = true,
  });

  final RecipeInput input;
  final Recipe? recipe;
  final MassUnit unit;
  final bool showBakersPercent;

  double? _grams(double? percent) =>
      percent == null ? null : recipe?.gramsAt(percent);

  @override
  Widget build(BuildContext context) {
    final input = this.input;
    final enrichment = input.enrichmentOrEmpty;

    return Panel(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      children: [
        _line(context, name: 'Flour', percent: 100, grams: recipe?.doughFlour),
        for (final part in input.flourBlend)
          _line(
            context,
            name: part.name,
            percent: part.percent,
            grams: _grams(part.percent),
            sub: true,
          ),
        _line(
          context,
          name: 'Water',
          percent: input.hydration,
          grams: _grams(input.hydration),
        ),
        _line(
          context,
          name: 'Salt',
          percent: input.salt,
          grams: _grams(input.salt),
        ),
        if (input.style == DoughStyle.classic)
          _line(
            context,
            name: 'Yeast',
            percent: input.yeast,
            grams: _grams(input.yeast),
          ),
        if (input.style == DoughStyle.sourdough) ...[
          _line(
            context,
            name: 'Levain',
            percent: input.levainPercent,
            grams: _grams(input.levainPercent),
          ),
          _line(
            context,
            name: 'hydration',
            percent: input.levainHydration,
            sub: true,
            noWeight: true,
            alwaysShowPercent: true,
          ),
          _leavenBuild(context),
        ],
        if (input.style == DoughStyle.preferment) ...[
          _line(
            context,
            name: 'Preferment',
            percent: input.prefermentPercent,
            grams: _grams(input.prefermentPercent),
          ),
          _line(
            context,
            name: 'hydration',
            percent: input.prefermentHydration,
            sub: true,
            noWeight: true,
            alwaysShowPercent: true,
          ),
          _line(
            context,
            name: 'yeast',
            percent: input.prefermentYeast,
            sub: true,
            noWeight: true,
            alwaysShowPercent: true,
          ),
          _leavenBuild(context),
        ],
        if (enrichment.fatPercent != null)
          _line(
            context,
            name: 'Fat',
            percent: enrichment.fatPercent,
            grams: _grams(enrichment.fatPercent),
          ),
        if (enrichment.sugarPercent != null)
          _line(
            context,
            name: 'Sugar',
            percent: enrichment.sugarPercent,
            grams: _grams(enrichment.sugarPercent),
          ),
        if (enrichment.eggCount != null)
          _line(
            context,
            name: 'Eggs',
            percent: enrichment.eggCount,
            // Eggs are bought by the piece, so the column shows the count.
            readOnlyText: formatCount(
              recipe?.eggs?.count ?? enrichment.eggCount!,
              'egg',
              'eggs',
            ),
            grams: recipe?.eggs?.grams,
            alwaysShowPercent: true,
          ),
        for (final mixIn in input.mixIns)
          _line(
            context,
            name: mixIn.name,
            percent: mixIn.percent,
            grams: _grams(mixIn.percent),
          ),
      ],
    );
  }

  /// What goes into the levain or preferment, so it can be built the night
  /// before without doing the split by hand.
  Widget _leavenBuild(BuildContext context) {
    final leaven = recipe?.leaven;
    if (leaven == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: Insets.md,
        top: Insets.xs,
        bottom: Insets.sm,
      ),
      child: Text(
        [
          for (final i in leaven.ingredients)
            '${formatMass(i.grams, unit)} ${i.name.toLowerCase()}',
        ].join(' · '),
        style: numeric(
          theme.textTheme.bodySmall,
        ).copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _line(
    BuildContext context, {
    required String name,
    required double? percent,
    String? readOnlyText,
    double? grams,
    bool sub = false,
    bool noWeight = false,
    bool alwaysShowPercent = false,
  }) {
    final theme = Theme.of(context);
    final textStyle = sub
        ? theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.bodyMedium;
    final numberStyle = numeric(theme.textTheme.bodyMedium);

    final Widget value =
        percent == null || (!showBakersPercent && !alwaysShowPercent)
        ? const SizedBox.shrink()
        : Text(
            readOnlyText ?? formatPercent(percent),
            textAlign: TextAlign.right,
            style: numberStyle,
          );

    final weight = noWeight
        ? ''
        : grams == null
        ? '—'
        : formatMass(grams, unit);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: [
          if (sub) const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              name,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Insets.sm),
          SizedBox(width: 88, child: value),
          SizedBox(
            width: 64,
            child: Semantics(
              label: weight == '—' ? '$name, not worked out yet' : null,
              child: FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Text(weight, style: numeric(theme.textTheme.titleSmall)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A finished recipe as every screen shows it: the table,
/// read-only, over its totals. [input] must already pass `validate()`.
class RecipeSummary extends StatelessWidget {
  const RecipeSummary({
    super.key,
    required this.input,
    required this.unit,
    this.showBakersPercent = true,
  });

  final RecipeInput input;
  final MassUnit unit;
  final bool showBakersPercent;

  @override
  Widget build(BuildContext context) {
    final recipe = calculate(input);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecipeTable(
          input: input,
          recipe: recipe,
          unit: unit,
          showBakersPercent: showBakersPercent,
        ),
        const SizedBox(height: Insets.md),
        TotalsPanel(recipe: recipe, unit: unit),
      ],
    );
  }
}

/// The answer. A warm tonal panel, the one place the app raises its voice.
///
/// Only two foregrounds are drawn here — the total and the stat labels — and
/// both come from [BakingColors]. `onSurfaceVariant` is tuned against the page
/// rather than against a warm fill and misses AA on it; see the note in
/// `core/theme/app_theme.dart`.
class TotalsPanel extends StatelessWidget {
  const TotalsPanel({super.key, required this.recipe, required this.unit});

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
