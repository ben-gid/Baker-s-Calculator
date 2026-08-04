import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';

/// A titled card. The one container shape in the app.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    this.note,
    required this.children,
  });

  final String? title;
  final Widget? trailing;

  /// Small explanatory line under the title.
  final String? note;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || trailing != null)
              Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(title!, style: theme.textTheme.titleMedium),
                    ),
                  if (title == null) const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            if (note != null) ...[
              const SizedBox(height: Insets.xs),
              Text(note!, style: theme.textTheme.bodySmall),
            ],
            if (title != null || trailing != null || note != null)
              const SizedBox(height: Insets.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A [SectionCard] that starts collapsed — used for the optional parts of the
/// calculator so the first screen is short.
///
/// The expand/collapse behaviour, the rotating chevron and the semantics are
/// all `ExpansionTile`'s; `expansionTileTheme` in `app_theme.dart` strips its
/// default dividers so it sits inside a [Card] cleanly.
class CollapsibleCard extends StatelessWidget {
  const CollapsibleCard({
    super.key,
    required this.title,
    this.subtitle,
    this.initiallyExpanded = false,
    this.badge,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final bool initiallyExpanded;

  /// Says the section already holds something, e.g. "3 flours". Takes the
  /// place of [subtitle] when set — what is in there beats what could be.
  final String? badge;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = badge ?? subtitle;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: caption == null
            ? null
            : Text(caption, style: theme.textTheme.bodySmall),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.all(Insets.lg),
        childrenPadding: const EdgeInsets.fromLTRB(
          Insets.lg,
          0,
          Insets.lg,
          Insets.lg,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
