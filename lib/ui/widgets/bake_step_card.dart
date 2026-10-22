import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/models/active_bake.dart';
import '../../domain/models/recipe.dart';
import '../../domain/timeline.dart';
import '../../state/providers.dart';

/// The step under way, opened up: what goes into the bowl, how to tell it is
/// done, and the buttons to say so. The same card sits under Home's jar and in
/// the live plan, so a bake reads one way wherever it is picked up.
///
/// Every button goes through [ActiveBakeController]; the card itself only
/// shows the [ActiveBake] it is given.
class BakeStepCard extends ConsumerWidget {
  const BakeStepCard({
    super.key,
    required this.bake,
    required this.index,
    required this.now,
  });

  final ActiveBake bake;
  final int index;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final controller = ref.read(activeBakeProvider.notifier);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final scheduled = bake.schedule[index];
    final step = scheduled.step;
    final rows = bake.ingredients?[index] ?? const <Ingredient>[];
    final sets = step.sets;
    final setsDone = bake.records[index].setsDone;
    final feed = step.kind == StepKind.levain ? bake.feed : null;
    final levainSkipped = bake.plan.indexed.any(
      (e) =>
          e.$2.kind == StepKind.levain &&
          bake.records[e.$1].status == StepStatus.skipped,
    );
    final addsWater =
        step.kind != StepKind.levain &&
        step.kind != StepKind.preferment &&
        rows.any((i) => i.role == IngredientRole.water);
    final water = addsWater ? ref.watch(doughTempsProvider).water : null;

    void say(String message) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    final String when;
    if (scheduled.startsAt.isAfter(now)) {
      when = 'Starts ${formatClock(scheduled.startsAt)}';
    } else {
      when = '${formatDuration(scheduled.endsAt.difference(now))} left';
    }

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(step.title, style: theme.textTheme.titleMedium),
                ),
                Text(when, style: numeric(theme.textTheme.labelLarge)),
              ],
            ),
            if (sets != null) ...[
              const SizedBox(height: Insets.sm),
              _SetCount(done: setsDone, of: sets),
            ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: Insets.md),
              StepRows(
                rows: rows,
                unit: unit,
                isWeighed: (row) =>
                    bake.weighed.contains(ActiveBake.weighedKey(index, row)),
                onToggle: (row) =>
                    controller.toggleWeighed(ActiveBake.weighedKey(index, row)),
              ),
            ],
            if (feed != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                'Feed ${bake.ratio.label}. Keep '
                '${formatMass(feed.keepBack, unit)} back for your jar.',
                style: muted,
              ),
            ],
            if (step.kind == StepKind.mix && levainSkipped)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Text('Use ripe levain you already have.', style: muted),
              ),
            if (water != null)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Text(
                  'Use water at ${water.waterTemp.round()} °C',
                  style: numeric(muted),
                ),
              ),
            if (step.detail != null) ...[
              const SizedBox(height: Insets.sm),
              Text(step.detail!, style: muted),
            ],
            const SizedBox(height: Insets.md),
            // A row when the buttons fit, stacked when a narrow card or large
            // text would push them off the edge.
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              overflowSpacing: Insets.xs,
              children: [
                if (sets == null)
                  TextButton(
                    onPressed: () {
                      controller.skipTo(index + 1);
                      say('Skipped ${step.title.toLowerCase()}');
                    },
                    child: const Text('Skip'),
                  )
                else
                  TextButton(
                    onPressed: () {
                      controller.done(index);
                      say('Folding done');
                    },
                    child: const Text('Enough folding'),
                  ),
                FilledButton(
                  onPressed: () {
                    if (sets != null) {
                      controller.foldSetDone(index);
                      say(
                        setsDone + 1 >= sets
                            ? 'Folding done'
                            : 'Set ${setsDone + 1} done',
                      );
                    } else {
                      controller.done(index);
                      say('${step.title} done');
                    }
                  },
                  child: Text(sets == null ? 'Done' : 'Set done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What goes into the bowl: the weight in a column on the left, the name
/// beside it — the calculator's own layout — and, given [onToggle], a tick for
/// each row as it is weighed. Ticking never holds anything up.
class StepRows extends StatelessWidget {
  const StepRows({
    super.key,
    required this.rows,
    required this.unit,
    this.isWeighed,
    this.onToggle,
  });

  final List<Ingredient> rows;
  final MassUnit unit;
  final bool Function(Ingredient row)? isWeighed;
  final ValueChanged<Ingredient>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        for (final row in rows)
          _row(theme, colors, row, isWeighed?.call(row) ?? false),
      ],
    );
  }

  Widget _row(ThemeData theme, ColorScheme colors, Ingredient row, bool done) {
    final amount = row.count != null
        ? formatCount(row.count!, 'egg', 'eggs')
        : formatMass(row.grams, unit);
    final style = theme.textTheme.bodyLarge?.copyWith(
      color: done ? colors.onSurfaceVariant : null,
      decoration: done ? TextDecoration.lineThrough : null,
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(amount, style: numeric(style))),
          Expanded(child: Text(row.name, style: style)),
          if (onToggle != null)
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? colors.primary : colors.outline,
            ),
        ],
      ),
    );
    if (onToggle == null) return content;
    return Semantics(
      checked: done,
      label: '$amount ${row.name}, ${done ? 'weighed' : 'not weighed'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.field),
        onTap: () => onToggle!(row),
        child: content,
      ),
    );
  }
}

