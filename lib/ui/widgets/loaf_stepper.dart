import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// How many loaves: minus, the count, plus. The calculator, a recipe's page and
/// the wizard all scale the same way, so they share this one control.
class LoafStepper extends StatelessWidget {
  const LoafStepper({
    super.key,
    required this.loaves,
    required this.onChanged,
    this.label = 'Loaves',
    this.min = 1,
    this.max,
    this.fewer = 'One fewer loaf',
    this.more = 'One more loaf',
  });

  final int loaves;
  final ValueChanged<int> onChanged;

  /// The bake plan counts its sets of folds with the same control.
  final String label;
  final int min;
  final int? max;
  final String fewer;
  final String more;

  void _set(int next) {
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Expanded rather than Spacer: at narrow widths the label has to give
        // way to the stepper.
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        IconButton.outlined(
          icon: const Icon(Icons.remove),
          tooltip: fewer,
          onPressed: loaves <= min ? null : () => _set(loaves - 1),
        ),
        SizedBox(
          width: 40,
          child: RollingText(
            '$loaves',
            textAlign: TextAlign.center,
            style: numeric(theme.textTheme.titleLarge),
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.add),
          tooltip: more,
          onPressed: max != null && loaves >= max!
              ? null
              : () => _set(loaves + 1),
        ),
      ],
    );
  }
}
