/// Number formatting for a kitchen, not a spreadsheet.
///
/// The engine works in exact doubles; this is the only place they get rounded,
/// and rounding is deliberately coarse — nobody weighs 366.1017 g of flour.
library;

enum MassUnit {
  grams('g', 'Grams'),
  ounces('oz', 'Ounces');

  const MassUnit(this.symbol, this.label);

  final String symbol;
  final String label;

  static MassUnit fromName(String? name) =>
      MassUnit.values.asNameMap()[name] ?? MassUnit.grams;
}

const double _gramsPerOunce = 28.349523125;

/// Formats a weight with its unit, e.g. `842 g` or `29.70 oz`.
///
/// Grams keep one decimal below 10 g — salt and yeast live there and a whole
/// gram is a big relative error — and are whole numbers above it.
String formatMass(double grams, MassUnit unit) =>
    '${_formatMassValue(grams, unit)} ${unit.symbol}';

String _formatMassValue(double grams, MassUnit unit) {
  if (unit == MassUnit.ounces) {
    return (grams / _gramsPerOunce).toStringAsFixed(2);
  }
  final rounded = grams.abs() < 10
      ? grams.toStringAsFixed(1)
      : grams.round().toString();
  // 9.0 reads as a false precision; 9 does not.
  return rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
}

/// `78%`, `2.5%`, `0.2%` — up to one decimal, never a trailing `.0`.
String formatPercent(double percent, {int decimals = 1}) {
  final fixed = percent.toStringAsFixed(decimals);
  final trimmed = fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
  return '${trimmed.isEmpty ? '0' : trimmed}%';
}

/// `2 eggs`, `1 egg`, `1.5 eggs`.
String formatCount(double count, String singular, String plural) {
  final whole = count == count.roundToDouble();
  final text = whole ? count.round().toString() : count.toStringAsFixed(1);
  return '$text ${count == 1 ? singular : plural}';
}

/// `4 h 30 m`, `45 m`, `2 h`.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes m';
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes m';
}

/// `09:30` in 24-hour form — unambiguous on a timeline read at 2am.
String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Parses a number the way a person types it, tolerating a comma decimal
/// separator and surrounding spaces. Returns null if it isn't a number.
double? parseNumber(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
