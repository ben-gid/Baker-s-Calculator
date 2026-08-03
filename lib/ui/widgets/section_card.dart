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
                    Expanded(child: Text(title!, style: theme.textTheme.titleMedium)),
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
class CollapsibleCard extends StatefulWidget {
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

  /// Shown when collapsed to say the section holds something, e.g. "3 flours".
  final String? badge;

  final List<Widget> children;

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Semantics(
              button: true,
              expanded: _expanded,
              child: Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: theme.textTheme.titleMedium),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.badge != null && !_expanded) ...[
                      Text(widget.badge!, style: theme.textTheme.labelMedium),
                      const SizedBox(width: Insets.sm),
                    ],
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: Motion.fast,
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.normal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      0,
                      Insets.lg,
                      Insets.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
