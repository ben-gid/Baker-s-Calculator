import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../domain/validation.dart';

/// A labelled numeric input wired straight to state — there is no Calculate
/// button, so every keystroke updates the recipe.
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

  /// Strips the label, helper slot and bottom margin so the field fits inside a
  /// row next to another control.
  final bool dense;

  /// `%`, `g`, `°C` — shown inside the field, not in the label.
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

    return Padding(
      padding: EdgeInsets.only(bottom: widget.dense ? 0 : Insets.md),
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        style: theme.textTheme.bodyLarge?.copyWith(
          fontFeatures: tabularFigures,
          fontFamily: numericFont,
        ),
        onChanged: (raw) => widget.onChanged(parseNumber(raw)),
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: widget.suffix,
          isDense: widget.dense,
          helperText: issue == null ? widget.helper : null,
          // Warnings are advisory, so they use the field's helper slot tinted
          // amber rather than the error slot, which would imply it is blocked.
          error: issue == null
              ? null
              : Text(
                  issue.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isWarning ? baking.warn : theme.colorScheme.error,
                  ),
                ),
          enabledBorder: isWarning
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.field),
                  borderSide: BorderSide(color: baking.warn),
                )
              : null,
        ),
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
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

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
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    textCapitalization: TextCapitalization.sentences,
    textInputAction: TextInputAction.next,
    onChanged: widget.onChanged,
    decoration: InputDecoration(labelText: widget.label, isDense: true),
  );
}
