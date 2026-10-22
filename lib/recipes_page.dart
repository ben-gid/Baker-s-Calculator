import 'package:dough_calculator/models/recipe_model.dart';
import 'package:dough_calculator/notifiers_and_providers/recipe_provider.dart';

import 'package:dough_calculator/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecipesPage extends ConsumerWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Recipes"),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                Navigator.pushNamed(context, '/account');
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Base Recipes"),
              Tab(text: "My Recipes"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecipeList(
              provider: baseRecipesProvider,
              emptyMessage: "No base recipes found.",
            ),
            _RecipeList(
              provider: userRecipesProvider,
              emptyMessage: "No custom recipes yet. Add one!",
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddOptions(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              context,
              icon: Icons.calculate_outlined,
              title: "Quick Calculate",
              subtitle: "Calculate without saving a recipe",
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/calculate");
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              context,
              icon: Icons.note_add_outlined,
              title: "New Recipe",
              subtitle: "Build and save a permanent recipe",
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/recipeForm");
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.bgLight, // AppColors.bgLight
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: 0.1,
                  ), // AppColors.primary
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeList extends ConsumerWidget {
  final Provider<List<Recipe>> provider;
  final String emptyMessage;

  const _RecipeList({required this.provider, required this.emptyMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(provider);

    if (recipes.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return ListTile(
          leading: Container(
            width: 12,
            height: 32,
            decoration: BoxDecoration(
              color: recipe.colorValue != null
                  ? Color(recipe.colorValue!)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Text(
            recipe.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(recipe.description ?? recipe.doughType.name),
          trailing: const Icon(Icons.calculate),
          onTap: () => _calculateRecipe(context, ref, recipe),
        );
      },
    );
  }

  void _calculateRecipe(BuildContext context, WidgetRef ref, Recipe recipe) {
    // 3. Navigate to dedicated recipe result page
    Navigator.pushNamed(
      context,
      "/calculatedMyRecipePage",
      arguments: {"recipe": recipe},
    );
  }
}
