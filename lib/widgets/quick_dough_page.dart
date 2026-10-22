import 'package:dough_calculator/repositories/data_to_calculate.dart';
import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/notifiers_and_providers/quick_calculater.dart';
import 'package:dough_calculator/notifiers_and_providers/calculation_mode_provider.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/utils/functions.dart';
import 'package:dough_calculator/utils/quick_fields.dart';
import 'package:dough_calculator/widgets/builders/quick_dough_form_builder.dart';
import 'package:dough_calculator/widgets/dough_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuickDoughPage extends ConsumerStatefulWidget {
  const QuickDoughPage({super.key});

  @override
  ConsumerState<QuickDoughPage> createState() => _QuickDoughPageState();
}

class _QuickDoughPageState extends ConsumerState<QuickDoughPage> {
  var selectedDough = 0;

  void _onDoughSaved(Field field) {
    CalculateData.doughInput.add(field);
  }

  /// choose the calculator based on the dough form
  void onDoughChanged(int? newDoughIndex) {
    setState(() {
      selectedDough = newDoughIndex ?? 0;

      ref.read(quickCalculateProvider.notifier).chooseCalculator(selectedDough);
      debugPrint(newDoughIndex.toString());
    });
  }

  List<FieldGroup> _getDoughType(bool isDoughWeightMode) {
    final doughAsString = convertDoughIndex(selectedDough);
    switch (doughAsString) {
      case yeastBreadlabel:
        if (!isDoughWeightMode) return yeastInputFields;

        // Clone and modify for Dough Weight Mode
        return yeastInputFields.map((group) {
          return FieldGroup(
            groupName: group.groupName,
            fields: group.fields.map((field) {
              // Replace "Flour" field with "Total Dough Weight"
              if (field.label == flourLabel) {
                return Field(
                  label: doughLabel,
                  valueType: valueGram,
                  helperText: "Target total weight of the final dough",
                );
              }
              return field;
            }).toList(),
          );
        }).toList();

      case (sourDoughLabel):
        return sourdoughInputFields;

      case (prefermentLabel):
        return prefermentInputFields;
    }
    throw ArgumentError("index doesnt match label");
  }

  @override
  Widget build(BuildContext context) {
    final isDoughWeightMode = ref.watch(calculationModeProvider);
    final doughAsString = convertDoughIndex(selectedDough);
    final showToggle = doughAsString == yeastBreadlabel;

    return Column(
      children: [
        DoughSelector(
          selectedDough: selectedDough,
          onDoughChanged: onDoughChanged,
        ),
        if (showToggle)
          SwitchListTile(
            title: const Text("Calculate by Dough Weight"),
            value: isDoughWeightMode,
            onChanged: (val) {
              ref.read(calculationModeProvider.notifier).toggle();
            },
          ),
        QuickDoughFormBuilder(
          fieldGroups: _getDoughType(isDoughWeightMode),
          onSaved: _onDoughSaved,
        ),
      ],
    );
  }
}
