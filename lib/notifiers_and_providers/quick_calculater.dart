import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/utils/functions.dart';
import 'package:dough_calculator/utils/quick_calculate_recipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Define the provider that holds the current calculator function
final quickCalculateProvider =
    NotifierProvider<
      QuickCalculateNotifier,
      List<OutputFieldGroup> Function({
        bool isDoughWeightMode,
        bool weightIncludesMixins,
        List<Field>? doughInputs,
        List<Field>? enrichedInputs,
        List<Field>? flourDispersionInputs,
        List<Field>? mixinInputs,
      })
    >(QuickCalculateNotifier.new);

class QuickCalculateNotifier
    extends
        Notifier<
          List<OutputFieldGroup> Function({
            bool isDoughWeightMode,
            bool weightIncludesMixins,
            List<Field>? doughInputs,
            List<Field>? enrichedInputs,
            List<Field>? flourDispersionInputs,
            List<Field>? mixinInputs,
          })
        > {
  @override
  List<OutputFieldGroup> Function({
    bool isDoughWeightMode,
    bool weightIncludesMixins,
    List<Field>? doughInputs,
    List<Field>? enrichedInputs,
    List<Field>? flourDispersionInputs,
    List<Field>? mixinInputs,
  })
  build() {
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
