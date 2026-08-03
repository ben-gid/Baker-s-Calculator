import 'dough_style.dart';

/// Weight of one "large" egg, used to convert an egg count into grams.
const double gramsPerEgg = 50.0;

/// One flour in a blend. [percent] is a share of the dough's flour, and all
/// parts in a blend are expected to sum to 100.
class FlourPart {
  const FlourPart({required this.name, required this.percent});

  final String name;
  final double percent;

  FlourPart copyWith({String? name, double? percent}) =>
      FlourPart(name: name ?? this.name, percent: percent ?? this.percent);

  Map<String, dynamic> toJson() => {'name': name, 'percent': percent};

  factory FlourPart.fromJson(Map<String, dynamic> json) => FlourPart(
    name: json['name'] as String,
    percent: (json['percent'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is FlourPart && other.name == name && other.percent == percent;

  @override
  int get hashCode => Object.hash(name, percent);
}

/// Seeds, nuts, cheese, olives — anything added as a baker's percentage of
/// flour that is not part of the dough's structure.
class MixIn {
  const MixIn({required this.name, required this.percent});

  final String name;
  final double percent;

  MixIn copyWith({String? name, double? percent}) =>
      MixIn(name: name ?? this.name, percent: percent ?? this.percent);

  Map<String, dynamic> toJson() => {'name': name, 'percent': percent};

  factory MixIn.fromJson(Map<String, dynamic> json) => MixIn(
    name: json['name'] as String,
    percent: (json['percent'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is MixIn && other.name == name && other.percent == percent;

  @override
  int get hashCode => Object.hash(name, percent);
}

/// Fat, sugar and eggs. Every field is optional — an absent field means the
/// baker did not enrich with that ingredient.
class Enrichment {
  const Enrichment({this.fatPercent, this.sugarPercent, this.eggCount});

  final double? fatPercent;
  final double? sugarPercent;

  /// Number of large eggs. Weighs [eggCount] * [gramsPerEgg] grams.
  final double? eggCount;

  bool get isEmpty =>
      fatPercent == null && sugarPercent == null && eggCount == null;

  double get eggGrams => (eggCount ?? 0) * gramsPerEgg;

  Enrichment copyWith({
    double? fatPercent,
    double? sugarPercent,
    double? eggCount,
    bool clearFat = false,
    bool clearSugar = false,
    bool clearEggs = false,
  }) => Enrichment(
    fatPercent: clearFat ? null : (fatPercent ?? this.fatPercent),
    sugarPercent: clearSugar ? null : (sugarPercent ?? this.sugarPercent),
    eggCount: clearEggs ? null : (eggCount ?? this.eggCount),
  );

  Map<String, dynamic> toJson() => {
    if (fatPercent != null) 'fatPercent': fatPercent,
    if (sugarPercent != null) 'sugarPercent': sugarPercent,
    if (eggCount != null) 'eggCount': eggCount,
  };

  factory Enrichment.fromJson(Map<String, dynamic> json) => Enrichment(
    fatPercent: (json['fatPercent'] as num?)?.toDouble(),
    sugarPercent: (json['sugarPercent'] as num?)?.toDouble(),
    eggCount: (json['eggCount'] as num?)?.toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is Enrichment &&
      other.fatPercent == fatPercent &&
      other.sugarPercent == sugarPercent &&
      other.eggCount == eggCount;

  @override
  int get hashCode => Object.hash(fatPercent, sugarPercent, eggCount);
}

/// Everything the baker types in. Immutable, serialisable, and the only input
/// the calculator reads — it holds no UI concerns and no global state.
///
/// Which fields are required depends on [style]; see `validation.dart`. Fields
/// belonging to another style are simply ignored rather than cleared, so
/// switching styles back and forth does not lose typed values.
class RecipeInput {
  const RecipeInput({
    this.style = DoughStyle.sourdough,
    this.flourWeight,
    this.totalDoughWeight,
    this.hydration = 70,
    this.salt = 2,
    this.yeast,
    this.levainPercent,
    this.levainHydration,
    this.prefermentPercent,
    this.prefermentHydration,
    this.prefermentYeast,
    this.enrichment,
    this.flourBlend = const [],
    this.mixIns = const [],
    this.loaves = 1,
  });

  final DoughStyle style;

  /// Total flour, in grams. Used by [DoughStyle.classic] only.
  final double? flourWeight;

  /// Finished dough weight in grams, for one loaf. Used by the inverse styles.
  final double? totalDoughWeight;

  final double hydration;
  final double salt;

  /// Instant yeast, as a percentage of flour. [DoughStyle.classic] only.
  final double? yeast;

  final double? levainPercent;
  final double? levainHydration;

  final double? prefermentPercent;
  final double? prefermentHydration;
  final double? prefermentYeast;

  final Enrichment? enrichment;
  final List<FlourPart> flourBlend;
  final List<MixIn> mixIns;

  /// How many of [totalDoughWeight] (or [flourWeight]) to make.
  final int loaves;

  Enrichment get enrichmentOrEmpty => enrichment ?? const Enrichment();

  RecipeInput copyWith({
    DoughStyle? style,
    double? flourWeight,
    double? totalDoughWeight,
    double? hydration,
    double? salt,
    double? yeast,
    double? levainPercent,
    double? levainHydration,
    double? prefermentPercent,
    double? prefermentHydration,
    double? prefermentYeast,
    Enrichment? enrichment,
    List<FlourPart>? flourBlend,
    List<MixIn>? mixIns,
    int? loaves,
    bool clearEnrichment = false,
  }) => RecipeInput(
    style: style ?? this.style,
    flourWeight: flourWeight ?? this.flourWeight,
    totalDoughWeight: totalDoughWeight ?? this.totalDoughWeight,
    hydration: hydration ?? this.hydration,
    salt: salt ?? this.salt,
    yeast: yeast ?? this.yeast,
    levainPercent: levainPercent ?? this.levainPercent,
    levainHydration: levainHydration ?? this.levainHydration,
    prefermentPercent: prefermentPercent ?? this.prefermentPercent,
    prefermentHydration: prefermentHydration ?? this.prefermentHydration,
    prefermentYeast: prefermentYeast ?? this.prefermentYeast,
    enrichment: clearEnrichment ? null : (enrichment ?? this.enrichment),
    flourBlend: flourBlend ?? this.flourBlend,
    mixIns: mixIns ?? this.mixIns,
    loaves: loaves ?? this.loaves,
  );

  Map<String, dynamic> toJson() => {
    'style': style.name,
    if (flourWeight != null) 'flourWeight': flourWeight,
    if (totalDoughWeight != null) 'totalDoughWeight': totalDoughWeight,
    'hydration': hydration,
    'salt': salt,
    if (yeast != null) 'yeast': yeast,
    if (levainPercent != null) 'levainPercent': levainPercent,
    if (levainHydration != null) 'levainHydration': levainHydration,
    if (prefermentPercent != null) 'prefermentPercent': prefermentPercent,
    if (prefermentHydration != null) 'prefermentHydration': prefermentHydration,
    if (prefermentYeast != null) 'prefermentYeast': prefermentYeast,
    if (enrichment != null && !enrichment!.isEmpty)
      'enrichment': enrichment!.toJson(),
    if (flourBlend.isNotEmpty)
      'flourBlend': flourBlend.map((f) => f.toJson()).toList(),
    if (mixIns.isNotEmpty) 'mixIns': mixIns.map((m) => m.toJson()).toList(),
    'loaves': loaves,
  };

  /// Throws [FormatException] on malformed input — callers importing untrusted
  /// JSON must catch it.
  factory RecipeInput.fromJson(Map<String, dynamic> json) {
    double? num_(String key) => (json[key] as num?)?.toDouble();
    try {
      return RecipeInput(
        style: DoughStyle.fromName(json['style'] as String),
        flourWeight: num_('flourWeight'),
        totalDoughWeight: num_('totalDoughWeight'),
        hydration: num_('hydration') ?? 70,
        salt: num_('salt') ?? 2,
        yeast: num_('yeast'),
        levainPercent: num_('levainPercent'),
        levainHydration: num_('levainHydration'),
        prefermentPercent: num_('prefermentPercent'),
        prefermentHydration: num_('prefermentHydration'),
        prefermentYeast: num_('prefermentYeast'),
        enrichment: json['enrichment'] == null
            ? null
            : Enrichment.fromJson(json['enrichment'] as Map<String, dynamic>),
        flourBlend: [
          for (final part in (json['flourBlend'] as List? ?? const []))
            FlourPart.fromJson(part as Map<String, dynamic>),
        ],
        mixIns: [
          for (final mixIn in (json['mixIns'] as List? ?? const []))
            MixIn.fromJson(mixIn as Map<String, dynamic>),
        ],
        loaves: (json['loaves'] as num?)?.toInt() ?? 1,
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed recipe input: $e');
    } on StateError catch (e) {
      throw FormatException('Unknown dough style: $e');
    }
  }
}
