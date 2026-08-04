/// Builds a recipe from a handful of choices.
///
/// This is the "generate me a recipe" feature, and it is deliberately a lookup
/// table rather than a model. Baker's percentages are a small, well-understood
/// space: the character of the bread fixes hydration, salt and enrichment, the
/// method fixes the leavening, and add-ins are percentages of flour. The result
/// is always a valid recipe, works offline, and costs nothing to ship.
library;

import 'models/dough_style.dart';
import 'models/recipe_input.dart';

/// What kind of bread, in the terms a baker would actually use.
enum BreadCharacter {
  hearth(
    'Crusty hearth loaf',
    'Open crumb, blistered crust',
    hydration: 78,
    salt: 2,
  ),
  everyday(
    'Everyday loaf',
    'Easy to handle, good for anything',
    hydration: 70,
    salt: 2,
  ),
  sandwich(
    'Soft sandwich loaf',
    'Tight crumb, soft crust',
    hydration: 65,
    salt: 2,
    fat: 6,
    sugar: 5,
  ),
  enriched(
    'Rich and sweet',
    'Brioche, buns, cinnamon rolls',
    hydration: 40,
    salt: 1.8,
    fat: 20,
    sugar: 12,
    eggs: 2,
  ),
  flatbread(
    'Pizza or flatbread',
    'Thin, fast, high heat',
    hydration: 62,
    salt: 2.8,
  );

  const BreadCharacter(
    this.label,
    this.blurb, {
    required this.hydration,
    required this.salt,
    this.fat,
    this.sugar,
    this.eggs,
  });

  final String label;
  final String blurb;
  final double hydration;
  final double salt;
  final double? fat;
  final double? sugar;
  final double? eggs;

  Enrichment? get enrichment => fat == null && sugar == null && eggs == null
      ? null
      : Enrichment(fatPercent: fat, sugarPercent: sugar, eggCount: eggs);
}

/// Optional flour blends offered by the wizard.
enum FlourChoice {
  white('White', []),
  wholeWheat('A little whole wheat', [
    FlourPart(name: 'Bread flour', percent: 85),
    FlourPart(name: 'Whole wheat', percent: 15),
  ]),
  wholegrain('Mostly wholegrain', [
    FlourPart(name: 'Whole wheat', percent: 70),
    FlourPart(name: 'Bread flour', percent: 30),
  ]),
  rye('With rye', [
    FlourPart(name: 'Bread flour', percent: 80),
    FlourPart(name: 'Rye', percent: 20),
  ]);

  const FlourChoice(this.label, this.blend);

  final String label;
  final List<FlourPart> blend;
}

/// Add-ins with a sensible default percentage each.
enum AddIn {
  seeds('Mixed seeds', 12),
  walnuts('Walnuts', 15),
  olives('Olives', 20),
  cheese('Cheese', 15),
  raisins('Raisins', 15),
  herbs('Herbs', 1);

  const AddIn(this.label, this.percent);

  final String label;
  final double percent;

  MixIn get mixIn => MixIn(name: label, percent: percent);
}

class WizardChoices {
  const WizardChoices({
    this.character = BreadCharacter.everyday,
    this.style = DoughStyle.sourdough,
    this.flour = FlourChoice.white,
    this.addIns = const {},
    this.loaves = 1,
  });

  final BreadCharacter character;
  final DoughStyle style;
  final FlourChoice flour;
  final Set<AddIn> addIns;
  final int loaves;

  WizardChoices copyWith({
    BreadCharacter? character,
    DoughStyle? style,
    FlourChoice? flour,
    Set<AddIn>? addIns,
    int? loaves,
  }) => WizardChoices(
    character: character ?? this.character,
    style: style ?? this.style,
    flour: flour ?? this.flour,
    addIns: addIns ?? this.addIns,
    loaves: loaves ?? this.loaves,
  );

  /// A name a person would recognise, e.g. "Sourdough crusty hearth loaf with
  /// walnuts".
  String get suggestedName {
    final base = switch (style) {
      DoughStyle.sourdough => 'Sourdough ${character.label.toLowerCase()}',
      DoughStyle.preferment => '${character.label} (preferment)',
      DoughStyle.classic => character.label,
    };
    if (addIns.isEmpty) return base;
    final names = addIns.map((a) => a.label.toLowerCase()).toList()..sort();
    return '$base with ${_list(names)}';
  }

  static String _list(List<String> items) => switch (items.length) {
    0 => '',
    1 => items.single,
    2 => '${items.first} and ${items.last}',
    _ => '${items.take(items.length - 1).join(', ')} and ${items.last}',
  };
}

/// Per-loaf dough weight by character. Flatbreads are portioned, everything
/// else is a loaf.
double _doughWeight(BreadCharacter character) => switch (character) {
  BreadCharacter.flatbread => 250,
  BreadCharacter.enriched => 700,
  _ => 900,
};

double _flourWeight(BreadCharacter character) => switch (character) {
  BreadCharacter.flatbread => 160,
  _ => 500,
};

RecipeInput composeRecipe(WizardChoices choices) {
  final character = choices.character;

  final base = RecipeInput(
    style: choices.style,
    hydration: character.hydration,
    salt: character.salt,
    enrichment: character.enrichment,
    flourBlend: choices.flour.blend,
    mixIns: [for (final addIn in choices.addIns) addIn.mixIn],
    loaves: choices.loaves,
  );

  return switch (choices.style) {
    DoughStyle.classic => base.copyWith(
      flourWeight: _flourWeight(character),
      // Flatbreads want a long, cold, low-yeast ferment; enriched doughs need
      // extra push to lift all that fat and sugar.
      yeast: switch (character) {
        BreadCharacter.flatbread => 0.2,
        BreadCharacter.enriched => 1.5,
        _ => 1,
      },
    ),
    DoughStyle.sourdough => base.copyWith(
      totalDoughWeight: _doughWeight(character),
      levainPercent: character == BreadCharacter.enriched ? 25 : 20,
      levainHydration: 100,
    ),
    DoughStyle.preferment => base.copyWith(
      totalDoughWeight: _doughWeight(character),
      // Poolish for open crumb, stiffer biga for structure.
      prefermentPercent: character == BreadCharacter.hearth ? 40 : 30,
      prefermentHydration: character == BreadCharacter.hearth ? 100 : 65,
      prefermentYeast: 0.2,
    ),
  };
}
