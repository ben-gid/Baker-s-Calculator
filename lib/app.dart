import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:dough_calculator/calculated_my_recipe_page.dart";
import "package:dough_calculator/calculated_recipe_page.dart";
import "package:dough_calculator/quick_calculate_page.dart";
import "package:dough_calculator/recipes_page.dart";
import "package:dough_calculator/recipe_form_page.dart";
import "package:dough_calculator/login_page.dart";
import "package:dough_calculator/register_page.dart";
import "package:dough_calculator/account_page.dart";
import "package:dough_calculator/themes.dart";
import "package:dough_calculator/notifiers_and_providers/auth_provider.dart";

class DoughCalculator extends ConsumerWidget {
  const DoughCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      theme: darkTheme,
      initialRoute: authState.isAuthenticated ? "/" : "/login",
      routes: {
        "/": (context) => const RecipesPage(),
        "/login": (context) => const LoginPage(),
        "/register": (context) => const RegisterPage(),
        "/account": (context) => const AccountPage(),
        "/calculate": (context) => const QuickCalculatePage(),
        "/calculatedRecipePage": (context) => const CalculatedRecipePage(),
        "/calculatedMyRecipePage": (context) => const CalculatedMyRecipePage(),
        "/recipes": (context) => const RecipesPage(),
        "/recipeForm": (context) => const RecipeFormPage(),
      },
    );
  }
}
