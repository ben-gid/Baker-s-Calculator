import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/models/recipe_input.dart';
import '../../domain/validation.dart';
import '../widgets/number_field.dart';
import '../widgets/panel.dart';

/// The calculator's percentages: one row each, the box on the left and its
/// name on the right, so a whole dough fits on a phone with little scrolling.
///
/// Only the boxes the style needs show; fat, sugar, eggs, a flour blend and
/// mix-ins wait behind "Add ingredient". There is no weights column — the
/// header's total rolls as you type, and the recipe itself is the next step.
class DoughForm extends StatefulWidget {
  const DoughForm({
    super.key,
    required this.input,
    required this.issues,
    required this.onChanged,
  });

  final RecipeInput input;
  final List<InputIssue> issues;
  final ValueChanged<RecipeInput> onChanged;

  @override
  State<DoughForm> createState() => _DoughFormState();
}

enum _Extra { flour, fat, sugar, eggs, mixIn }

/// What a labelled box says under itself: warnings only. An empty box is left
/// alone because the header gathers every blank into one "Needs …" line, and
/// an error is left to the header too, which already prints it — under the box
/// as well, it would say everything twice.
InputIssue? adviceFor(InputIssue? issue) =>
    issue?.severity == IssueSeverity.warning ? issue : null;

class _DoughFormState extends State<DoughForm> {
  /// Fat, sugar and eggs the baker has added but not filled in yet. Their
  /// values are null until typed, and a null enrichment is how the model says
  /// "not in this dough" — so without this the box would vanish the moment it
  /// was emptied.
  final Set<_Extra> _opened = {};

  RecipeInput get _input => widget.input;

  void _emit(RecipeInput next) => widget.onChanged(next);

  void _setEnrichment(Enrichment next) =>
      _emit(_input.copyWith(enrichment: next.isEmpty ? null : next));

  InputIssue? _issue(RecipeField field) =>
      adviceFor(widget.issues.firstFor(field));

  bool _shows(_Extra extra, double? value) =>
      value != null || _opened.contains(extra);

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final enrichment = input.enrichmentOrEmpty;

