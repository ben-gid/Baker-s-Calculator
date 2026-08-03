/// Desired dough temperature: what temperature should the water be?
///
/// Standard baker's method. The desired dough temperature is multiplied by the
/// number of contributing temperatures, and every temperature you already know
/// is subtracted; what is left is the water.
library;

/// Typical friction gain, in degrees, from mixing. Hand mixing adds almost
/// nothing; a spiral mixer on speed 2 can add 10 °C or more. Bakers calibrate
/// this against their own mixer, so it stays an input rather than a constant.
const double handMixFriction = 1;
const double standMixerFriction = 5;

class DoughTempInputs {
  const DoughTempInputs({
    required this.desiredDoughTemp,
    required this.roomTemp,
    required this.flourTemp,
    this.prefermentTemp,
    this.frictionFactor = handMixFriction,
  });

  final double desiredDoughTemp;
  final double roomTemp;
  final double flourTemp;

  /// Levain or preferment temperature. Omit for a straight dough — it changes
  /// the multiplier, not just the sum.
  final double? prefermentTemp;

  final double frictionFactor;

  /// Room, flour, friction, and the preferment if there is one.
  int get factorCount => prefermentTemp == null ? 3 : 4;
}

class DoughTempResult {
  const DoughTempResult({required this.waterTemp, required this.warning});

  final double waterTemp;

  /// Set when the required water temperature is not reachable in a normal
  /// kitchen, so the UI can suggest chilling the flour or using ice.
  final String? warning;
}

DoughTempResult waterTemperature(DoughTempInputs inputs) {
  final total = inputs.desiredDoughTemp * inputs.factorCount;
  final known =
      inputs.roomTemp +
      inputs.flourTemp +
      (inputs.prefermentTemp ?? 0) +
      inputs.frictionFactor;

  final water = total - known;

  return DoughTempResult(
    waterTemp: water,
    warning: switch (water) {
      < 0 => 'Colder than ice water — chill the flour or add ice to the mix',
      < 4 => 'Use ice water',
      > 60 => 'Too hot — water this warm will kill the yeast',
      _ => null,
    },
  );
}
