import 'package:bakers_calculator/core/formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grams pass straight through', () {
    expect(toGrams(500, MassUnit.grams), 500);
    expect(fromGrams(500, MassUnit.grams), 500);
  });

  test('a typed ounce weight survives the trip through grams exactly', () {
    // NumberField retypes its box whenever the value differs from the text,
    // so the round trip has to land back on the very number typed.
    for (final typed in [1.0, 17.6, 20.0, 35.27, 0.5]) {
      final grams = toGrams(typed, MassUnit.ounces);
      expect(fromGrams(grams, MassUnit.ounces), typed);
    }
    expect(toGrams(1, MassUnit.ounces), closeTo(28.3495, 0.0001));
  });

  test('clock reads a.m./p.m. by default and 24-hour on request', () {
    final midnight = DateTime(2026, 1, 1, 0, 5);
    final noon = DateTime(2026, 1, 1, 12, 0);
    final evening = DateTime(2026, 1, 1, 21, 30);
    expect(formatClock(midnight), '12:05 a.m.');
    expect(formatClock(noon), '12:00 p.m.');
    expect(formatClock(evening), '9:30 p.m.');
    expect(formatClock(midnight, use24Hour: true), '00:05');
    expect(formatClock(evening, use24Hour: true), '21:30');
  });
}
