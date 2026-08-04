/// The three fermentation methods the calculator supports.
///
/// [classic] is a *forward* calculation: you give the flour weight and every
/// other ingredient is a percentage of it. The other two are *inverse*: you
/// give the finished dough weight and the flour is solved for.
enum DoughStyle {
  classic('Classic', 'Commercial yeast, straight dough'),
  sourdough('Sourdough', 'Natural levain'),
  preferment('Preferment', 'Poolish, biga or pâte fermentée');

  const DoughStyle(this.label, this.blurb);

  final String label;
  final String blurb;

  /// True when the baker supplies flour weight rather than total dough weight.
  bool get isForward => this == DoughStyle.classic;

  /// Throws [ArgumentError] on an unknown name — callers decoding untrusted
  /// JSON must catch it.
  static DoughStyle fromName(String name) => DoughStyle.values.byName(name);
}
