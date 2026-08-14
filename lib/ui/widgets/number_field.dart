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
    this.issue,
    this.dense = false,
  });

  final String? label;
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
    final Color? stateColor = issue == null
        ? null
        : isWarning
        ? baking.warn
        : theme.colorScheme.error;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.dense ? 0 : Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label != null) ...[
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
              style: numeric(theme.textTheme.bodyLarge),
              onChanged: (raw) => widget.onChanged(parseNumber(raw)),
              decoration: InputDecoration(
                isDense: widget.dense,
                suffixIcon: widget.suffix == null
                    ? null
                    : _Unit(text: widget.suffix!),
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
  const _Unit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: Insets.lg, left: Insets.sm),
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
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.showLabel ? null : widget.label,
            ),
          ),
        ),
      ],
    );
  }
}
