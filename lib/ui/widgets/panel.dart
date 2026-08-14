import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';

/// A section heading inside a [Panel] — the title of the group, not of the page.
///
/// Set in the label style rather than uppercased: the design tells a heading
/// from body text by size, weight and colour, and shouting would fight the soft
/// shapes around it.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
    ),
  );
}

/// A titled panel. The one container shape in the app: a filled surface with a
/// generous radius, no border and no shadow.
///
/// It reads as a container because the page behind it is a shade darker, the
/// way a grouped iOS list or a Material 3 filled card does — so nothing here
/// draws an outline.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.title,
    this.trailing,
    this.note,
    this.fill,
    this.padding = const EdgeInsets.all(Insets.lg),
    required this.children,
  });

  final String? title;
  final Widget? trailing;

  /// Small explanatory line under the title.
  final String? note;

  /// Overrides the panel fill. Used by the totals block only.
  final Color? fill;

  final EdgeInsets padding;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeader = title != null || trailing != null;

    // Material, not a DecoratedBox: a ListTile or an InkWell inside the panel
    // paints its ink on the nearest Material ancestor, so a plain coloured box
    // would both hide that ink and let it bleed past the panel's rounded edge.
    return Material(
      color: fill ?? theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader)
              Row(
                children: [
                  if (title != null)
                    Expanded(child: SectionLabel(title!))
                  else
                    const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            if (note != null) ...[
              SizedBox(height: hasHeader ? Insets.xs : 0),
              Text(note!, style: theme.textTheme.bodySmall),
            ],
            if (hasHeader || note != null) const SizedBox(height: Insets.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A [Panel] that starts collapsed — used for the optional parts of the
/// calculator so the first screen is short.
class DisclosurePanel extends StatefulWidget {
  const DisclosurePanel({
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
  State<DisclosurePanel> createState() => _DisclosurePanelState();
}

class _DisclosurePanelState extends State<DisclosurePanel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = widget.badge ?? widget.subtitle;

    return Panel(
      padding: EdgeInsets.zero,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: widget.title,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(widget.title),
                        if (caption != null) ...[
                          const SizedBox(height: Insets.xs),
                          Text(caption, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  // A chevron that turns, rather than a +/- swap: the rotation
                  // is what says the panel below is the same thing opening.
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
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
          ),
      ],
    );
  }
}
