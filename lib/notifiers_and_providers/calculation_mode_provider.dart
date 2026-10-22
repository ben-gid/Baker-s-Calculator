import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalculationModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false; // false = Flour Weight, true = Dough Weight
  }

  void toggle() {
    state = !state;
  }
}

final calculationModeProvider = NotifierProvider<CalculationModeNotifier, bool>(
  CalculationModeNotifier.new,
);
