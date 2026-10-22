import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/validation.dart';

/// A labelled numeric input wired straight to state — there is no Calculate
/// button, so every keystroke updates the recipe.
///
/// The label sits *above* the box rather than floating into a gap in its edge,
/// so the field stays one unbroken filled shape. The unit is a fixed column on
/// the right, which keeps the number and its unit from reflowing as the value
/// grows.
///
/// The controller is only rewritten when the incoming [value] differs from what
/// is already typed, otherwise the caret jumps to the end while the baker is
/// mid-number. An empty box therefore has to reach state as null: if state
/// coerced it to a number, this would immediately type that number back in and
/// the field could never be cleared.
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.helper,
    this.hint,
    this.issue,
    this.dense = false,
    this.showLabel = true,
  });

  final String? label;

  /// False keeps [label] for screen readers but prints nothing above the box,
  /// for a field that sits in a row whose own text already names it.
  final bool showLabel;

  /// Greyed inside the empty box — a typical range such as `65–80`. A range
  /// rather than a number, so it can never be mistaken for something typed.
  final String? hint;
  final double? value;
  final ValueChanged<double?> onChanged;

  /// Strips the helper slot and bottom margin so the field fits inside a row
  /// next to another control. The label still shows if one is given.
  final bool dense;

  /// `%`, `g`, `°C` — a column inside the field, not part of the label.
  final String? suffix;

  final String? helper;
  final InputIssue? issue;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );

  static String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  @override
  void didUpdateWidget(NumberField old) {
    super.didUpdateWidget(old);
    if (parseNumber(_controller.text) != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    final issue = widget.issue;
    final isWarning = issue?.severity == IssueSeverity.warning;
    final message = issue?.message ?? widget.helper;

    // Warnings are advisory, so they colour the rule and the message amber
    // rather than using the error slot, which would imply the recipe is blocked.
    // A box that is merely empty is not outlined at all: a blank dough is all
    // empty boxes, and a page of red rules would read as a page of mistakes.
    final Color? stateColor = issue == null || issue.missing != null
        ? null
        : isWarning
        ? baking.warn
        : theme.colorScheme.error;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.dense ? 0 : Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label != null && widget.showLabel) ...[
            // Visual only — the field itself carries the label for screen
            // readers below.
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(left: Insets.xs),
                child: Text(widget.label!, style: theme.textTheme.labelMedium),
              ),
            ),
            const SizedBox(height: Insets.xs),
          ],
          Semantics(
            label: widget.label,
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: numeric(
                widget.dense
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.bodyLarge,
              ),
              onChanged: (raw) => widget.onChanged(parseNumber(raw)),
              decoration: InputDecoration(
                isDense: widget.dense,
                hintText: widget.hint,
                hintStyle: numeric(
                  widget.dense
                      ? theme.textTheme.bodySmall
                      : theme.textTheme.bodyMedium,
                ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                contentPadding: widget.dense
                    ? const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                        vertical: Insets.md,
                      )
                    : null,
                suffixIcon: widget.suffix == null
                    ? null
                    : _Unit(text: widget.suffix!, dense: widget.dense),
                suffixIconConstraints: const BoxConstraints(minHeight: 0),
                enabledBorder: stateColor == null
                    ? null
                    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.field),
                        borderSide: BorderSide(
                          color: stateColor,
                          width: Borders.focus,
                        ),
                      ),
              ),
            ),
          ),
          if (!widget.dense && message != null) ...[
            const SizedBox(height: Insets.xs),
            Padding(
              padding: const EdgeInsets.only(left: Insets.xs),
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: stateColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The unit sitting at the trailing edge of the box, muted so the value keeps
/// the eye. No divider: nothing in the app is ruled any more.
class _Unit extends StatelessWidget {
  const _Unit({required this.text, required this.dense});

  final String text;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: dense
          ? const EdgeInsets.only(right: Insets.sm, left: Insets.xs)
          : const EdgeInsets.only(right: Insets.lg, left: Insets.sm),
      child: Text(
        text,
        style: numeric(
          theme.textTheme.bodyMedium,
        ).copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// A short free-text field, used for flour and mix-in names.
class NameField extends StatefulWidget {
  const NameField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showLabel = true,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  /// Drops the printed label to a placeholder, so the box lines up with a
  /// `dense` [NumberField] beside it in a row. The label still reaches screen
  /// readers either way.
  final bool showLabel;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(NameField old) {
    super.didUpdateWidget(old);
    if (_controller.text != widget.value) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showLabel) ...[
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(left: Insets.xs),
              child: Text(widget.label, style: theme.textTheme.labelMedium),
            ),
          ),
          const SizedBox(height: Insets.xs),
        ],
        Semantics(
          label: widget.label,
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onChanged: widget.onChanged,
            // Without a printed label it sits in a table row, beside a dense
            // NumberField, so it takes the same size and padding.
            style: widget.showLabel ? null : theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.showLabel ? null : widget.label,
              contentPadding: widget.showLabel
                  ? null
                  : const EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                      vertical: Insets.md,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
