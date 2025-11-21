import 'package:dough_calculator/repositories/data_to_calculate.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/models/field_models.dart';
import 'package:flutter/material.dart';

final doughInput = CalculateData.doughInput;
final enrichedInput = CalculateData.enrichedInput;
final flourDispersionInput = CalculateData.flourDispersionInput;
final mixinInput = CalculateData.mixinInput;

List<OutputFieldGroup> calculateYeastDough() {
  debugPrint("yeast");
  /// Calculate yeast dough
  final double flourWeight = getField(flourLabel, doughInput)!.value!;
  final double hydrationPercent = getField(hydrationLabel, doughInput)!.value!;
  final double yeastPercent = getField(yeastLabel, doughInput)!.value!;
  final double saltPercent = getField(saltLabel, doughInput)!.value!;

  final water = flourWeight * hydrationPercent / 100;
  final yeast = flourWeight * yeastPercent / 100;
  final salt = flourWeight * saltPercent / 100;

  final doughOutput = OutputFieldGroup(name: doughName, values: {});

  Map<String, double>? flourDispersion = _getFlourDispersion(flourWeight);
  if (flourDispersion != null) {
    for (var field in flourDispersion.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  } else {
    doughOutput.addValue("Flour", flourWeight);
  }

  doughOutput.addValue("Water", water);
  doughOutput.addValue("Yeast", yeast);
  doughOutput.addValue("Salt", salt);

  Map<String, double>? enrichment = _getEnrichment(flourWeight);
  Map<String, double>? mixins = _getMixins(flourWeight);

  if (enrichment != null) {
    for (var field in enrichment.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  }
  if (mixins != null) {
    for (var field in mixins.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  }

  double totalDoughWeight = 0;
  for (var field in doughOutput.values.entries) {
    if (field.key != eggLabel) {
      totalDoughWeight += field.value ?? 0;
    } else {
      final eggCount = field.value ?? 0;
      final eggWeight = eggCount * eggWeightInGrams;
      totalDoughWeight += eggWeight;
    }
  }

  final totalOutput = OutputFieldGroup(
    name: "Total",
    values: {'Total Dough Weight': totalDoughWeight},
  );

  return <OutputFieldGroup>[doughOutput, totalOutput];
}

List<OutputFieldGroup> calculateSourDough({bool weightIncludesMixins = false}) {
  debugPrint("sourdough");
  final double doughWeight = getField(doughLabel, doughInput)!.value!;
  final double hydrationPercent = getField(hydrationLabel, doughInput)!.value!;
  final double saltPercent = getField(saltLabel, doughInput)!.value!;
  final double levainPercent = getField(levainLabel, doughInput)!.value!;
  final double levainHydration = getField(
    levainHydrationLabel,
    doughInput,
  )!.value!;

  double? fatPercent = getField(fatLabel, enrichedInput)?.value;
  double? sugarPercent = getField(sugarLabel, enrichedInput)?.value;
  double? eggCount = getField(eggLabel, enrichedInput)?.value;

  double mixinsTotalPercent = 0;
  for (Field field in mixinInput) {
    mixinsTotalPercent += field.value ?? 0;
  }

  double doughDenom =
      1 +
      hydrationPercent / 100 +
      saltPercent / 100 +
      ((fatPercent ?? 0) / 100) +
      ((sugarPercent ?? 0) / 100) +
      (weightIncludesMixins ? mixinsTotalPercent / 100 : 0);
  // egg is calculated later

  final totalEggWeight = (eggCount ?? 0) * eggWeightInGrams;

  /// Calculate
  // subtract eggs from dough weight before dividing denom
  final flourTotal = (doughWeight - totalEggWeight) / doughDenom;
  final waterTotal = flourTotal * hydrationPercent / 100;
  final levainTotal = flourTotal * levainPercent / 100;

  final flourLevain = levainTotal / (1 + levainHydration / 100);
  final waterLevain = levainTotal - flourLevain;

  final saltWeight = flourTotal * saltPercent / 100;

  final flourFromMain = flourTotal - flourLevain;
  final waterFromMain = waterTotal - waterLevain;

  final levainOutput = OutputFieldGroup(
    name: "Levain",
    values: {
      'Levain Flour': flourLevain,
      'Levain Water': waterLevain,
      'Levain Total': levainTotal,
    },
  );

  final doughOutput = OutputFieldGroup(name: doughName, values: {});

  Map<String, double>? flourDispersion = _getFlourDispersion(flourFromMain);
  if (flourDispersion != null) {
    for (var field in flourDispersion.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  } else {
    doughOutput.addValue(doughFlourLabel, flourFromMain);
  }
  doughOutput.addValue("Water", waterFromMain);
  doughOutput.addValue("Salt", saltWeight);

  Map<String, double>? enrichment = _getEnrichment(flourTotal);
  Map<String, double>? mixins = _getMixins(flourTotal);

  if (enrichment != null) {
    for (var field in enrichment.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  }
  if (mixins != null) {
    for (var field in mixins.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  }

  // calculate total weight by adding levain and dough
  double totalDoughWeight = 0;
  totalDoughWeight += levainTotal;
  for (var field in doughOutput.values.entries) {
    if (field.key != eggOutputLabel) {
      totalDoughWeight += field.value ?? 0;
    } else {
      totalDoughWeight += totalEggWeight;
    }
  }

  final totalOutput = OutputFieldGroup(
    name: "Total",
    values: {
      'Total Dough Weight': totalDoughWeight,
      'Flour Total': flourTotal,
      'Water Total': waterTotal,
    },
  );

  return <OutputFieldGroup>[levainOutput, doughOutput, totalOutput];
}

List<OutputFieldGroup> calculatePreferment({
  bool weightIncludesMixins = false,
}) {
  debugPrint("preferment");
  final double doughWeight = getField(doughLabel, doughInput)!.value!;
  final double hydrationPercent = getField(hydrationLabel, doughInput)!.value!;
  final double saltPercent = getField(saltLabel, doughInput)!.value!;

  double? fatPercent = getField(fatLabel, enrichedInput)?.value;
  double? sugarPercent = getField(sugarLabel, enrichedInput)?.value;
  double? eggCount = getField(eggLabel, enrichedInput)?.value;

  double mixinsTotalPercent = 0;
  for (Field field in mixinInput) {
    mixinsTotalPercent += field.value ?? 0;
  }

  final double prefermentPercent = getField(
    prefermentPercentlabel,
    doughInput,
  )!.value!;
  final double prefermentHydration = getField(
    prefermentHydrationLabel,
    doughInput,
  )!.value!;
  final double prefermentYeastPercentage = getField(
    prefermentYeastLabel,
    doughInput,
  )!.value!;

  //calculate yeast percentage relative to flour in total dough
  final double prefermentYeastForDenom =
      1 *
      prefermentPercent /
      100 // gets preferment relative to total flour
      /
      (1 +
          (prefermentYeastPercentage / 100) +
          (prefermentHydration / 100)) // gets flour in preferment
      *
      prefermentYeastPercentage /
      100; // yeast in preferment

  double doughDenom =
      1 +
      hydrationPercent / 100 +
      saltPercent / 100 +
      prefermentYeastForDenom +
      ((fatPercent ?? 0) / 100) +
      ((sugarPercent ?? 0) / 100) +
      (weightIncludesMixins ? mixinsTotalPercent / 100 : 0);
  // egg is calculated later

  final totalEggWeight = (eggCount ?? 0) * eggWeightInGrams;

  /// Calculate
  // subtract eggs from dough weight before dividing denom
  final flourTotal = (doughWeight - totalEggWeight) / doughDenom;
  final waterTotal = flourTotal * hydrationPercent / 100;
  final prefermentTotal = flourTotal * prefermentPercent / 100;

  final flourPreferment =
      prefermentTotal /
      (1 + prefermentHydration / 100 + prefermentYeastPercentage / 100);
  final waterPreferment = flourPreferment * prefermentHydration / 100;
  final yeastPreferment = flourPreferment * prefermentYeastPercentage / 100;

  final saltWeight = flourTotal * saltPercent / 100;

  final flourFromMain = flourTotal - flourPreferment;
  final waterFromMain = waterTotal - waterPreferment;

  final prefermentOutput = OutputFieldGroup(
    name: "Preferment",
    values: {
      'Preferment Flour': flourPreferment,
      'Preferment Water': waterPreferment,
      'Preferment Yeast': yeastPreferment,
      'Preferment Total': prefermentTotal,
    },
  );

  final doughOutput = OutputFieldGroup(name: doughName, values: {});

  Map<String, double>? flourDispersion = _getFlourDispersion(flourFromMain);
  if (flourDispersion != null) {
    for (var field in flourDispersion.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  } else {
    doughOutput.addValue(doughFlourLabel, flourFromMain);
  }
  doughOutput.addValue("Water", waterFromMain);
  doughOutput.addValue("Salt", saltWeight);

  Map<String, double>? enrichment = _getEnrichment(flourTotal);
  Map<String, double>? mixins = _getMixins(flourTotal);

  if (enrichment != null) {
    for (var field in enrichment.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  }
  if (mixins != null) {
    for (var field in mixins.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  }

  // calculate total weight by adding preferment and dough
  double totalDoughWeight = 0;
  totalDoughWeight += prefermentTotal;
  for (var field in doughOutput.values.entries) {
    if (field.key != eggOutputLabel) {
      totalDoughWeight += field.value ?? 0;
    } else {
      totalDoughWeight += totalEggWeight;
    }
  }

  final totalOutput = OutputFieldGroup(
    name: "Total",
    values: {
      'Total Dough Weight': totalDoughWeight,
      'Flour Total': flourTotal,
      'Water Total': waterTotal,
    },
  );

  return <OutputFieldGroup>[prefermentOutput, doughOutput, totalOutput];
}

Map<String, double>? _getEnrichment(double flourWeight) {
  if (enrichedInput.isEmpty) return null;

  double? fatPercent = getField(fatLabel, enrichedInput)?.value;
  double? sugarPercent = getField(sugarLabel, enrichedInput)?.value;
  double? eggCount = getField(eggLabel, enrichedInput)?.value;

  final Map<String, double> output = {};

  if (fatPercent != null) {
    output["Fat"] = flourWeight * fatPercent / 100;
  }
  if (sugarPercent != null) {
    output["Sugar"] = flourWeight * sugarPercent / 100;
  }
  if (eggCount != null) {
    // still returns count; convert when summing weights
    output[eggOutputLabel] = eggCount;
  }

  return output;
}

Map<String, double>? _getFlourDispersion(double flourWeight) {
  if (flourDispersionInput.isEmpty) return null;

  final Map<String, double> flourDispersionWeight = {};
  for (Field field in flourDispersionInput) {
    final percentage = field.value ?? 0;
    flourDispersionWeight[field.label] = flourWeight * percentage / 100;
  }

  return flourDispersionWeight;
}

Map<String, double>? _getMixins(double flourWeight) {
  if (mixinInput.isEmpty) return null;

  final Map<String, double> mixinsWeight = {};
  for (Field field in mixinInput) {
    final percentage = field.value ?? 0;
    mixinsWeight[field.label] = flourWeight * percentage / 100;
  }

  return mixinsWeight;
}
