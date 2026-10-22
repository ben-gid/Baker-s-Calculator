import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/notification_service.dart';
import 'data/recipe_repository.dart';
import 'data/settings_repository.dart';
import 'state/providers.dart';

/// Opens the platform stores before the first frame so no screen has to render
/// a spinner for a preference read. The recipe file itself is still loaded
/// lazily — it is the one thing that could be slow.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final recipes = await RecipeRepository.open();
  // Registers the reminder buttons; asks for nothing.
  final notifications = NotificationService();
  await notifications.initialise();

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(preferences),
        ),
        recipeRepositoryProvider.overrideWithValue(recipes),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const BakersCalculatorApp(),
    ),
  );
}
