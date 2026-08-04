import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The three tabs. Kept in one list so the bottom bar and the wide-screen rail
/// can never drift apart.
class NavTab {
  const NavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

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
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goToBranch,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final tab in navTabs)
                  NavigationRailDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: Text(tab.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goToBranch,
        destinations: [
          for (final tab in navTabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
