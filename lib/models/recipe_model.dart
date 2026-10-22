import 'package:dough_calculator/models/field_models.dart';

enum DoughType { classic, sourdough, preferment }

class RecipeStep {
  final String description;
  final int timeInMinutes;

  RecipeStep({required this.description, required this.timeInMinutes});

  Map<String, dynamic> toJson() => {
    'description': description,
    'timeInMinutes': timeInMinutes,
  };

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    description: json['description'],
    timeInMinutes: json['timeInMinutes'],
  );
}

class Recipe {
  final String id;
  final String title;
  final String? description;
  final DoughType doughType;
  final List<Field> doughInputs;
  final List<Field> flourDispersionInputs;
  final List<Field> enrichedInputs;
  final List<Field> mixinInputs;
  final List<RecipeStep> instructions;
  final bool isDefault;
  final int? colorValue;

  Recipe({
    required this.id,
    required this.title,
    this.description,
    required this.doughType,
    required this.doughInputs,
    required this.flourDispersionInputs,
    required this.enrichedInputs,
    required this.mixinInputs,
    this.instructions = const [],
    this.isDefault = false,
    this.colorValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'doughType': doughType.index,
      'doughInputs': doughInputs.map((f) => f.toJson()).toList(),
      'flourDispersionInputs': flourDispersionInputs
          .map((f) => f.toJson())
          .toList(),
      'enrichedInputs': enrichedInputs.map((f) => f.toJson()).toList(),
      'mixinInputs': mixinInputs.map((f) => f.toJson()).toList(),
      'instructions': instructions.map((s) => s.toJson()).toList(),
      'isDefault': isDefault,
      'colorValue': colorValue,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    doughType: DoughType.values[json['doughType']],
    doughInputs: (json['doughInputs'] as List)
        .map((f) => Field.fromJson(f))
        .toList(),
    flourDispersionInputs: (json['flourDispersionInputs'] as List)
        .map((f) => Field.fromJson(f))
        .toList(),
    enrichedInputs: (json['enrichedInputs'] as List)
        .map((f) => Field.fromJson(f))
        .toList(),
    mixinInputs: (json['mixinInputs'] as List)
        .map((f) => Field.fromJson(f))
        .toList(),
    instructions: (json['instructions'] as List)
        .map((s) => RecipeStep.fromJson(s))
        .toList(),
    isDefault: json['isDefault'] ?? false,
    colorValue: json['colorValue'],
  );
}
