import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'calculator/calculator_page.dart';
import 'library/library_page.dart';
import 'recipe/import_page.dart';
import 'recipe/recipe_page.dart';
import 'settings/settings_page.dart';
import 'shell.dart';
import 'timeline/timeline_page.dart';
import 'tools/tools_page.dart';
import 'wizard/wizard_page.dart';

/// Three tabs, each with its own navigation stack, plus two full-screen routes
/// pushed over the top.
///
/// `/recipe/:id` and `/import` sit outside the shell so a shared link opens
/// straight onto the content instead of behind a tab bar.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const CalculatorPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/recipes',
              builder: (context, state) => const LibraryPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tools',
              builder: (context, state) => const ToolsPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/recipe/:id',
      builder: (context, state) => RecipePage(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/recipe/:id/plan',
      builder: (context, state) =>
          TimelinePage(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/import',
      builder: (context, state) =>
          ImportPage(payload: state.uri.queryParameters['d']),
    ),
    GoRoute(path: '/suggest', builder: (context, state) => const WizardPage()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('That link did not lead anywhere.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go to the calculator'),
            ),
          ],
        ),
      ),
    ),
  ),
);
