import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/spacing.dart';
import 'calculator/calculator_page.dart';
import 'home/home_page.dart';
import 'library/library_page.dart';
import 'recipe/import_page.dart';
import 'recipe/recipe_page.dart';
import 'settings/settings_page.dart';
import 'timeline/timeline_page.dart';
import 'wizard/wizard_page.dart';

/// One stack, no tabs. Home is the jar and the shelf; everything else opens
/// over it and backs out to it.
///
/// The calculator and the library are children of `/`, so `context.go` to
/// either still has Home underneath. The calculator rises over Home rather
/// than sliding in: its sheet comes up from below while the jar flies into its
/// header (see `calculator_page.dart`).
///
/// `/recipe/:id` and `/import` sit at the top level so a shared link opens
/// straight onto the content.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'calculate',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 520),
            reverseTransitionDuration: const Duration(milliseconds: 380),
            // The page itself only fades; its sheet does the rising, on the
            // same animation, so the two stay in step.
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0, 0.6, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
            child: const CalculatorPage(),
          ),
        ),
        GoRoute(
          path: 'recipes',
          builder: (context, state) => const LibraryPage(),
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
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('That link did not lead anywhere.'),
            const SizedBox(height: Insets.lg),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
  ),
);
