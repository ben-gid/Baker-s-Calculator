import 'package:flutter/material.dart';

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
