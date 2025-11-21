import 'package:dough_calculator/utils/constants.dart';

/// converts the selected dough from dough_selector.dart to a string
String convertDoughIndex(int index) {
  if (index < 0 || index > 2) {
    throw ArgumentError("index: $index isnt within bounds");
  }
  switch (index) {
    case 0:
      return yeastBreadlabel;
    case 1:
      return sourDoughLabel;
    case 2:
      return prefermentLabel;
  }
  return "";
}