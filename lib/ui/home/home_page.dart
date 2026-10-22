import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/calculator.dart';
import '../../domain/models/active_bake.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/saved_recipe.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/bake_step_card.dart';
import '../widgets/motion.dart';
import '../widgets/panel.dart';
import '../widgets/starter_jar.dart';

/// The hub. One jar that shows whatever matters now — a bake rising, the dough
/// you were building, or an empty jar waiting — and a shelf of recipes under
/// it. There are no tabs: everything else opens over this and backs out to it.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bake = ref.watch(activeBakeProvider);
    final dough = ref.watch(calculationProvider);
    final library = ref.watch(libraryProvider).value;
    final unit = ref.watch(settingsProvider.select((s) => s.unit));

    final saved = library?.saved ?? const <SavedRecipe>[];
    final recents = saved.isNotEmpty
        ? saved.take(10).toList()
        : library?.system ?? const <SavedRecipe>[];

    // Before the baker has saved anything, the tools sit on the empty jar;
    // after, they move to the end of the shelf. One place at a time.
    final firstLaunch = library != null && saved.isEmpty;

    void newDough() {
      ref.read(calculatorProvider.notifier).reset();
      context.go('/calculate');
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: pagePadding(context, top: Insets.sm),
          children: [
            RiseIn(child: _TopBar()),
            const SizedBox(height: Insets.md),
            RiseIn(
              delay: const Duration(milliseconds: 60),
              child: _JarHero(
                bake: bake,
                dough: dough,
                unit: unit,
                showTools: firstLaunch && bake == null && dough == null,
                onNewDough: newDough,
              ),
            ),
            const SizedBox(height: Insets.xl),
            RiseIn(
              delay: const Duration(milliseconds: 120),
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New dough'),
                  onPressed: newDough,
                ),
              ),
            ),
            if (recents.isNotEmpty) ...[
              const SizedBox(height: Insets.xl),
              RiseIn(
                delay: const Duration(milliseconds: 180),
                child: _Shelf(
                  title: saved.isNotEmpty ? 'Recent' : 'Built in',
                  recipes: recents,
                  unit: unit,
                  showTools: !firstLaunch,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          "Baker's Calculator",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.settings_outlined),
        tooltip: 'Settings',
        onPressed: () => context.push('/settings'),
      ),
    ],
  );
}

/// The jar and what it is showing. Stateful only to tick once a minute while a
/// bake is under way, so the rise and the countdown keep moving.
class _JarHero extends StatefulWidget {
  const _JarHero({
    required this.bake,
    required this.dough,
    required this.unit,
    required this.showTools,
    required this.onNewDough,
  });

  final ActiveBake? bake;
  final Recipe? dough;
  final MassUnit unit;
  final bool showTools;
  final VoidCallback onNewDough;

  @override
  State<_JarHero> createState() => _JarHeroState();
}

