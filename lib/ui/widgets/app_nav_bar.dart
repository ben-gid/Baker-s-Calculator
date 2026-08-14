import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';

/// One tab in [AppNavBar]. Kept in a single list by the shell so the bar and the
/// wide-screen rail can never drift apart.
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

/// The app's navigation, in both of its forms: a bar of equal cells along the
/// bottom on phones, a column of the same cells down the left on wide screens.
///
/// The selected tab takes a rounded tonal pill behind its icon and the label
/// underneath goes solid — the Material 3 indicator, matching how selection
/// looks everywhere else in the app.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.vertical = false,
  });

  final List<NavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Rail form: cells stack downward.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final cells = [
      for (var i = 0; i < tabs.length; i++)
        _Cell(
          tab: tabs[i],
          selected: i == selectedIndex,
          vertical: vertical,
          onTap: () => onSelected(i),
        ),
    ];

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        right: !vertical,
        child: vertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: Insets.lg),
                  for (final cell in cells)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.sm),
                      child: cell,
                    ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                child: Row(
                  children: [for (final cell in cells) Expanded(child: cell)],
                ),
              ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.tab,
    required this.selected,
    required this.vertical,
    required this.onTap,
  });

  final NavTab tab;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        excludeSemantics: true,
        child: SizedBox(
          width: vertical ? 76 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 64,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  size: 22,
                  color: foreground,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
