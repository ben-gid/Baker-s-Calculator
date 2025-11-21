import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/widgets/builders/build_section.dart';
import 'package:dough_calculator/widgets/builders/build_segment.dart';
import 'package:dough_calculator/widgets/builders/quick_form_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FlourDispersor extends StatefulWidget {
  /// Called each time a flour‐percentage field is saved.
  final void Function(Field field) onSaved;

  const FlourDispersor({
    super.key,
    required this.onSaved,
  });

  @override
  State<StatefulWidget> createState() => _FlourDispersorState();
}

class _FlourDispersorState extends State<FlourDispersor> {
  static const _flourCount = 5;

  /// Currently selected segment index.
  int selectedCount = 1;

  /// Controller list for enforcing flours total to 100%.
  late final List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    controllers = List.generate(_flourCount, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Called when the user picks a new count.
  void onCountChanged(int? newCount) {
    if (newCount == null) return;
    setState(() {
      final oldCount = selectedCount;
      selectedCount = newCount;

      // Clear old controllers:
      for (var i = selectedCount; i < oldCount; i++) {
        controllers[i].clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Returns a CupertinoSlidingSegmentedControl for the user to select flour count.
    /// TextFormFields, to calculate the percentage dispersion,

    final theme = Theme.of(context);
    final Map<int, Widget> floursForSelector = {
      for (int i = 1; i <= _flourCount; i++)
        i: buildSegment(i.toString(), selectedCount == i, theme),
    };

    return buildSection(
      title: "Flour Types",
      children: [
        Padding(
          padding: EdgeInsetsGeometry.fromLTRB(0, 2, 0, 10),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              children: floursForSelector,
              groupValue: selectedCount,
              thumbColor: Theme.of(context).colorScheme.primary,
              onValueChanged: (value) {
                onCountChanged(value);
              },
            ),
          ),
        ),

        if (selectedCount > 1)
          Column(
            children: List<Widget>.generate(selectedCount, (int index) {
              final controller = controllers[index];
              final label = "Flour ${index + 1} (%):";
              final field = Field(label: label, valueType: valuePercent);
              
              return QuickFormTextField(
                field: field,
                onSaved: widget.onSaved,
                controller: controller,
                validator: validator,
              );
              
            }),
          ),
      ],
    );
  }

  String? validator(String? value, String label) {
    if (value == null || value.isEmpty) {
      return "$label required";
    }

    // make sure inut is a number
    double? n = double.tryParse(value);
    if (n == null) return "$label must be a number";

    // assert total percentage == 100%
    double totalFlourPercentage = 0;
    for (var controller in controllers) {
      // if old controllers are cleared it will return null so add 0
      totalFlourPercentage += double.tryParse(controller.text) ?? 0;
    }
    if (totalFlourPercentage != 100) {
      return 'All percentage fields must add up to 100%. '
          'Current total: ${totalFlourPercentage.toStringAsFixed(2)}%';
    }
    return null;
  }
}
