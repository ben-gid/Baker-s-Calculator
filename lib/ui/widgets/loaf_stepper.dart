import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// How many loaves: minus, the count, plus. The calculator, a recipe's page and
/// the wizard all scale the same way, so they share this one control.
class LoafStepper extends StatelessWidget {
  const LoafStepper({super.key, required this.loaves, required this.onChanged});

  final int loaves;
  final ValueChanged<int> onChanged;

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
        Expanded(child: Text('Loaves', style: theme.textTheme.bodyMedium)),
        IconButton.outlined(
          icon: const Icon(Icons.remove),
          tooltip: 'One fewer loaf',
          onPressed: loaves <= 1 ? null : () => _set(loaves - 1),
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
          tooltip: 'One more loaf',
          onPressed: () => _set(loaves + 1),
        ),
      ],
    );
  }
}
