import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/widgets/builders/build_section.dart';
import 'package:dough_calculator/widgets/builders/quick_form_text_field.dart';
import 'package:flutter/material.dart';

class QuickDoughFormBuilder extends StatelessWidget {
  final List<FieldGroup> fieldGroups;
  final void Function(Field field) onSaved;

  const QuickDoughFormBuilder({
    super.key,
    required this.fieldGroups,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...fieldGroups.map((group) {
          return buildSection(
            title: group.groupName, 
            children: [
              ...group.fields.map((field) {
                return QuickFormTextField(
                  field: field, 
                  onSaved: onSaved,
                );
              }),
            ],
          );
        }),
      ]
    );
  }
}