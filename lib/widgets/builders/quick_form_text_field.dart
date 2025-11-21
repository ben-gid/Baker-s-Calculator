import 'package:dough_calculator/models/field_models.dart';
import 'package:flutter/material.dart';

String? _defaultValidator(String? value, String label) {
    if (value == null || value.isEmpty) {
      return "required";
    }
    if (double.tryParse(value) == null) {
      return "$label must be a number";
    }
    return null;
  }

class QuickFormTextField extends StatefulWidget {
  final Field field;
  final void Function(Field) onSaved;
  final String? helper;
  final TextEditingController? controller;
  final String? Function(String? value, String label) validator;

  const QuickFormTextField({
    super.key,
    required this.field,
    required this.onSaved,
    this.helper,
    this.controller,
    validator, 
  }) : validator = validator ?? _defaultValidator;


  @override
  State<QuickFormTextField> createState() => _QuickFormTextFieldState();
}

class _QuickFormTextFieldState extends State<QuickFormTextField> {
  @override
  Widget build(BuildContext context) {
    final label = widget.field.label;
    final helper = widget.field.helperText;
    return Padding(
      padding: EdgeInsets.all(5.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: label,
                errorMaxLines: 3,
              ),
              validator: (value) {
                return widget.validator(value, label);
              },
              onSaved: (val) {
                widget.field.value = double.tryParse(val ?? "");
                widget.onSaved(widget.field);
              },
            ),
          ),
          
        ],
      )
    );
  }

}