import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/notifiers_and_providers/quick_calculater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalculateButton extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final List<Field> doughInput;
  final List<Field> flourDispersionInput;
  final List<Field> enrichedInput;
  final List<Field> mixinInput;

  CalculateButton({
    super.key,
    required this.formKey,
    required this.doughInput,
    required this.flourDispersionInput,
    required this.enrichedInput,
    required this.mixinInput,
  });

  final Map<String, double> calculatedFlourDispersion = {};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.all(5.0),
      child: ElevatedButton(
        onPressed: () {
          final form = formKey.currentState!;
          if (form.validate()) {
            form.save(); // Triggers all onSaved callbacks

            List<OutputFieldGroup> calculatedOutputFields = 
                ref.watch(quickCalculateProvider)();
                
            Navigator.pushNamed(
              context,
              "/calculatedRecipePage",
              arguments: {
                "calculatedOutputFields": calculatedOutputFields,
                "calculatedFlourDispersion": calculatedFlourDispersion,
                "flourDispersionInput": flourDispersionInput,
                "from": "yeast_bread_page",
              },
            );
          }
        },
        child: Text('Calculate'),
      ),
    );
  }
}
