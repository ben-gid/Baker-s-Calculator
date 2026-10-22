import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';

/// The primary action for a screen: a full-width pill pinned under the content,
/// sitting in the scaffold's `bottomNavigationBar` slot.
///
/// Replaces `FloatingActionButton.extended` — not because a FAB is round, but
/// because a floating one covered the last row of a long form. Taking its own
/// space means nothing is ever hidden underneath it, which is why
/// `Insets.scrollBottom` could drop from 96 to 24.
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String label;
  final IconData icon;

  /// Null disables the bar — it stays in place and greys out rather than
  /// disappearing, so the layout does not jump as a form becomes valid.
  final VoidCallback? onPressed;

  /// A quieter tonal button before the primary one — "Back" beside "Save".
  /// It takes the smaller share of the width, so the primary still leads.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onPressed != null;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.sm,
            Insets.lg,
            Insets.md,
          ),
          child: SizedBox(
            height: 54,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (secondaryLabel != null) ...[
                  Expanded(
                    flex: 2,
                    child: FilledButton.tonal(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                ],
                Expanded(flex: 3, child: _primary(theme, enabled)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primary(ThemeData theme, bool enabled) {
    final colors = theme.colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.surfaceContainerHigh,
        disabledForegroundColor: colors.onSurfaceVariant,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: Insets.sm),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: enabled ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
