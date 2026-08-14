import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';

/// A segmented control: a rounded track with a rounded thumb that slides to the
/// selected cell, the way an iOS segmented control does.
///
/// The thumb is a single positioned box rather than a fill on each cell, so the
/// selection actually travels between options instead of blinking from one to
/// the next.
class StyleToggle<T> extends StatelessWidget {
  const StyleToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final List<ToggleOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Shrinks the track for a toggle that sits in a panel header rather than
  /// carrying a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final index = options.indexWhere((o) => o.value == selected);
    final height = compact ? 36.0 : minTapTarget;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / options.length;
          return Stack(
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: cell * index,
                  width: cell,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in options)
                    Expanded(
                      child: _Cell(
                        option: option,
                        selected: option.value == selected,
                        onTap: () => onChanged(option.value),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class ToggleOption<T> {
  const ToggleOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ToggleOption<Object?> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: Material(
        // Transparent, so the thumb behind it stays visible; the ink still
        // lands on this Material rather than bleeding to the panel.
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 16, color: foreground),
                  const SizedBox(width: Insets.xs),
                ],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    style:
                        theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                        ) ??
                        TextStyle(color: foreground),
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
