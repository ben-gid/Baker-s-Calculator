import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/calculator.dart';
import '../../domain/models/saved_recipe.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/panel.dart';
import '../widgets/starter_jar.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final controller = ref.read(libraryProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
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
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Could not open your library',
            message: '$error',
          ),
          data: (state) => Column(
            children: [
              Padding(
                padding: pagePadding(context, top: 0, bottom: Insets.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: controller.search,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Search recipes',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    IconButton(
                      isSelected: state.favouritesOnly,
                      icon: const Icon(Icons.favorite_border),
                      selectedIcon: const Icon(Icons.favorite),
                      tooltip: state.favouritesOnly
                          ? 'Show all recipes'
                          : 'Show favourites only',
                      onPressed: controller.toggleFavouritesFilter,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _RecipeList(
                  state: state,
                  width: width,
                  onDismissError: controller.dismissError,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({
    required this.state,
    required this.width,
    required this.onDismissError,
  });

  final LibraryState state;
  final double width;
  final VoidCallback onDismissError;

  @override
  Widget build(BuildContext context) {
    final saved = state.visibleSaved;
    final system = state.visibleSystem;

    if (state.error == null && saved.isEmpty && system.isEmpty) {
      return EmptyState(
        icon: state.query.isEmpty ? Icons.menu_book_outlined : Icons.search_off,
        title: state.query.isEmpty
            ? 'No recipes yet'
            : 'Nothing matches "${state.query}"',
        message: state.query.isEmpty
            ? 'Start a new dough from Home and save it, or start from one of '
                  'the built-in recipes.'
            : 'Try a different name, flour or dough style.',
        actionLabel: state.query.isEmpty ? 'Suggest a recipe' : null,
        onAction: state.query.isEmpty ? () => context.push('/suggest') : null,
      );
    }

    return ListView(
      padding: pagePadding(context, top: 0),
      children: [
        if (state.error != null)
          ErrorBanner(message: state.error!, onDismiss: onDismissError),
        if (saved.isNotEmpty) ...[
          _SectionHeading('Your recipes', count: saved.length),
          for (final recipe in saved) _RecipeTile(recipe: recipe),
          const SizedBox(height: Insets.xl),
        ],
        if (system.isNotEmpty) ...[
          _SectionHeading('Built in', count: system.length),
          for (final recipe in system) _RecipeTile(recipe: recipe),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label, {required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Insets.sm),
    child: Row(
      children: [
        SectionLabel(label),
        const SizedBox(width: Insets.sm),
        Text('$count', style: numeric(Theme.of(context).textTheme.labelSmall)),
      ],
    ),
  );
}

class _RecipeTile extends ConsumerWidget {
  const _RecipeTile({required this.recipe});

  final SavedRecipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    // A recipe that fails validation can still be listed — it just cannot show
    // a weight. That is better than hiding it and losing the baker's work.
    final result = validate(recipe.input).hasErrors
        ? null
        : calculate(recipe.input);
    final weight = result?.totalWeight;

    final subtitle = [
      recipe.input.style.label,
      if (recipe.input.hydration case final hydration?)
        formatPercent(hydration),
      if (weight != null) formatMass(weight, settings.unit),
      if (recipe.input.loaves > 1) '${recipe.input.loaves} loaves',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: ListTile(
        title: Text(recipe.name, style: theme.textTheme.titleSmall),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        // Its jar, which travels on to the recipe's page.
        leading: Hero(
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
        trailing: recipe.isSystem
            ? null
            : IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                color: recipe.isFavorite ? theme.colorScheme.primary : null,
                tooltip: recipe.isFavorite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                onPressed: () => ref
                    .read(libraryProvider.notifier)
                    .toggleFavourite(recipe.id),
              ),
        onTap: () => context.push('/recipe/${recipe.id}'),
      ),
    );
  }
}
