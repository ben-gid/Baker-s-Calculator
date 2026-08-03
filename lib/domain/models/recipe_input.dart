import 'dough_style.dart';

/// Weight of one "large" egg, used to convert an egg count into grams.
const double gramsPerEgg = 50.0;

/// "Leave this field alone", so `copyWith(x: null)` can mean *clear it*.
///
/// Without this, a field the baker has emptied is indistinguishable from one
/// they did not mention, the old value sticks, and the text box refills itself
/// mid-edit — you cannot turn 900 into 1000 without going via 91000.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

/// [value] is the sentinel, a number, or null. `num` rather than `double`
/// because an `Object?` parameter gives up Dart's int-to-double coercion, and
/// `copyWith(salt: 2)` must keep meaning 2.0 rather than throwing.
double? _or(Object? value, double? current) =>
    identical(value, _unset) ? current : (value as num?)?.toDouble();

/// One flour in a blend. [percent] is a share of the dough's flour, and all
/// parts in a blend are expected to sum to 100.
class FlourPart {
  const FlourPart({required this.name, required this.percent});

  final String name;

  /// Null while the baker has the box empty — `validate()` blocks it.
  final double? percent;

  FlourPart copyWith({String? name, Object? percent = _unset}) =>
      FlourPart(name: name ?? this.name, percent: _or(percent, this.percent));

  Map<String, dynamic> toJson() => {'name': name, 'percent': percent};

  factory FlourPart.fromJson(Map<String, dynamic> json) => FlourPart(
    name: json['name'] as String,
    percent: (json['percent'] as num?)?.toDouble(),
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
  final double? percent;

  MixIn copyWith({String? name, Object? percent = _unset}) =>
      MixIn(name: name ?? this.name, percent: _or(percent, this.percent));

  Map<String, dynamic> toJson() => {'name': name, 'percent': percent};

  factory MixIn.fromJson(Map<String, dynamic> json) => MixIn(
    name: json['name'] as String,
    percent: (json['percent'] as num?)?.toDouble(),
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
    Object? fatPercent = _unset,
    Object? sugarPercent = _unset,
    Object? eggCount = _unset,
  }) => Enrichment(
    fatPercent: _or(fatPercent, this.fatPercent),
    sugarPercent: _or(sugarPercent, this.sugarPercent),
    eggCount: _or(eggCount, this.eggCount),
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

  /// Water as a percentage of the DOUGH's flour — the flour you weigh into the
  /// bowl, not the total including whatever the levain carries in.
  final double? hydration;

  final double? salt;

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

  /// Passing null to any nullable field clears it; omitting it keeps what is
  /// already there. See [_unset].
  RecipeInput copyWith({
    DoughStyle? style,
    Object? flourWeight = _unset,
    Object? totalDoughWeight = _unset,
    Object? hydration = _unset,
    Object? salt = _unset,
    Object? yeast = _unset,
    Object? levainPercent = _unset,
    Object? levainHydration = _unset,
    Object? prefermentPercent = _unset,
    Object? prefermentHydration = _unset,
    Object? prefermentYeast = _unset,
    Object? enrichment = _unset,
    List<FlourPart>? flourBlend,
    List<MixIn>? mixIns,
    int? loaves,
  }) => RecipeInput(
    style: style ?? this.style,
    flourWeight: _or(flourWeight, this.flourWeight),
    totalDoughWeight: _or(totalDoughWeight, this.totalDoughWeight),
    hydration: _or(hydration, this.hydration),
    salt: _or(salt, this.salt),
    yeast: _or(yeast, this.yeast),
    levainPercent: _or(levainPercent, this.levainPercent),
    levainHydration: _or(levainHydration, this.levainHydration),
    prefermentPercent: _or(prefermentPercent, this.prefermentPercent),
    prefermentHydration: _or(prefermentHydration, this.prefermentHydration),
    prefermentYeast: _or(prefermentYeast, this.prefermentYeast),
    enrichment: identical(enrichment, _unset)
        ? this.enrichment
        : enrichment as Enrichment?,
    flourBlend: flourBlend ?? this.flourBlend,
    mixIns: mixIns ?? this.mixIns,
    loaves: loaves ?? this.loaves,
  );

  Map<String, dynamic> toJson() => {
    'style': style.name,
    if (flourWeight != null) 'flourWeight': flourWeight,
    if (totalDoughWeight != null) 'totalDoughWeight': totalDoughWeight,
    if (hydration != null) 'hydration': hydration,
    if (salt != null) 'salt': salt,
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
