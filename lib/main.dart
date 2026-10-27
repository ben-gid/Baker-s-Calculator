import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/home_screen_widget.dart';
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
  final settings = SettingsRepository(preferences);
  // Registers the widget's buttons and brings it up to date with the saved
  // bake, which a press handled in the background may have moved on.
  final homeWidget = HomeScreenWidget();
  await homeWidget.initialise(onWidgetAction);
  unawaited(homeWidget.showBake(settings.readActiveBake()));

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        recipeRepositoryProvider.overrideWithValue(recipes),
        notificationServiceProvider.overrideWithValue(notifications),
        homeScreenWidgetProvider.overrideWithValue(homeWidget),
      ],
      child: const BakersCalculatorApp(),
    ),
  );
}
