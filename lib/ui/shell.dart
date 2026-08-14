import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/spacing.dart';
import 'widgets/app_nav_bar.dart';

/// The three tabs. Kept in one list so the bottom bar and the wide-screen rail
/// can never drift apart.
const navTabs = [
  NavTab(
    label: 'Calculate',
    icon: Icons.calculate_outlined,
    selectedIcon: Icons.calculate,
  ),
  NavTab(
    label: 'Recipes',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  NavTab(
    label: 'Tools',
    icon: Icons.handyman_outlined,
    selectedIcon: Icons.handyman,
  ),
];

/// Bottom navigation on phones, a rail on wide screens. Each tab keeps its own
/// stack, so switching tabs and coming back lands where you left off.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goToBranch(int index) => navigationShell.goBranch(
    index,
    // Tapping the tab you are already on pops back to its root, which is what
    // every platform's bottom bar does.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            AppNavBar(
              tabs: navTabs,
              selectedIndex: navigationShell.currentIndex,
              onSelected: _goToBranch,
              vertical: true,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppNavBar(
        tabs: navTabs,
        selectedIndex: navigationShell.currentIndex,
        onSelected: _goToBranch,
      ),
    );
  }
}
