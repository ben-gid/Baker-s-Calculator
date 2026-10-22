import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/calculator.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_input.dart';
import '../../domain/validation.dart';
import 'number_field.dart';
import 'panel.dart';

/// The recipe as one table: ingredient, baker's percentage, weight.
///
/// It is the form and the result at once. In the calculator the percentage
/// column is the input and the weights fill in beside it as you type, so there
/// is nothing to scroll down to. Everywhere else it is read-only, so a recipe
/// looks the same wherever it appears.
///
/// Weights come from [recipe], which is null while the input is blocked. Every
/// weight then reads "—" rather than the rows disappearing, so the table holds
/// still while the baker fills it in.
class RecipeTable extends StatefulWidget {
  const RecipeTable({
    super.key,
    required this.input,
    required this.recipe,
    required this.unit,
    this.issues = const [],
    this.onChanged,
    this.showBakersPercent = true,
  });

  final RecipeInput input;
  final Recipe? recipe;
  final MassUnit unit;
  final List<InputIssue> issues;

  /// Null makes the table read-only.
  final ValueChanged<RecipeInput>? onChanged;

  /// Read-only tables only — an editable one always shows the column it edits.
  final bool showBakersPercent;

  @override
  State<RecipeTable> createState() => _RecipeTableState();
}

enum _Extra { flour, fat, sugar, eggs, mixIn }

class _RecipeTableState extends State<RecipeTable> {
  /// Fat, sugar and eggs the baker has added but not filled in yet. Their
  /// values are null until typed, and a null enrichment is how the model says
  /// "not in this dough" — so without this the row would vanish the moment its
  /// box was emptied.
  final Set<_Extra> _opened = {};

  RecipeInput get _input => widget.input;
  bool get _editable => widget.onChanged != null;

  void _emit(RecipeInput next) => widget.onChanged!(next);

  void _setEnrichment(Enrichment next) =>
      _emit(_input.copyWith(enrichment: next.isEmpty ? null : next));

  double? _grams(double? percent) =>
      percent == null ? null : widget.recipe?.gramsAt(percent);

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final issues = widget.issues;
    final enrichment = input.enrichmentOrEmpty;
    final blend = input.flourBlend;
    final mixIns = input.mixIns;
    final blendIssue = issues.firstFor(RecipeField.flourBlend);
    final mixInIssue = issues.firstFor(RecipeField.mixIns);

    bool shows(_Extra extra, double? value) =>
        value != null || _opened.contains(extra);

