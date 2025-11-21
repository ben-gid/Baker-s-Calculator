import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/utils/quick_fields.dart';
import 'package:dough_calculator/widgets/builders/build_section.dart';
import 'package:dough_calculator/widgets/builders/quick_form_text_field.dart';
import 'package:flutter/material.dart';

class EnrichedDoughSegment extends StatefulWidget {
  /// creates a segmented button with options of adding:
  /// fat, sugar, egg
  
  /// called when the field is saved; 
  /// allows access to the label + value of the field
  final void Function(Field field) onSaved;

  const EnrichedDoughSegment({
    super.key,
    required  this.onSaved,
  });

  @override
  State<EnrichedDoughSegment> createState() => _EnrichedDoughSegmentState();
}

class _EnrichedDoughSegmentState extends State<EnrichedDoughSegment> {
  Set<String> _enrichedSelected = {};

  bool selected(String value) {
    return _enrichedSelected.contains(value);
  }

  @override
  Widget build(BuildContext context) {
    final fieldsLength = enrichmentInputFields.fields.length;
    return buildSection( 
      title: enrichmentInputFields.groupName,
      children: [
        Padding(
          padding: const EdgeInsetsGeometry.fromLTRB(0, 0, 0, 5),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton(
              multiSelectionEnabled: true,
              showSelectedIcon: false,
              segments: List<ButtonSegment<String>>.generate(fieldsLength, (index) {
                final label = enrichmentInputFields.fields[index].label;
                return ButtonSegment<String>(
                  value: label,
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label),
                    ],
                  ),
                );
              }),
              selected: _enrichedSelected,
              emptySelectionAllowed: true,
              onSelectionChanged: (newSelected) {
                setState(() {
                  _enrichedSelected = newSelected;
                });
              },
            ),
          ),
        ),
        
        ...List<Widget>.generate(fieldsLength, (int index) {
          final field = enrichmentInputFields.fields[index];
          final label = field.label;
          if (selected(label)) {
            return QuickFormTextField(
              field: field, 
              onSaved: widget.onSaved
            );
          }
          return SizedBox();
        }),
      ],
    );
  }
}

class RecipeFormTextFieldPair {
}