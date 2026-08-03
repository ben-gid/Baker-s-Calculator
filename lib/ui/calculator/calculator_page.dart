import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/dough_style.dart';
import '../../domain/models/recipe_input.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/number_field.dart';
import '../widgets/recipe_view.dart';
import '../widgets/section_card.dart';
import 'save_recipe_sheet.dart';

/// One scrolling screen: pick a style, fill in what it needs, and the recipe
/// updates underneath as you type.
///
/// The original app split this across two pages behind a Calculate button and
/// an "Advanced" step. Everything optional is now a collapsed card instead, so
/// the first screen is short but nothing is hidden behind navigation.
class CalculatorPage extends ConsumerWidget {
  const CalculatorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(calculatorProvider);
    final issues = ref.watch(issuesProvider);
    final recipe = ref.watch(calculationProvider);
    final settings = ref.watch(settingsProvider);
    final width = MediaQuery.sizeOf(context).width;

    final form = _CalculatorForm(input: input, issues: issues);
    final result = recipe == null
        ? _BlockedResult(issues: issues)
        : RecipeView(
            recipe: recipe,
            unit: settings.unit,
            showBakersPercent: settings.showBakersPercent,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Baker's Calculator"),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Start over',
            onPressed: () => ref.read(calculatorProvider.notifier).reset(),
          ),
          const SizedBox(width: Insets.xs),
        ],
      ),
      floatingActionButton: recipe == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showSaveRecipeSheet(context, ref, input),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save'),
            ),
      body: SafeArea(
        child: width >= Breakpoints.tablet
            // Wide screens put the live result beside the form so the numbers
            // never scroll out of sight while typing.
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Scroll(width: width, child: form),
                  ),
                  Expanded(
                    child: _Scroll(width: width, child: result),
                  ),
                ],
              )
            : _Scroll(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    form,
                    const SizedBox(height: Insets.xl),
                    result,
                  ],
                ),
              ),
      ),
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      pageMargin(width),
      Insets.lg,
      pageMargin(width),
      Insets.scrollBottom,
    ),
    child: child,
  );
}

class _CalculatorForm extends ConsumerWidget {
  const _CalculatorForm({required this.input, required this.issues});

  final RecipeInput input;
  final List<InputIssue> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StyleSelector(style: input.style, onChanged: controller.setStyle),
        const SizedBox(height: Insets.lg),
        _DoughCard(input: input, issues: issues),
        const SizedBox(height: Insets.md),
        _FlourBlendCard(input: input, issues: issues),
        const SizedBox(height: Insets.md),
        _EnrichmentCard(input: input, issues: issues),
        const SizedBox(height: Insets.md),
        _MixInsCard(input: input, issues: issues),
        const SizedBox(height: Insets.md),
        _BatchCard(input: input),
      ],
    );
  }
}

class _StyleSelector extends StatelessWidget {
  const _StyleSelector({required this.style, required this.onChanged});

