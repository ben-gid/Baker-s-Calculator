import 'package:dough_calculator/models/field_models.dart';

/// model that stores Quick Calculate Page inputs
class CalculateData {
  CalculateData._();
  static final CalculateData instance = CalculateData._();

  // Make each list static:
  static final List<Field> doughInput            = [];
  static final List<Field> flourDispersionInput  = [];
  static final List<Field> enrichedInput         = [];
  static final List<Field> mixinInput            = [];

  // 3) (Optional) If you want static helper methods too:
  static void clearAll() {
    doughInput.clear();
    flourDispersionInput.clear();
    enrichedInput.clear();
    mixinInput.clear();
  }


  static double? getFlourPercentageTotal() {
    if (flourDispersionInput.isEmpty) return null;
    double totalPercentage = 0;
    for (var flourPercent in flourDispersionInput) {
      totalPercentage += flourPercent.value!;
    }
    return totalPercentage;
  }
}

