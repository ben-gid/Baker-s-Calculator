import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/spacing.dart';
import '../../data/recipe_share.dart';
import '../../domain/calculator.dart';
import '../../domain/models/saved_recipe.dart';
import '../../domain/validation.dart';
import '../../state/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/recipe_view.dart';
import '../widgets/action_bar.dart';
import '../widgets/panel.dart';

class RecipePage extends ConsumerWidget {
  const RecipePage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final settings = ref.watch(settingsProvider);

    final recipe = library.hasValue
        ? ref.read(libraryProvider.notifier).byId(id)
        : null;

    if (library.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.search_off,
          title: 'Recipe not found',
          message: 'It may have been deleted from this device.',
          actionLabel: 'Back to recipes',
          onAction: () => context.go('/recipes'),
        ),
      );
    }

    final blocked = validate(recipe.input).hasErrors;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Open in calculator',
            onPressed: () {
              ref.read(calculatorProvider.notifier).load(recipe.input);
              context.go('/');
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share',
            onPressed: blocked ? null : () => _share(context, recipe, ref),
          ),
          _Menu(recipe: recipe),
          const SizedBox(width: Insets.xs),
        ],
      ),
      bottomNavigationBar: ActionBar(
        label: 'Plan this bake',
        icon: Icons.schedule,
        onPressed: blocked
            ? null
            : () => context.push('/recipe/${recipe.id}/plan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recipe.isSystem)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.lg),
                  child: _BuiltInBanner(recipe: recipe),
                ),
              if (recipe.notes != null && recipe.notes!.isNotEmpty) ...[
                Panel(title: 'Notes', children: [Text(recipe.notes!)]),
                const SizedBox(height: Insets.md),
              ],
              if (blocked)
                const EmptyState(
                  icon: Icons.error_outline,
                  title: 'This recipe is incomplete',
                  message:
                      'Open it in the calculator to fill in the missing values.',
                )
              else
                RecipeView(
                  recipe: calculate(recipe.input),
                  unit: settings.unit,
                  showBakersPercent: settings.showBakersPercent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    SavedRecipe recipe,
    WidgetRef ref,
  ) async {
    final settings = ref.read(settingsProvider);
    final text = toPlainText(recipe, settings.unit);
    final link = toShareLink(recipe);
    await SharePlus.instance.share(
      ShareParams(
        text: '$text\nOpen in Baker\'s Calculator: $link',
        subject: recipe.name,
      ),
    );
  }
}

class _BuiltInBanner extends ConsumerWidget {
  const _BuiltInBanner({required this.recipe});

  final SavedRecipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Built-in recipe. Save a copy to make it yours.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              final copy = await ref
                  .read(libraryProvider.notifier)
                  .duplicate(recipe, name: recipe.name);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Copied "${copy.name}" to your recipes'),
                ),
              );
              router.go('/recipe/${copy.id}');
            },
            child: const Text('Save a copy'),
          ),
        ],
      ),
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({required this.recipe});

  final SavedRecipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      onSelected: (action) => switch (action) {
        'duplicate' => _duplicate(context, ref),
        'export' => _export(context),
        'delete' => _confirmDelete(context, ref),
        _ => null,
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem(value: 'export', child: Text('Export as file')),
        if (!recipe.isSystem)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final copy = await ref.read(libraryProvider.notifier).duplicate(recipe);
    router.go('/recipe/${copy.id}');
  }

  Future<void> _export(BuildContext context) async {
    final safeName = recipe.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    await SharePlus.instance.share(
      ShareParams(
        fileNameOverrides: ['${safeName.isEmpty ? 'recipe' : safeName}.json'],
        files: [
          XFile.fromData(
            utf8.encode(toJsonDocument(recipe)),
            mimeType: 'application/json',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${recipe.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final router = GoRouter.of(context);
    await ref.read(libraryProvider.notifier).delete(recipe.id);
    router.go('/recipes');
  }
}