    return Panel(
      padding: EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        _editable ? Insets.xs : Insets.lg,
        Insets.md,
      ),
      children: [
        _line(
          name: 'Flour',
          percent: 100,
          fixed: true,
          grams: widget.recipe?.doughFlour,
        ),
        for (var i = 0; i < blend.length; i++)
          _line(
            name: blend[i].name,
            nameLabel: 'Flour ${i + 1}',
            onName: (name) => _emit(
              input.copyWith(
                flourBlend: [
                  for (var j = 0; j < blend.length; j++)
                    j == i ? blend[j].copyWith(name: name) : blend[j],
                ],
              ),
            ),
            fieldLabel: 'Flour ${i + 1} share',
            percent: blend[i].percent,
            issue: blendIssue,
            onPercent: (v) => _emit(
              input.copyWith(
                flourBlend: [
                  for (var j = 0; j < blend.length; j++)
                    j == i ? blend[j].copyWith(percent: v) : blend[j],
                ],
              ),
            ),
            grams: _grams(blend[i].percent),
            onRemove: () => _emit(
              input.copyWith(
                flourBlend: [
                  for (var j = 0; j < blend.length; j++)
                    if (j != i) blend[j],
                ],
              ),
            ),
            sub: true,
          ),
        _line(
          name: 'Water',
          fieldLabel: 'Hydration',
          hint: '65–80',
          percent: input.hydration,
          field: RecipeField.hydration,
          onPercent: (v) => _emit(input.copyWith(hydration: v)),
          grams: _grams(input.hydration),
        ),
        _line(
          name: 'Salt',
          hint: '1.8–2.2',
          percent: input.salt,
          field: RecipeField.salt,
          onPercent: (v) => _emit(input.copyWith(salt: v)),
          grams: _grams(input.salt),
        ),
        if (input.style == DoughStyle.classic)
          _line(
            name: 'Yeast',
            hint: '1–2',
            percent: input.yeast,
            field: RecipeField.yeast,
            onPercent: (v) => _emit(input.copyWith(yeast: v)),
            grams: _grams(input.yeast),
          ),
        if (input.style == DoughStyle.sourdough) ...[
          _line(
            name: 'Levain',
            hint: '15–25',
            percent: input.levainPercent,
            field: RecipeField.levainPercent,
            onPercent: (v) => _emit(input.copyWith(levainPercent: v)),
            grams: _grams(input.levainPercent),
          ),
          _line(
            name: 'hydration',
            fieldLabel: 'Levain hydration',
            hint: '50–100',
            percent: input.levainHydration,
            field: RecipeField.levainHydration,
            onPercent: (v) => _emit(input.copyWith(levainHydration: v)),
            sub: true,
            noWeight: true,
            alwaysShowPercent: true,
          ),
          _leavenBuild(context),
        ],
        if (input.style == DoughStyle.preferment) ...[
          _line(
            name: 'Preferment',
            hint: '20–40',
            percent: input.prefermentPercent,
            field: RecipeField.prefermentPercent,
            onPercent: (v) => _emit(input.copyWith(prefermentPercent: v)),
            grams: _grams(input.prefermentPercent),
          ),
          _line(
            name: 'hydration',
            fieldLabel: 'Preferment hydration',
            hint: '50–100',
            percent: input.prefermentHydration,
            field: RecipeField.prefermentHydration,
            onPercent: (v) => _emit(input.copyWith(prefermentHydration: v)),
            sub: true,
            noWeight: true,
            alwaysShowPercent: true,
          ),
          _line(
            name: 'yeast',
            fieldLabel: 'Preferment yeast',
            hint: '0.1–0.5',
            percent: input.prefermentYeast,
            field: RecipeField.prefermentYeast,
            onPercent: (v) => _emit(input.copyWith(prefermentYeast: v)),
            sub: true,
            noWeight: true,
            alwaysShowPercent: true,
          ),
          _leavenBuild(context),
          if (_editable) _PrefermentPresets(input: input, onChanged: _emit),
        ],
        if (shows(_Extra.fat, enrichment.fatPercent))
          _line(
            name: 'Fat',
            hint: '5–20',
            percent: enrichment.fatPercent,
            field: RecipeField.fat,
            onPercent: (v) =>
                _setEnrichment(enrichment.copyWith(fatPercent: v)),
            grams: _grams(enrichment.fatPercent),
            onRemove: () {
              setState(() => _opened.remove(_Extra.fat));
              _setEnrichment(enrichment.copyWith(fatPercent: null));
            },
          ),
        if (shows(_Extra.sugar, enrichment.sugarPercent))
          _line(
            name: 'Sugar',
            hint: '5–15',
            percent: enrichment.sugarPercent,
            field: RecipeField.sugar,
            onPercent: (v) =>
                _setEnrichment(enrichment.copyWith(sugarPercent: v)),
            grams: _grams(enrichment.sugarPercent),
            onRemove: () {
              setState(() => _opened.remove(_Extra.sugar));
              _setEnrichment(enrichment.copyWith(sugarPercent: null));
            },
          ),
        if (shows(_Extra.eggs, enrichment.eggCount))
          _line(
            name: 'Eggs',
            hint: '1–4',
            suffix: null,
            percent: enrichment.eggCount,
            // Eggs are bought by the piece, so the column shows the count.
            readOnlyText: formatCount(
              widget.recipe?.eggs?.count ?? enrichment.eggCount ?? 0,
              'egg',
              'eggs',
            ),
            field: RecipeField.eggs,
            onPercent: (v) => _setEnrichment(enrichment.copyWith(eggCount: v)),
            grams: enrichment.eggCount == null
                ? null
                : widget.recipe?.eggs?.grams,
            onRemove: () {
              setState(() => _opened.remove(_Extra.eggs));
              _setEnrichment(enrichment.copyWith(eggCount: null));
            },
            alwaysShowPercent: true,
          ),
        for (var i = 0; i < mixIns.length; i++)
          _line(
            name: mixIns[i].name,
            nameLabel: 'Mix-in ${i + 1}',
            onName: (name) => _emit(
              input.copyWith(
                mixIns: [
                  for (var j = 0; j < mixIns.length; j++)
                    j == i ? mixIns[j].copyWith(name: name) : mixIns[j],
                ],
              ),
            ),
            fieldLabel: 'Mix-in ${i + 1} share',
            hint: '5–20',
            percent: mixIns[i].percent,
            issue: mixInIssue,
            onPercent: (v) => _emit(
              input.copyWith(
                mixIns: [
                  for (var j = 0; j < mixIns.length; j++)
                    j == i ? mixIns[j].copyWith(percent: v) : mixIns[j],
                ],
              ),
            ),
            grams: _grams(mixIns[i].percent),
            onRemove: () => _emit(
              input.copyWith(
                mixIns: [
                  for (var j = 0; j < mixIns.length; j++)
                    if (j != i) mixIns[j],
                ],
              ),
            ),
          ),
        if (_editable)
          _AddMenu(
            options: [
              _Extra.flour,
              if (!shows(_Extra.fat, enrichment.fatPercent)) _Extra.fat,
              if (!shows(_Extra.sugar, enrichment.sugarPercent)) _Extra.sugar,
              if (!shows(_Extra.eggs, enrichment.eggCount)) _Extra.eggs,
              _Extra.mixIn,
            ],
            onSelected: _add,
          ),
      ],
    );
  }

  void _add(_Extra extra) {
    switch (extra) {
      // A blend of one is just the flour row again, so the first add brings
      // two empty flours to name and share out.
      case _Extra.flour:
        _emit(
          _input.copyWith(
            flourBlend: [
              ..._input.flourBlend,
              if (_input.flourBlend.isEmpty)
                const FlourPart(name: '', percent: null),
              const FlourPart(name: '', percent: null),
            ],
          ),
        );
      case _Extra.mixIn:
        _emit(
          _input.copyWith(
            mixIns: [
              ..._input.mixIns,
              const MixIn(name: '', percent: null),
            ],
          ),
        );
      case _Extra.fat || _Extra.sugar || _Extra.eggs:
        setState(() => _opened.add(extra));
    }
  }

  /// What goes into the levain or preferment, so it can be built the night
  /// before without doing the split by hand.
  Widget _leavenBuild(BuildContext context) {
    final leaven = widget.recipe?.leaven;
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
            '${formatMass(i.grams, widget.unit)} ${i.name.toLowerCase()}',
        ].join(' · '),
        style: numeric(
          theme.textTheme.bodySmall,
        ).copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _line({
    required String name,
    String? nameLabel,
    ValueChanged<String>? onName,
    String? fieldLabel,
    String? hint,
    String? suffix = '%',
    required double? percent,
    String? readOnlyText,
    bool fixed = false,
    RecipeField? field,
    InputIssue? issue,
    ValueChanged<double?>? onPercent,
    double? grams,
    VoidCallback? onRemove,
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

    final Widget label = _editable && onName != null
        ? NameField(
            label: nameLabel!,
            showLabel: false,
            value: name,
            onChanged: onName,
          )
        : Text(name, style: textStyle, overflow: TextOverflow.ellipsis);

    final Widget value;
    if (_editable && !fixed) {
      value = NumberField(
        label: fieldLabel ?? name,
        showLabel: false,
        dense: true,
        hint: hint,
        suffix: suffix,
        value: percent,
        issue: issue ?? (field == null ? null : widget.issues.firstFor(field)),
        onChanged: onPercent!,
      );
    } else if (percent == null ||
        (!widget.showBakersPercent && !alwaysShowPercent && !_editable)) {
      value = const SizedBox.shrink();
    } else if (_editable) {
      // The flour's fixed 100, laid out like the boxes below it — number at
      // the left, unit at the right — so the column reads straight down.
      value = Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatPercent(percent).replaceAll('%', ''),
                style: numberStyle,
              ),
            ),
            Text(
              '%',
              style: numberStyle.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    } else {
      value = Text(
        readOnlyText ?? formatPercent(percent),
        textAlign: TextAlign.right,
        style: numberStyle,
      );
    }

    final weight = noWeight
        ? ''
        : grams == null
        ? '—'
        : formatMass(grams, widget.unit);

    return Padding(
      padding: _editable
          ? const EdgeInsets.only(bottom: Insets.xs)
          : const EdgeInsets.symmetric(vertical: Insets.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _editable ? 44 : 0),
        child: Row(
          children: [
            if (sub) const SizedBox(width: Insets.md),
            Expanded(child: label),
            const SizedBox(width: Insets.sm),
            SizedBox(width: 88, child: value),
            SizedBox(
              width: 64,
              child: Semantics(
                label: weight == '—' ? '$name, not worked out yet' : null,
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    weight,
                    style: numeric(theme.textTheme.titleSmall),
                  ),
                ),
              ),
            ),
            if (_editable)
              SizedBox(
                width: 40,
                child: onRemove == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        tooltip: 'Remove ${name.isEmpty ? nameLabel : name}',
                        onPressed: onRemove,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.options, required this.onSelected});

  final List<_Extra> options;
  final ValueChanged<_Extra> onSelected;

  static const _labels = {
    _Extra.flour: 'Flour',
    _Extra.fat: 'Fat',
    _Extra.sugar: 'Sugar',
    _Extra.eggs: 'Eggs',
    _Extra.mixIn: 'Mix-in',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<_Extra>(
        tooltip: 'Add an ingredient',
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem(value: option, child: Text(_labels[option]!)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 20, color: colors.primary),
              const SizedBox(width: Insets.sm),
              Text(
                'Add ingredient',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tap for the three preferments a baker actually uses, instead of
/// remembering three numbers each.
class _PrefermentPresets extends StatelessWidget {
  const _PrefermentPresets({required this.input, required this.onChanged});

  final RecipeInput input;
  final ValueChanged<RecipeInput> onChanged;

  static const _presets = {
    'Poolish': (percent: 30.0, hydration: 100.0, yeast: 0.2),
    'Biga': (percent: 40.0, hydration: 55.0, yeast: 0.3),
    'Pâte fermentée': (percent: 25.0, hydration: 65.0, yeast: 0.5),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Insets.md, bottom: Insets.xs),
      child: Wrap(
        spacing: Insets.sm,
        children: [
          for (final preset in _presets.entries)
            ActionChip(
              label: Text(preset.key),
              onPressed: () => onChanged(
                input.copyWith(
                  prefermentPercent: preset.value.percent,
                  prefermentHydration: preset.value.hydration,
                  prefermentYeast: preset.value.yeast,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A finished recipe as every screen but the calculator shows it: the table,
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
