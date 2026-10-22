import "package:dough_calculator/repositories/data_to_calculate.dart";
import "package:dough_calculator/models/field_models.dart";
import "package:dough_calculator/utils/constants.dart";
import "package:dough_calculator/themes.dart";
import 'package:flutter/material.dart';

class CalculatedRecipePage extends StatefulWidget {
  const CalculatedRecipePage({super.key});

  @override
  State<CalculatedRecipePage> createState() => _CalculatedRecipePageState();
}

class _CalculatedRecipePageState extends State<CalculatedRecipePage> {
  // Snapshot the inputs at page creation so they survive CalculateData.clearAll()
  late final List<Field> _doughInputs;
  late final List<Field> _enrichedInputs;
  late final List<Field> _mixinInputs;
  bool _inputsCaptured = false;

  void _captureInputs() {
    if (!_inputsCaptured) {
      _doughInputs = List.of(CalculateData.doughInput);
      _enrichedInputs = List.of(CalculateData.enrichedInput);
      _mixinInputs = List.of(CalculateData.mixinInput);
      _inputsCaptured = true;
    }
  }

  /// Find the original baker's percentage for a result label.
  /// Group-aware: handles "Total", "Levain", "Dough" groups differently.
  double? _findOriginalPct(String resultLabel, String groupName) {
    // Total group never shows percentages
    if (groupName == "Total") return null;

    // Levain group: "Levain Total" maps to levain %
    if (groupName == "Levain") {
      if (resultLabel.toLowerCase().contains("total") ||
          (!resultLabel.toLowerCase().contains("flour") &&
              !resultLabel.toLowerCase().contains("water"))) {
        return _searchInputs(levainLabel, _doughInputs);
      }
      // Levain Flour and Levain Water are derived — no direct %
      return null;
    }

    // For Dough and any other group, search all input lists
    double? pct = _searchInputs(resultLabel, _doughInputs);
    if (pct != null) return pct;

    // Special case: Flour is always 100% in baker's math
    if (resultLabel.toLowerCase().contains("flour")) return 100.0;

    // Special case: "Water" maps to Hydration
    if (resultLabel.toLowerCase().contains("water")) {
      final hydField = getField(hydrationLabel, _doughInputs);
      if (hydField != null && hydField.valueType == valuePercent) {
        return hydField.value;
      }
    }

    // Check enriched inputs
    pct = _searchInputs(resultLabel, _enrichedInputs);
    if (pct != null) return pct;

    // Check mixin inputs
    pct = _searchInputs(resultLabel, _mixinInputs);
    if (pct != null) return pct;

    return null;
  }

  double? _searchInputs(String resultLabel, List<Field> inputs) {
    try {
      final field = inputs.firstWhere(
        (f) =>
            (f.name != null && resultLabel.contains(f.name!)) ||
            resultLabel.contains(f.label) ||
            f.label.contains(resultLabel),
      );
      return field.valueType == valuePercent ? field.value : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _captureInputs();

    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final List<OutputFieldGroup> calculatedOutputFields =
        args["calculatedOutputFields"];
    final Map<String, double> calculatedFlourDispersion =
        args["calculatedFlourDispersion"];
    final List<Field> flourDispersionInput = args["flourDispersionInput"];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            CalculateData.clearAll();
            Navigator.pop(context);
          },
        ),
        title: const Text("Results"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...calculatedOutputFields.map((group) {
                return _buildGroupCard(
                  context,
                  group: group,
                  flourDispersionInput: flourDispersionInput,
                  calculatedFlourDispersion: calculatedFlourDispersion,
                );
              }),
              _buildPercentagesCard(
                calculatedOutputFields,
                flourDispersionInput,
                calculatedFlourDispersion,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context, {
    required OutputFieldGroup group,
    required List<Field> flourDispersionInput,
    required Map<String, double> calculatedFlourDispersion,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMuted, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgLight.withValues(alpha: 120 / 255),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Text(
              group.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Ingredient rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                ...group.values.entries.map((entry) {
                  // Flour dispersion case
                  if (flourDispersionInput.isNotEmpty &&
                      group.name == "Dough" &&
                      entry.key == "Flour") {
                    return Column(
                      children: [
                        ...calculatedFlourDispersion.entries.map((e) {
                          final String displayValue =
                              "${e.value.toStringAsFixed(2)}g";

                          return _buildIngredientRow(
                            label: e.key,
                            value: displayValue,
                          );
                        }),
                      ],
                    );
                  }

                  final isEgg = entry.key.toLowerCase().contains("egg");
                  final String displayValue = isEgg
                      ? entry.value!.toStringAsFixed(0)
                      : "${entry.value?.toStringAsFixed(2)}g";

                  return _buildIngredientRow(
                    label: entry.key,
                    value: displayValue,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentagesCard(
    List<OutputFieldGroup> groups,
    List<Field> flourDispersionInput,
    Map<String, double> calculatedFlourDispersion,
  ) {
    final List<Widget> percentageRows = [];
    final Set<String> addedLabels = {};

    for (var group in groups) {
      if (group.name == "Total") continue;

      for (var entry in group.values.entries) {
        final label = entry.key;

        // Flour dispersion case
        if (flourDispersionInput.isNotEmpty &&
            group.name == "Dough" &&
            label == "Flour") {
          for (var e in calculatedFlourDispersion.entries) {
            final field = getField(e.key, flourDispersionInput);
            if (field != null && field.valueType == valuePercent) {
              if (addedLabels.add(e.key)) {
                percentageRows.add(
                  _buildPercentageRow(
                    e.key,
                    "${field.value!.toStringAsFixed(1)}%",
                  ),
                );
              }
            }
          }
          continue;
        }

        final isEgg = label.toLowerCase().contains("egg");
        final double? originalPct = _findOriginalPct(label, group.name);

        if (originalPct != null && !isEgg) {
          if (addedLabels.add(label)) {
            percentageRows.add(
              _buildPercentageRow(label, "${originalPct.toStringAsFixed(1)}%"),
            );
          }
        }
      }
    }

    if (percentageRows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMuted, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgLight.withValues(alpha: 120 / 255),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: const Text(
              "Baker's Percentages",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(children: percentageRows),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageRow(String label, String percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          Text(
            percentage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