  final DoughStyle style;
  final ValueChanged<DoughStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<DoughStyle>(
          segments: [
            for (final option in DoughStyle.values)
              ButtonSegment(value: option, label: Text(option.label)),
          ],
          selected: {style},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          style.blurb,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DoughCard extends ConsumerWidget {
  const _DoughCard({required this.input, required this.issues});

  final RecipeInput input;
  final List<InputIssue> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);

    return SectionCard(
      title: 'Dough',
      children: [
        if (input.style.isForward)
          NumberField(
            label: 'Flour weight',
            suffix: 'g',
            value: input.flourWeight,
            helper: 'Typically 400–600 g per loaf',
            issue: issues.firstFor(RecipeField.flourWeight),
            onChanged: (v) =>
                controller.change((i) => i.copyWith(flourWeight: v)),
          )
        else
          NumberField(
            label: 'Total dough weight',
            suffix: 'g',
            value: input.totalDoughWeight,
            helper: 'Everything combined — typically 700 g–1 kg per loaf',
            issue: issues.firstFor(RecipeField.totalDoughWeight),
            onChanged: (v) =>
                controller.change((i) => i.copyWith(totalDoughWeight: v)),
          ),
        NumberField(
          label: 'Hydration',
          suffix: '%',
          value: input.hydration,
          helper: 'Water as a percentage of the dough flour',
          issue: issues.firstFor(RecipeField.hydration),
          onChanged: (v) => controller.change((i) => i.copyWith(hydration: v)),
        ),
        NumberField(
          label: 'Salt',
          suffix: '%',
          value: input.salt,
          helper: 'Usually 1.8–2.2% of the dough flour',
          issue: issues.firstFor(RecipeField.salt),
          onChanged: (v) => controller.change((i) => i.copyWith(salt: v)),
        ),
        if (input.style == DoughStyle.classic)
          NumberField(
            label: 'Yeast',
            suffix: '%',
            value: input.yeast,
            helper: 'Instant yeast, usually 1–2% of flour',
            issue: issues.firstFor(RecipeField.yeast),
            onChanged: (v) => controller.change((i) => i.copyWith(yeast: v)),
          ),
        if (input.style == DoughStyle.sourdough) ...[
          NumberField(
            label: 'Levain',
            suffix: '%',
            value: input.levainPercent,
            helper: 'Levain as a percentage of the dough flour — typically 20%',
            issue: issues.firstFor(RecipeField.levainPercent),
            onChanged: (v) =>
                controller.change((i) => i.copyWith(levainPercent: v)),
          ),
          NumberField(
            label: 'Levain hydration',
            suffix: '%',
            value: input.levainHydration,
            helper: 'Water in the levain — typically 100%',
            issue: issues.firstFor(RecipeField.levainHydration),
            onChanged: (v) =>
                controller.change((i) => i.copyWith(levainHydration: v)),
          ),
        ],
        if (input.style == DoughStyle.preferment) ...[
          _PrefermentPresets(input: input),
          NumberField(
            label: 'Preferment',
            suffix: '%',
            value: input.prefermentPercent,
            helper: 'Preferment as a percentage of the dough flour',
            issue: issues.firstFor(RecipeField.prefermentPercent),
            onChanged: (v) =>
                controller.change((i) => i.copyWith(prefermentPercent: v)),
          ),
          NumberField(
            label: 'Preferment hydration',
            suffix: '%',
            value: input.prefermentHydration,
            helper: 'Poolish is 100%, biga 50–60%',
            issue: issues.firstFor(RecipeField.prefermentHydration),
            onChanged: (v) =>
                controller.change((i) => i.copyWith(prefermentHydration: v)),
          ),
          NumberField(
            label: 'Preferment yeast',
            suffix: '%',
            value: input.prefermentYeast,
            helper: 'Yeast relative to the flour in the preferment',
            issue: issues.firstFor(RecipeField.prefermentYeast),
            onChanged: (v) =>
                controller.change((i) => i.copyWith(prefermentYeast: v)),
          ),
        ],
      ],
    );
  }
}

/// One tap for the three preferments a baker actually uses, instead of
/// remembering three numbers each.
class _PrefermentPresets extends ConsumerWidget {
  const _PrefermentPresets({required this.input});

  final RecipeInput input;