class _SetCount extends StatelessWidget {
  const _SetCount({required this.done, required this.of});

  final int done;
  final int of;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    return Row(
      children: [
        for (var i = 0; i < of; i++)
          Padding(
            padding: const EdgeInsets.only(right: Insets.xs),
            child: _Dot(
              fill: i < done ? baking.starterDeep : null,
              ring: i < done ? null : theme.colorScheme.outline,
            ),
          ),
        const SizedBox(width: Insets.sm),
        Text(
          done >= of ? 'All $of sets done' : 'Set ${done + 1} of $of',
          style: numeric(theme.textTheme.labelLarge),
        ),
      ],
    );
  }
}

/// The whole bake at a glance, one dot a step: filled for done, a ring for a
/// step the clock passed unticked, a dash for one left out, the starter's
/// colour for the step under way.
class BakeDots extends StatelessWidget {
  const BakeDots({super.key, required this.bake, required this.now});

  final ActiveBake bake;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final states = [
      for (var i = 0; i < bake.plan.length; i++) bake.stateAt(i, now),
    ];
    final done = states.where((s) => s == StepProgress.done).length;
    return Semantics(
      label: '$done of ${states.length} steps done',
      excludeSemantics: true,
      child: Wrap(
        spacing: Insets.sm,
        runSpacing: Insets.xs,
        alignment: WrapAlignment.center,
        children: [for (final state in states) ProgressMark(state)],
      ),
    );
  }
}

/// One step's mark, the same in the dots and down the plan's spine.
class ProgressMark extends StatelessWidget {
  const ProgressMark(this.progress, {super.key});

  final StepProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final baking = theme.extension<BakingColors>()!;
    return switch (progress) {
      StepProgress.done => _Dot(fill: colors.primary),
      StepProgress.current => _Dot(
        fill: baking.starter,
        ring: baking.starterDeep,
        size: 12,
      ),
      StepProgress.unticked => _Dot(ring: colors.outline),
      StepProgress.skipped => _Dash(color: colors.outlineVariant),
      StepProgress.upcoming => _Dot(fill: colors.outlineVariant),
    };
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.fill, this.ring, this.size = 10});

  final Color? fill;
  final Color? ring;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: fill,
      border: ring == null ? null : Border.all(color: ring!, width: 2),
    ),
  );
}

class _Dash extends StatelessWidget {
  const _Dash({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 10,
    height: 10,
    child: Center(
      child: Container(
        width: 10,
        height: 2,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    ),
  );
}
