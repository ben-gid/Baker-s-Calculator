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

/// [prefermentTemp] is null for a straight dough — a levain or preferment
/// changes the multiplier, not just the sum.
///
/// The returned `warning` is set when the water temperature is not reachable in
/// a normal kitchen, so the UI can suggest chilling the flour or using ice.
({double waterTemp, String? warning}) waterTemperature({
  required double desiredDoughTemp,
  required double roomTemp,
  required double flourTemp,
  double? prefermentTemp,
  double frictionFactor = handMixFriction,
}) {
  // Room, flour, friction, and the preferment if there is one.
  final factors = prefermentTemp == null ? 3 : 4;
  final water =
      desiredDoughTemp * factors -
      (roomTemp + flourTemp + (prefermentTemp ?? 0) + frictionFactor);

  return (
    waterTemp: water,
    warning: switch (water) {
      < 0 => 'Colder than ice water — chill the flour or add ice to the mix',
      < 4 => 'Use ice water',
      > 60 => 'Too hot — water this warm will kill the yeast',
      _ => null,
    },
  );
}