    Widget field({
      required String label,
      required String hint,
      String? suffix = '%',
      required double? value,
      required RecipeField issue,
      required ValueChanged<double?> onChanged,
      VoidCallback? onRemove,
    }) {
      final advice = _issue(issue);
      return _FieldRow(
        box: NumberField(
          label: label,
          showLabel: false,
          dense: true,
          hint: hint,
          suffix: suffix,
          value: value,
          issue: advice,
          onChanged: onChanged,
        ),
        label: Text(label),
        advice: advice,
        removeTooltip: 'Remove $label',
        onRemove: onRemove,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Dough',
          children: [
            field(
              label: 'Hydration',
              hint: '65–80',
              value: input.hydration,
              issue: RecipeField.hydration,
              onChanged: (v) => _emit(input.copyWith(hydration: v)),
            ),
            field(
              label: 'Salt',
              hint: '1.8–2.2',
              value: input.salt,
              issue: RecipeField.salt,
              onChanged: (v) => _emit(input.copyWith(salt: v)),
            ),
            if (input.style == DoughStyle.classic)
              field(
                label: 'Yeast',
                hint: '1–2',
                value: input.yeast,
                issue: RecipeField.yeast,
                onChanged: (v) => _emit(input.copyWith(yeast: v)),
              ),
          ],
        ),
        if (input.style == DoughStyle.sourdough) ...[
          const SizedBox(height: Insets.sm),
          _Section(
            title: 'Levain',
            children: [
              field(
                label: 'Levain',
                hint: '15–25',
                value: input.levainPercent,
                issue: RecipeField.levainPercent,
                onChanged: (v) => _emit(input.copyWith(levainPercent: v)),
              ),
              field(
                label: 'Levain hydration',
                hint: '50–100',
                value: input.levainHydration,
                issue: RecipeField.levainHydration,
                onChanged: (v) => _emit(input.copyWith(levainHydration: v)),
              ),
            ],
          ),
        ],
        if (input.style == DoughStyle.preferment) ...[
          const SizedBox(height: Insets.sm),
          _Section(
            title: 'Preferment',
            children: [
              _PrefermentPresets(input: input, onChanged: _emit),
              const SizedBox(height: Insets.sm),
              field(
                label: 'Preferment',
                hint: '20–40',
                value: input.prefermentPercent,
                issue: RecipeField.prefermentPercent,
                onChanged: (v) => _emit(input.copyWith(prefermentPercent: v)),
              ),
              field(
                label: 'Preferment hydration',
                hint: '50–100',
                value: input.prefermentHydration,
                issue: RecipeField.prefermentHydration,
                onChanged: (v) => _emit(input.copyWith(prefermentHydration: v)),
              ),
              field(
                label: 'Preferment yeast',
                hint: '0.1–0.5',
                value: input.prefermentYeast,
                issue: RecipeField.prefermentYeast,
                onChanged: (v) => _emit(input.copyWith(prefermentYeast: v)),
              ),
            ],
          ),
        ],
        if (_shows(_Extra.fat, enrichment.fatPercent) ||
            _shows(_Extra.sugar, enrichment.sugarPercent) ||
            _shows(_Extra.eggs, enrichment.eggCount)) ...[
          const SizedBox(height: Insets.sm),
          _Section(
            title: 'Enrichment',
            children: [
              if (_shows(_Extra.fat, enrichment.fatPercent))
                field(
                  label: 'Fat',
                  hint: '5–20',
                  value: enrichment.fatPercent,
                  issue: RecipeField.fat,
                  onChanged: (v) =>
                      _setEnrichment(enrichment.copyWith(fatPercent: v)),
                  onRemove: () {
                    setState(() => _opened.remove(_Extra.fat));
                    _setEnrichment(enrichment.copyWith(fatPercent: null));
                  },
                ),
              if (_shows(_Extra.sugar, enrichment.sugarPercent))
                field(
                  label: 'Sugar',
                  hint: '5–15',
                  value: enrichment.sugarPercent,
                  issue: RecipeField.sugar,
                  onChanged: (v) =>
                      _setEnrichment(enrichment.copyWith(sugarPercent: v)),
                  onRemove: () {
                    setState(() => _opened.remove(_Extra.sugar));
                    _setEnrichment(enrichment.copyWith(sugarPercent: null));
                  },
                ),
              if (_shows(_Extra.eggs, enrichment.eggCount))
                // Eggs are bought by the piece, so this box is a count.
                field(
                  label: 'Eggs',
                  hint: '1–4',
                  suffix: null,
                  value: enrichment.eggCount,
                  issue: RecipeField.eggs,
                  onChanged: (v) =>
                      _setEnrichment(enrichment.copyWith(eggCount: v)),
                  onRemove: () {
                    setState(() => _opened.remove(_Extra.eggs));
                    _setEnrichment(enrichment.copyWith(eggCount: null));
                  },
                ),
            ],
          ),
        ],
        if (input.flourBlend.isNotEmpty) ...[
          const SizedBox(height: Insets.sm),
          _NamedShares(
            title: 'Flour blend',
            noun: 'Flour',
            names: [for (final part in input.flourBlend) part.name],
            shares: [for (final part in input.flourBlend) part.percent],
            issue: widget.issues.firstFor(RecipeField.flourBlend),
            onName: (i, name) => _emit(
              input.copyWith(
                flourBlend: [
                  for (var j = 0; j < input.flourBlend.length; j++)
                    j == i
                        ? input.flourBlend[j].copyWith(name: name)
                        : input.flourBlend[j],
                ],
              ),
            ),
            onShare: (i, v) => _emit(
              input.copyWith(
                flourBlend: [
                  for (var j = 0; j < input.flourBlend.length; j++)
                    j == i
                        ? input.flourBlend[j].copyWith(percent: v)
                        : input.flourBlend[j],
                ],
              ),
            ),
            onRemove: (i) => _emit(
              input.copyWith(
                flourBlend: [
                  for (var j = 0; j < input.flourBlend.length; j++)
                    if (j != i) input.flourBlend[j],
                ],
              ),
            ),
          ),
        ],
        if (input.mixIns.isNotEmpty) ...[
          const SizedBox(height: Insets.sm),
          _NamedShares(
            title: 'Mix-ins',
            noun: 'Mix-in',
            hint: '5–20',
            names: [for (final mixIn in input.mixIns) mixIn.name],
            shares: [for (final mixIn in input.mixIns) mixIn.percent],
            issue: widget.issues.firstFor(RecipeField.mixIns),
            onName: (i, name) => _emit(
              input.copyWith(
                mixIns: [
                  for (var j = 0; j < input.mixIns.length; j++)
                    j == i
                        ? input.mixIns[j].copyWith(name: name)
                        : input.mixIns[j],
                ],
              ),
            ),
            onShare: (i, v) => _emit(
              input.copyWith(
                mixIns: [
                  for (var j = 0; j < input.mixIns.length; j++)
                    j == i
                        ? input.mixIns[j].copyWith(percent: v)
                        : input.mixIns[j],
                ],
              ),
            ),
            onRemove: (i) => _emit(
              input.copyWith(
                mixIns: [
                  for (var j = 0; j < input.mixIns.length; j++)
                    if (j != i) input.mixIns[j],
                ],
              ),
            ),
          ),
        ],
        _AddMenu(
          options: [
            _Extra.flour,
            if (!_shows(_Extra.fat, enrichment.fatPercent)) _Extra.fat,
            if (!_shows(_Extra.sugar, enrichment.sugarPercent)) _Extra.sugar,
            if (!_shows(_Extra.eggs, enrichment.eggCount)) _Extra.eggs,
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
}

/// A list of named shares — the flours of a blend, or the mix-ins. Each row is
/// a name box beside a percentage box; the group's one message sits under the
/// list rather than repeating under every row.
class _NamedShares extends StatelessWidget {
  const _NamedShares({
    required this.title,
    required this.noun,
    this.hint,
    required this.names,
    required this.shares,
    required this.issue,
    required this.onName,
    required this.onShare,
    required this.onRemove,
  });

  final String title;

  /// `Flour`, `Mix-in` — numbered into each row's labels, `Flour 1` and
  /// `Flour 1 share`.
  final String noun;
  final String? hint;
  final List<String> names;
  final List<double?> shares;
  final InputIssue? issue;
  final void Function(int index, String name) onName;
  final void Function(int index, double? share) onShare;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issue = this.issue;
    return _Section(
      title: title,
      children: [
        // The share is the box on the left, like every other row; the name,
        // typed in, is its label.
        for (var i = 0; i < names.length; i++)
          _FieldRow(
            box: NumberField(
              label: '$noun ${i + 1} share',
              showLabel: false,
              dense: true,
              hint: hint,
              suffix: '%',
              value: shares[i],
              issue: issue?.missing == null ? issue : null,
              onChanged: (v) => onShare(i, v),
            ),
            label: NameField(
              label: '$noun ${i + 1}',
              showLabel: false,
              value: names[i],
              onChanged: (name) => onName(i, name),
            ),
            removeTooltip:
                'Remove ${names[i].isEmpty ? '$noun ${i + 1}' : names[i]}',
            onRemove: () => onRemove(i),
          ),
        if (adviceFor(issue) case final advice?)
          Padding(
            padding: const EdgeInsets.only(left: Insets.xs, right: Insets.lg),
            child: Text(
              advice.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.extension<BakingColors>()!.warn,
              ),
            ),
          ),
      ],
    );
  }
}

/// A heading over its rows, with no panel around them: the form sits on the
/// white sheet, where a panel would be the sheet's own colour and add nothing
/// but padding.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionLabel(title),
      const SizedBox(height: Insets.xs),
      ...children,
    ],
  );
}

/// Every box in the form is this wide, the weight's included, so the numbers
/// make one column down the left.
const fieldBoxWidth = 112.0;

/// One input: the box on the left, at the same width on every row so the
/// numbers line up in a column, and what it is on the right. A warning, if
/// there is one, sits under the row.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.box,
    required this.label,
    this.advice,
    required this.removeTooltip,
    this.onRemove,
  });

  final Widget box;
  final Widget label;
  final InputIssue? advice;
  final String removeTooltip;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final advice = this.advice;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: fieldBoxWidth, child: box),
              const SizedBox(width: Insets.md),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium,
                  child: label,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  tooltip: removeTooltip,
                  onPressed: onRemove,
                ),
            ],
          ),
          if (advice != null)
            Padding(
              padding: const EdgeInsets.only(left: Insets.xs, top: Insets.xs),
              child: Text(
                advice.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.extension<BakingColors>()!.warn,
                ),
              ),
            ),
        ],
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
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.xs,
            vertical: Insets.sm,
          ),
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
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
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
    );
  }
}
