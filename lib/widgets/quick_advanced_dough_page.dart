import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/utils/quick_calculate_recipe.dart' as CalculateData;
import 'package:dough_calculator/widgets/enriched_dough_segment.dart';
import 'package:dough_calculator/widgets/flour_dispersor.dart';
import 'package:dough_calculator/widgets/mixin_switch.dart';
import 'package:flutter/material.dart';

class QuickAdvancedDoughPage extends StatelessWidget {
  const QuickAdvancedDoughPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FlourDispersor(
          onSaved: onDispersionSaved,
        ),
        EnrichedDoughSegment(
          onSaved: onEnrichedSaved,
        ),
        MixinSwitch(
          onSaved: onMixinSaved,
        ),
      ],
    );
  }
}

void onDispersionSaved(Field field) {
  CalculateData.flourDispersionInput.add(field);
}

void onEnrichedSaved(Field field) {
  CalculateData.enrichedInput.add(field);
}

void onMixinSaved(Field field) {
  CalculateData.mixinInput.add(field);
}