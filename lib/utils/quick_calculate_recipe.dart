import 'package:dough_calculator/repositories/data_to_calculate.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/models/field_models.dart';
import 'package:flutter/material.dart';

List<OutputFieldGroup> calculateYeastDough({
  bool isDoughWeightMode = false,
  bool weightIncludesMixins = false,
  List<Field>? doughInputs,
  List<Field>? enrichedInputs,
  List<Field>? flourDispersionInputs,
  List<Field>? mixinInputs,
}) {
  debugPrint("yeast");
  final doughIn = doughInputs ?? CalculateData.doughInput;
  final enrichedIn = enrichedInputs ?? CalculateData.enrichedInput;
  final flourDispersionIn =
      flourDispersionInputs ?? CalculateData.flourDispersionInput;
  final mixinIn = mixinInputs ?? CalculateData.mixinInput;

  double flourWeight;

  if (isDoughWeightMode) {
    final double totalDoughWeightInput =
        getField(doughLabel, doughIn)?.value ?? 0;
    final double hydrationPercent =
        getField(hydrationLabel, doughIn)?.value ?? 0;
    final double yeastPercent = getField(yeastLabel, doughIn)?.value ?? 0;
    final double saltPercent = getField(saltLabel, doughIn)?.value ?? 0;

    double? fatPercent = getField(fatLabel, enrichedIn)?.value;
    double? sugarPercent = getField(sugarLabel, enrichedIn)?.value;
    double mixinsTotalPercent = 0;
    for (Field field in mixinIn) {
      mixinsTotalPercent += field.value ?? 0;
    }

    double totalPercentage =
        100 +
        hydrationPercent +
        yeastPercent +
        saltPercent +
        (fatPercent ?? 0) +
        (sugarPercent ?? 0) +
        mixinsTotalPercent;

    double fixedWeight = 0;
    double? eggCount = getField(eggLabel, enrichedIn)?.value;
    if (eggCount != null) {
      fixedWeight += eggCount * eggWeightInGrams;
    }
    flourWeight =
        (totalDoughWeightInput - fixedWeight) / (totalPercentage / 100);
  } else {
    flourWeight = getField(flourLabel, doughIn)?.value ?? 0;
  }

  final double hydrationPercent = getField(hydrationLabel, doughIn)?.value ?? 0;
  final double yeastPercent = getField(yeastLabel, doughIn)?.value ?? 0;
  final double saltPercent = getField(saltLabel, doughIn)?.value ?? 0;

  final water = flourWeight * hydrationPercent / 100;
  final yeast = flourWeight * yeastPercent / 100;
  final salt = flourWeight * saltPercent / 100;

  final doughOutput = OutputFieldGroup(name: doughName, values: {});

  Map<String, double>? flourDispersion = _getFlourDispersion(
    flourWeight,
    flourDispersionIn,
  );
  if (flourDispersion != null) {
    for (var field in flourDispersion.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  } else {
    doughOutput.addValue(
      getField(flourLabel, doughIn)?.name ?? "Flour",
      flourWeight,
    );
  }

  doughOutput.addValue(
    getField(hydrationLabel, doughIn)?.name ?? "Water",
    water,
  );
  doughOutput.addValue(getField(yeastLabel, doughIn)?.name ?? "Yeast", yeast);
  doughOutput.addValue(getField(saltLabel, doughIn)?.name ?? "Salt", salt);

  Map<String, double>? enrichment = _getEnrichment(flourWeight, enrichedIn);
  Map<String, double>? mixins = _getMixins(flourWeight, mixinIn);

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
    if (field.key != eggLabel &&
        field.key != getField(eggLabel, enrichedIn)?.name) {
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

List<OutputFieldGroup> calculateSourDough({
  bool isDoughWeightMode = false,
  bool weightIncludesMixins = false,
  List<Field>? doughInputs,
  List<Field>? enrichedInputs,
  List<Field>? flourDispersionInputs,
  List<Field>? mixinInputs,
}) {
  debugPrint("sourdough");
  final doughIn = doughInputs ?? CalculateData.doughInput;
  final enrichedIn = enrichedInputs ?? CalculateData.enrichedInput;
  final mixinIn = mixinInputs ?? CalculateData.mixinInput;

  final double doughWeight = getField(doughLabel, doughIn)?.value ?? 0;
  final double hydrationPercent = getField(hydrationLabel, doughIn)?.value ?? 0;
  final double saltPercent = getField(saltLabel, doughIn)?.value ?? 0;
  final double levainPercent = getField(levainLabel, doughIn)?.value ?? 0;
  final double levainHydration =
      getField(levainHydrationLabel, doughIn)?.value ?? 0;

  double? fatPercent = getField(fatLabel, enrichedIn)?.value;
  double? sugarPercent = getField(sugarLabel, enrichedIn)?.value;
  double? eggCount = getField(eggLabel, enrichedIn)?.value;

  double mixinsTotalPercent = 0;
  for (Field field in mixinIn) {
    mixinsTotalPercent += field.value ?? 0;
  }

  double doughDenom =
      1 +
      hydrationPercent / 100 +
      saltPercent / 100 +
      ((fatPercent ?? 0) / 100) +
      ((sugarPercent ?? 0) / 100) +
      (weightIncludesMixins ? mixinsTotalPercent / 100 : 0);

  final totalEggWeight = (eggCount ?? 0) * eggWeightInGrams;
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
      getField(levainLabel, doughIn)?.name ?? 'Levain Total': levainTotal,
      'Levain Flour': flourLevain,
      'Levain Water': waterLevain,
    },
  );

  final doughOutput = OutputFieldGroup(name: doughName, values: {});

  Map<String, double>? flourDispersion = _getFlourDispersion(
    flourFromMain,
    flourDispersionInputs ?? CalculateData.flourDispersionInput,
  );
  if (flourDispersion != null) {
    for (var field in flourDispersion.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  } else {
    doughOutput.addValue(
      getField(doughFlourLabel, doughIn)?.name ?? doughFlourLabel,
      flourFromMain,
    );
  }
  doughOutput.addValue(
    getField(hydrationLabel, doughIn)?.name ?? "Water",
    waterFromMain,
  );
  doughOutput.addValue(
    getField(saltLabel, doughIn)?.name ?? "Salt",
    saltWeight,
  );

  Map<String, double>? enrichment = _getEnrichment(flourTotal, enrichedIn);
  Map<String, double>? mixins = _getMixins(flourTotal, mixinIn);

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
  totalDoughWeight += levainTotal;
  for (var field in doughOutput.values.entries) {
    if (field.key != eggOutputLabel &&
        field.key != getField(eggLabel, enrichedIn)?.name) {
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
  bool isDoughWeightMode = false,
  bool weightIncludesMixins = false,
  List<Field>? doughInputs,
  List<Field>? enrichedInputs,
  List<Field>? flourDispersionInputs,
  List<Field>? mixinInputs,
}) {
  debugPrint("preferment");
  final doughIn = doughInputs ?? CalculateData.doughInput;
  final enrichedIn = enrichedInputs ?? CalculateData.enrichedInput;
  final mixinIn = mixinInputs ?? CalculateData.mixinInput;

  final double doughWeight = getField(doughLabel, doughIn)?.value ?? 0;
  final double hydrationPercent = getField(hydrationLabel, doughIn)?.value ?? 0;
  final double saltPercent = getField(saltLabel, doughIn)?.value ?? 0;

  double? fatPercent = getField(fatLabel, enrichedIn)?.value;
  double? sugarPercent = getField(sugarLabel, enrichedIn)?.value;
  double? eggCount = getField(eggLabel, enrichedIn)?.value;

  double mixinsTotalPercent = 0;
  for (Field field in mixinIn) {
    mixinsTotalPercent += field.value ?? 0;
  }

  final double prefermentPercent =
      getField(prefermentPercentlabel, doughIn)?.value ?? 0;
  final double prefermentHydration =
      getField(prefermentHydrationLabel, doughIn)?.value ?? 0;
  final double prefermentYeastPercentage =
      getField(prefermentYeastLabel, doughIn)?.value ?? 0;

  final double prefermentYeastForDenom =
      1 *
      prefermentPercent /
      100 /
      (1 + (prefermentYeastPercentage / 100) + (prefermentHydration / 100)) *
      prefermentYeastPercentage /
      100;

  double doughDenom =
      1 +
      hydrationPercent / 100 +
      saltPercent / 100 +
      prefermentYeastForDenom +
      ((fatPercent ?? 0) / 100) +
      ((sugarPercent ?? 0) / 100) +
      (weightIncludesMixins ? mixinsTotalPercent / 100 : 0);

  final totalEggWeight = (eggCount ?? 0) * eggWeightInGrams;
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
      getField(prefermentPercentlabel, doughIn)?.name ?? 'Preferment Total':
          prefermentTotal,
      'Preferment Flour': flourPreferment,
      'Preferment Water': waterPreferment,
      'Preferment Yeast': yeastPreferment,
    },
  );

  final doughOutput = OutputFieldGroup(name: doughName, values: {});

  Map<String, double>? flourDispersion = _getFlourDispersion(
    flourFromMain,
    flourDispersionInputs ?? CalculateData.flourDispersionInput,
  );
  if (flourDispersion != null) {
    for (var field in flourDispersion.entries) {
      doughOutput.addValue(field.key, field.value);
    }
  } else {
    doughOutput.addValue(
      getField(doughFlourLabel, doughIn)?.name ?? doughFlourLabel,
      flourFromMain,
    );
  }
  doughOutput.addValue(
    getField(hydrationLabel, doughIn)?.name ?? "Water",
    waterFromMain,
  );
  doughOutput.addValue(
    getField(saltLabel, doughIn)?.name ?? "Salt",
    saltWeight,
  );

  Map<String, double>? enrichment = _getEnrichment(flourTotal, enrichedIn);
  Map<String, double>? mixins = _getMixins(flourTotal, mixinIn);

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
  totalDoughWeight += prefermentTotal;
  for (var field in doughOutput.values.entries) {
    if (field.key != eggOutputLabel &&
        field.key != getField(eggLabel, enrichedIn)?.name) {
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

Map<String, double>? _getEnrichment(
  double flourWeight,
  List<Field> enrichedIn,
) {
  if (enrichedIn.isEmpty) return null;
  double? fatPercent = getField(fatLabel, enrichedIn)?.value;
  double? sugarPercent = getField(sugarLabel, enrichedIn)?.value;
  double? eggCount = getField(eggLabel, enrichedIn)?.value;
  final Map<String, double> output = {};
  if (fatPercent != null) {
    output[getField(fatLabel, enrichedIn)?.name ?? "Fat"] =
        flourWeight * fatPercent / 100;
  }
  if (sugarPercent != null) {
    output[getField(sugarLabel, enrichedIn)?.name ?? "Sugar"] =
        flourWeight * sugarPercent / 100;
  }
  if (eggCount != null) {
    output[getField(eggLabel, enrichedIn)?.name ?? eggOutputLabel] = eggCount;
  }
  return output;
}

Map<String, double>? _getFlourDispersion(
  double flourWeight,
  List<Field> flourDispersionIn,
) {
  if (flourDispersionIn.isEmpty) return null;
  final Map<String, double> flourDispersionWeight = {};
  for (Field field in flourDispersionIn) {
    final percentage = field.value ?? 0;
    flourDispersionWeight[field.name ?? field.label] =
        flourWeight * percentage / 100;
  }
  return flourDispersionWeight;
}

Map<String, double>? _getMixins(double flourWeight, List<Field> mixinIn) {
  if (mixinIn.isEmpty) return null;
  final Map<String, double> mixinsWeight = {};
  for (Field field in mixinIn) {
    final percentage = field.value ?? 0;
    mixinsWeight[field.name ?? field.label] = flourWeight * percentage / 100;
  }
  return mixinsWeight;
}
