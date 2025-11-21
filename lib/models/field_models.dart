class Field {
  final String label;
  final String valueType;
  final String? hint;
  String? helperText;
  String? name;
  double? value;

  Field({
    required this.label, 
    required this.valueType,
    this.hint,
    this.helperText,
    this.name,
    this.value, 
  });

  @override
  String toString() {
    return """
      Field Object: {
        label: $label, 
        helperText: $helperText,
        value: $value,
      }
    """;
  }
}

class FieldGroup {
  final String groupName;
  final List<Field> fields;

  FieldGroup({ required this.groupName, required this.fields});
}

Field? getField(String label, List<Field> fields) {
  /// returns the first instance of a Field which label mathes its label.
  try {
    return fields.firstWhere((f) => f.label == label,);
  } catch(_) {
    return null;
  }
  
}

List<Field> getFieldsFromGroup(List<FieldGroup> fieldGroups) {
  List<Field> fields = [];
  for (FieldGroup group in fieldGroups) {
    fields += group.fields;
  }
  return fields;
}

class OutputFieldGroup {
  final String name;
  final Map<String, double?> values;

  OutputFieldGroup({required this.name, required this.values});

  void addValue(String name, double? value) {
    values[name] = value;
  }
}
