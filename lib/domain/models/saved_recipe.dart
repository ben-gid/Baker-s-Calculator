import 'recipe_input.dart';

/// A named, storable recipe. The [input] is the whole recipe — everything else
/// is library metadata.
class SavedRecipe {
  const SavedRecipe({
    required this.id,
    required this.name,
    required this.input,
    this.tags = const [],
    this.notes,
    this.isFavorite = false,
    this.isSystem = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final RecipeInput input;
  final List<String> tags;
  final String? notes;
  final bool isFavorite;

  /// Shipped with the app. Read-only: editing one saves a copy instead.
  final bool isSystem;

  final DateTime createdAt;
  final DateTime updatedAt;

  SavedRecipe copyWith({
    String? id,
    String? name,
    RecipeInput? input,
    List<String>? tags,
    String? notes,
    bool? isFavorite,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SavedRecipe(
    id: id ?? this.id,
    name: name ?? this.name,
    input: input ?? this.input,
    tags: tags ?? this.tags,
    notes: notes ?? this.notes,
    isFavorite: isFavorite ?? this.isFavorite,
    isSystem: isSystem ?? this.isSystem,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// True when [query] matches the name, a tag, or the dough style.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        input.style.label.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'input': input.toJson(),
    if (tags.isNotEmpty) 'tags': tags,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (isFavorite) 'isFavorite': true,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// [isSystem] is never trusted from JSON — it is set by whoever loads the
  /// file, so an imported recipe cannot claim to be built in.
  factory SavedRecipe.fromJson(
    Map<String, dynamic> json, {
    bool isSystem = false,
  }) {
    DateTime date(String key) =>
        DateTime.tryParse(json[key] as String? ?? '') ?? DateTime.now();
    try {
      return SavedRecipe(
        id: json['id'] as String,
        name: json['name'] as String,
        input: RecipeInput.fromJson(json['input'] as Map<String, dynamic>),
        tags: [for (final t in (json['tags'] as List? ?? const [])) t as String],
        notes: json['notes'] as String?,
        isFavorite: json['isFavorite'] as bool? ?? false,
        isSystem: isSystem,
        createdAt: date('createdAt'),
        updatedAt: date('updatedAt'),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed recipe: $e');
    }
  }
}