class _JarHeroState extends State<_JarHero> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(_JarHero old) {
    super.didUpdateWidget(old);
    _syncTick();
  }

  void _syncTick() {
    if (widget.bake == null) {
      _tick?.cancel();
      _tick = null;
    } else {
      _tick ??= Timer.periodic(
        const Duration(minutes: 1),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bake = widget.bake;
    final dough = widget.dough;
    final now = DateTime.now();

    final ({double level, double dome, double fizz, String label}) jar;
    final VoidCallback onTap;
    final Widget caption;

    if (bake != null) {
      final rise = bake.riseAt(now);
      jar = (
        level: rise.level,
        dome: rise.ready ? 1 : 0,
        fizz: 0.9,
        label: 'Your bake, ${rise.ready ? 'ready' : 'rising'}',
      );
      onTap = () => context.push('/recipe/${bake.recipeId}/plan');
      caption = _BakeCaption(bake: bake, now: now);
    } else if (dough != null) {
      jar = (
        level: jarLevelFor(dough.hydration),
        dome: 0,
        fizz: 0.5,
        label: 'Your dough, ${formatPercent(dough.hydration)} hydration',
      );
      onTap = () => context.go('/calculate');
      caption = _DoughCaption(dough: dough, unit: widget.unit);
    } else {
      jar = (level: 0.3, dome: 0, fizz: 0.25, label: 'An empty jar');
      onTap = widget.onNewDough;
      caption = _EmptyCaption(showTools: widget.showTools);
    }

    return Column(
      children: [
        Semantics(
          button: true,
          label: jar.label,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: Hero(
              tag: jarHeroTag,
              child: SizedBox(
                width: 184,
                height: 236,
                child: StarterJar(
                  level: jar.level,
                  dome: jar.dome,
                  fizz: jar.fizz,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          child: KeyedSubtree(
            key: ValueKey(caption.runtimeType),
            child: caption,
          ),
        ),
      ],
    );
  }
}

/// What the bake is doing now, under the jar. The headline opens the step
/// under way into its card — the grams for it, and Skip and Done — and the
/// dots under it are the whole bake at a glance, opening the live plan.
class _BakeCaption extends ConsumerStatefulWidget {
  const _BakeCaption({required this.bake, required this.now});

  final ActiveBake bake;
  final DateTime now;

  @override
  ConsumerState<_BakeCaption> createState() => _BakeCaptionState();
}

class _BakeCaptionState extends ConsumerState<_BakeCaption> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bake = widget.bake;
    final now = widget.now;
    final current = bake.currentAt(now);
    final step = current == null ? null : bake.schedule[current];
    final nextIndex = current == null ? null : bake.nextAfter(current);
    final next = nextIndex == null ? null : bake.schedule[nextIndex];

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

    final card = _open && current != null
        ? Padding(
            padding: const EdgeInsets.only(top: Insets.sm),
            child: BakeStepCard(bake: bake, index: current, now: now),
          )
        : const SizedBox(width: double.infinity);

    return Column(
      children: [
        SectionLabel(bake.recipeName),
        const SizedBox(height: Insets.xs),
        Semantics(
          button: step != null,
          expanded: step == null ? null : _open,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.field),
            onTap: step == null ? null : () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm,
                vertical: Insets.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: numeric(theme.textTheme.titleLarge),
                    ),
                  ),
                  if (step != null)
                    Icon(_open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: () => context.push('/recipe/${bake.recipeId}/plan'),
          child: Padding(
            padding: const EdgeInsets.all(Insets.sm),
            child: BakeDots(bake: bake, now: now),
          ),
        ),
        // Without motion the card simply appears: AnimatedSize asserts when
        // its duration is zero.
        if (MediaQuery.disableAnimationsOf(context))
          card
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: card,
          ),
        if (next != null && !_open) ...[
          const SizedBox(height: Insets.xs),
          Text(
            'Then ${next.step.title.toLowerCase()} at ${formatClock(next.startsAt)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        TextButton(
          onPressed: () => ref.read(activeBakeProvider.notifier).stop(),
          child: Text(step == null ? 'Clear' : 'Stop bake'),
        ),
      ],
    );
  }
}

class _DoughCaption extends StatelessWidget {
  const _DoughCaption({required this.dough, required this.unit});

  final Recipe dough;
  final MassUnit unit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '${formatPercent(dough.hydration)} hydration',
        style: numeric(Theme.of(context).textTheme.bodyMedium),
      ),
      const SizedBox(height: Insets.sm),
      FilledButton.tonal(
        onPressed: () => context.go('/calculate'),
        child: Text(
          'Back to your ${formatMass(dough.totalWeight, unit)} dough',
        ),
      ),
    ],
  );
}

class _EmptyCaption extends StatelessWidget {
  const _EmptyCaption({required this.showTools});

  final bool showTools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Every dough starts with an empty jar.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (showTools) ...[
          const SizedBox(height: Insets.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Suggest a recipe'),
                onPressed: () => context.push('/suggest'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Import a recipe'),
                onPressed: () => context.push('/import'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Recipes like jars on a shelf: a swipe away, with the whole library behind
/// "See all". Once the baker has recipes of their own, the two tools close the
/// row.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.recipes,
    required this.unit,
    required this.showTools,
  });

  final String title;
  final List<SavedRecipe> recipes;
  final MassUnit unit;
  final bool showTools;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final recipe in recipes) _RecipeCard(recipe: recipe, unit: unit),
      if (showTools) ...const [
        _ToolCard(
          icon: Icons.auto_awesome_outlined,
          title: 'Suggest a recipe',
          subtitle: 'Four questions',
          route: '/suggest',
        ),
        _ToolCard(
          icon: Icons.download_outlined,
          title: 'Import a recipe',
          subtitle: 'From a link or code',
          route: '/import',
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel(title)),
            TextButton(
              onPressed: () => context.push('/recipes'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: Insets.sm),
            itemBuilder: (context, index) => cards[index],
          ),
        ),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.onTap, required this.children});

  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 156,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.unit});

  final SavedRecipe recipe;
  final MassUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = validate(recipe.input).hasErrors
        ? null
        : calculate(recipe.input);

    return _ShelfCard(
      onTap: () => context.push('/recipe/${recipe.id}'),
      children: [
        // A little still jar at this recipe's hydration.
        Hero(
          tag: recipeJarTag(recipe.id),
          child: SizedBox(
            width: 30,
            height: 38,
            child: StarterJar(
              level: jarLevelFor(result?.hydration),
              fizz: 0.3,
              animate: false,
            ),
          ),
        ),
        const Spacer(),
        Text(
          recipe.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: Insets.xs),
        Text(
          [
            recipe.input.style.label,
            if (result != null) formatMass(result.totalWeight, unit),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: numeric(theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ShelfCard(
      onTap: () => context.push(route),
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const Spacer(),
        Text(title, maxLines: 2, style: theme.textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        Text(subtitle, maxLines: 1, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