  static const _presets = {
    'Poolish': (percent: 30.0, hydration: 100.0, yeast: 0.2),
    'Biga': (percent: 40.0, hydration: 55.0, yeast: 0.3),
    'Pâte fermentée': (percent: 25.0, hydration: 65.0, yeast: 0.5),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Wrap(
        spacing: Insets.sm,
        children: [
          for (final preset in _presets.entries)
            ActionChip(
              label: Text(preset.key),
              onPressed: () => controller.change(
                (i) => i.copyWith(
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

class _FlourBlendCard extends ConsumerWidget {
  const _FlourBlendCard({required this.input, required this.issues});

  final RecipeInput input;
  final List<InputIssue> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);
    final blend = input.flourBlend;
    final issue = issues.firstFor(RecipeField.flourBlend);
    final total = blend.fold(0.0, (sum, part) => sum + (part.percent ?? 0));

    void setBlend(List<FlourPart> next) =>
        controller.change((i) => i.copyWith(flourBlend: next));

    return CollapsibleCard(
      title: 'Flour blend',
      subtitle: 'Mix two or more flours',
      initiallyExpanded: blend.isNotEmpty,
      badge: blend.isEmpty ? null : '${blend.length} flours',
      children: [
        if (blend.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Text(
              'One flour is assumed unless you add a blend.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (var index = 0; index < blend.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: NameField(
                    label: 'Flour ${index + 1}',
                    value: blend[index].name,
                    onChanged: (name) => setBlend([
                      for (var i = 0; i < blend.length; i++)
                        i == index ? blend[i].copyWith(name: name) : blend[i],
                    ]),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  flex: 2,
                  child: NumberField(
                    dense: true,
                    suffix: '%',
                    value: blend[index].percent,
                    onChanged: (percent) => setBlend([
                      for (var i = 0; i < blend.length; i++)
                        i == index
                            ? blend[i].copyWith(percent: percent)
                            : blend[i],
                    ]),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove ${blend[index].name}',
                  onPressed: () => setBlend([
                    for (var i = 0; i < blend.length; i++)
                      if (i != index) blend[i],
                  ]),
                ),
              ],
            ),
          ),
        if (issue != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Text(
              issue.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          )
        else if (blend.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Text(
              'Total ${formatPercent(total)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add flour'),
            onPressed: () => setBlend([
              ...blend,
              // Suggest the remainder so two flours land on 100% by default.
              FlourPart(
                name: blend.isEmpty ? 'Bread flour' : '',
                percent: blend.isEmpty ? 100 : (100 - total).clamp(0, 100),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _EnrichmentCard extends ConsumerWidget {
  const _EnrichmentCard({required this.input, required this.issues});

  final RecipeInput input;
  final List<InputIssue> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);
    final enrichment = input.enrichmentOrEmpty;
    final active = <String>{
      if (enrichment.fatPercent != null) 'fat',
      if (enrichment.sugarPercent != null) 'sugar',
      if (enrichment.eggCount != null) 'eggs',
    };

    void set(Enrichment next) => controller.change(
      (i) => i.copyWith(enrichment: next.isEmpty ? null : next),
    );

    return CollapsibleCard(
      title: 'Enrich',
      subtitle: 'Fat, sugar and eggs',
      initiallyExpanded: active.isNotEmpty,
      badge: active.isEmpty ? null : '${active.length} added',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.lg),
          child: Wrap(
            spacing: Insets.sm,
            children: [
              FilterChip(
                label: const Text('Fat'),
                selected: active.contains('fat'),
                onSelected: (on) =>
                    set(enrichment.copyWith(fatPercent: on ? 8 : null)),
              ),
              FilterChip(
                label: const Text('Sugar'),
                selected: active.contains('sugar'),
                onSelected: (on) =>
                    set(enrichment.copyWith(sugarPercent: on ? 6 : null)),
              ),
              FilterChip(
                label: const Text('Eggs'),
                selected: active.contains('eggs'),
                onSelected: (on) =>
                    set(enrichment.copyWith(eggCount: on ? 1 : null)),
              ),
            ],
          ),
        ),
        if (active.contains('fat'))
          NumberField(
            label: 'Fat',
            suffix: '%',
            value: enrichment.fatPercent,
            helper: 'Butter, oil — as a percentage of flour',
            issue: issues.firstFor(RecipeField.fat),
            onChanged: (v) => set(enrichment.copyWith(fatPercent: v)),
          ),
        if (active.contains('sugar'))
          NumberField(
            label: 'Sugar',
            suffix: '%',
            value: enrichment.sugarPercent,
            helper: 'Sugar, honey — as a percentage of flour',
            issue: issues.firstFor(RecipeField.sugar),
            onChanged: (v) => set(enrichment.copyWith(sugarPercent: v)),
          ),
        if (active.contains('eggs'))
          NumberField(
            label: 'Eggs',
            value: enrichment.eggCount,
            helper: 'Large eggs, counted — ${gramsPerEgg.round()} g each',
            issue: issues.firstFor(RecipeField.eggs),
            onChanged: (v) => set(enrichment.copyWith(eggCount: v)),
          ),
      ],
    );
  }
}

class _MixInsCard extends ConsumerWidget {
  const _MixInsCard({required this.input, required this.issues});

  final RecipeInput input;
  final List<InputIssue> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);
    final mixIns = input.mixIns;

    void setMixIns(List<MixIn> next) =>
        controller.change((i) => i.copyWith(mixIns: next));

    return CollapsibleCard(
      title: 'Mix-ins',
      subtitle: 'Seeds, nuts, cheese, olives',
      initiallyExpanded: mixIns.isNotEmpty,
      badge: mixIns.isEmpty ? null : '${mixIns.length} added',
      children: [
        for (var index = 0; index < mixIns.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: NameField(
                    label: 'Mix-in ${index + 1}',
                    value: mixIns[index].name,
                    onChanged: (name) => setMixIns([
                      for (var i = 0; i < mixIns.length; i++)
                        i == index ? mixIns[i].copyWith(name: name) : mixIns[i],
                    ]),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  flex: 2,
                  child: NumberField(
                    dense: true,
                    suffix: '%',
                    value: mixIns[index].percent,
                    onChanged: (percent) => setMixIns([
                      for (var i = 0; i < mixIns.length; i++)
                        i == index
                            ? mixIns[i].copyWith(percent: percent)
                            : mixIns[i],
                    ]),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove ${mixIns[index].name}',
                  onPressed: () => setMixIns([
                    for (var i = 0; i < mixIns.length; i++)
                      if (i != index) mixIns[i],
                  ]),
                ),
              ],
            ),
          ),
        if (issues.firstFor(RecipeField.mixIns) case final issue?)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Text(
              issue.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add mix-in'),
            onPressed: () =>
                setMixIns([...mixIns, const MixIn(name: '', percent: 10)]),
          ),
        ),
      ],
    );
  }
}

class _BatchCard extends ConsumerWidget {
  const _BatchCard({required this.input});

  final RecipeInput input;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);
    final settings = ref.watch(settingsProvider);

    return SectionCard(
      title: 'Batch',
      trailing: SegmentedButton<MassUnit>(
        segments: [
          for (final unit in MassUnit.values)
            ButtonSegment(value: unit, label: Text(unit.symbol)),
        ],
        selected: {settings.unit},
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
        onSelectionChanged: (selection) =>
            ref.read(settingsProvider.notifier).setUnit(selection.first),
      ),
      children: [
        Row(
          children: [
            // Expanded rather than Spacer: at narrow widths the label has to
            // give way to the stepper, not push it off the card.
            Expanded(
              child: Text(
                'Loaves',
                style: Theme.of(context).textTheme.bodyLarge,
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFeatures: tabularFigures,
                  fontFamily: numericFont,
                ),
              ),
            ),
            IconButton.outlined(
              icon: const Icon(Icons.add),
              tooltip: 'One more loaf',
              onPressed: () =>
                  controller.change((i) => i.copyWith(loaves: i.loaves + 1)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown in place of the recipe when the input cannot be calculated. Lists the
/// blocking problems so the fix is obvious without hunting up the form.
class _BlockedResult extends StatelessWidget {
  const _BlockedResult({required this.issues});

  final List<InputIssue> issues;

  @override
  Widget build(BuildContext context) {
    final errors = issues
        .where((i) => i.severity == IssueSeverity.error)
        .toList();
    return SectionCard(
      title: 'Recipe',
      children: [
        EmptyState(
          icon: Icons.edit_note,
          title: errors.length == 1
              ? 'One thing to fix'
              : '${errors.length} things to fix',
          message: errors.map((e) => e.message).join('\n'),
        ),
      ],
    );
  }
}
