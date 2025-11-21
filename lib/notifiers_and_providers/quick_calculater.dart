import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/utils/functions.dart';
import 'package:dough_calculator/utils/quick_calculate_recipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Define the provider that holds the current calculator function
final quickCalculateProvider =
    NotifierProvider<QuickCalculateNotifier, List<OutputFieldGroup> Function()>(
      QuickCalculateNotifier.new,
    );

class QuickCalculateNotifier
    extends Notifier<List<OutputFieldGroup> Function()> {
  @override
  List<OutputFieldGroup> Function() build() {
    // initial value
    return calculateYeastDough;
  }

  /// choose the calculator based on the dough form
  void chooseCalculator(int newDoughIndex) {
    final doughAsString = convertDoughIndex(newDoughIndex);

    switch (doughAsString) {
      case yeastBreadlabel:
        state = calculateYeastDough;
        break;

      case sourDoughLabel:
        state = calculateSourDough;
        break;

      case prefermentLabel:
        state = calculatePreferment;
        break;
    }
  }
}
