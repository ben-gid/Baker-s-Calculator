import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/calculator.dart';
import '../../domain/models/active_bake.dart';
import '../../domain/models/saved_recipe.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/panel.dart';

/// The front door: start a dough, see the bake that is running, or pick up a
/// recent recipe — each one tap from here.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bake = ref.watch(activeBakeProvider);
    final inProgress = ref.watch(calculationProvider);
    final library = ref.watch(libraryProvider).value;
    final settings = ref.watch(settingsProvider);

    final saved = library?.saved ?? const <SavedRecipe>[];
    final recents = saved.isNotEmpty
        ? saved.take(10).toList()
        : library?.system ?? const <SavedRecipe>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Baker's Calculator"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: Insets.xs),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: pagePadding(context),
          children: [
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New dough'),
                onPressed: () {
                  ref.read(calculatorProvider.notifier).reset();
                  context.go('/calculate');
                },
              ),
            ),
            // A dough that already works is worth getting back to; "New
            // dough" would otherwise be the only way in, and it clears it.
            if (inProgress != null) ...[
              const SizedBox(height: Insets.sm),
              TextButton(
                onPressed: () => context.go('/calculate'),
                child: Text(
                  'Back to your ${formatMass(inProgress.totalWeight, settings.unit)} dough',
                ),
              ),
            ],
            if (bake != null) ...[
              const SizedBox(height: Insets.lg),
              _BakeCard(bake: bake),
            ],
            if (recents.isNotEmpty) ...[
              const SizedBox(height: Insets.xl),
              SectionLabel(saved.isNotEmpty ? 'Recent' : 'Built in'),
              const SizedBox(height: Insets.sm),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recents.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Insets.sm),
                  itemBuilder: (context, index) =>
                      _RecipeCard(recipe: recents[index], unit: settings.unit),
                ),
              ),
            ],
            const SizedBox(height: Insets.xl),
            Text(
              'Every new dough starts blank. Use Template in the calculator to '
              'start from a recipe instead.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the running bake is doing now, and what comes next. Re-reads the clock
/// once a minute, which is as fine as the plan itself is.
class _BakeCard extends ConsumerStatefulWidget {
  const _BakeCard({required this.bake});

  final ActiveBake bake;

  @override
  ConsumerState<_BakeCard> createState() => _BakeCardState();
}

class _BakeCardState extends ConsumerState<_BakeCard> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final step = widget.bake.stepAt(now);
    final next = step == null ? null : widget.bake.stepAfter(step);
    final onFill = TextStyle(color: colors.onPrimaryContainer);

    final String headline;
    if (step == null) {
      headline = 'Done — out of the oven';
    } else if (step.startsAt.isAfter(now)) {
      headline =
          'Starts ${formatClock(step.startsAt)} with '
          '${step.step.title.toLowerCase()}';
    } else {
      headline =
          '${step.step.title} · ${formatDuration(step.endsAt.difference(now))} left';
    }

    return Panel(
      fill: colors.primaryContainer,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionLabel(
                widget.bake.recipeName,
                color: colors.onPrimaryContainer,
              ),
            ),
            TextButton(
              onPressed: () => ref.read(activeBakeProvider.notifier).stop(),
              child: Text(step == null ? 'Clear' : 'Stop bake'),
            ),
          ],
        ),
        Text(headline, style: theme.textTheme.titleMedium?.merge(onFill)),
        if (next != null) ...[
          const SizedBox(height: Insets.xs),
          Text(
            'Then ${next.step.title.toLowerCase()} at ${formatClock(next.startsAt)}',
            style: theme.textTheme.bodySmall?.merge(onFill),
          ),
        ],
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.unit});

  final SavedRecipe recipe;
  final MassUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weight = validate(recipe.input).hasErrors
        ? null
        : calculate(recipe.input).totalWeight;

    return SizedBox(
      width: 176,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/recipe/${recipe.id}'),
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  [
                    recipe.input.style.label,
                    if (weight != null) formatMass(weight, unit),
                  ].join(' · '),
                  style: numeric(theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
