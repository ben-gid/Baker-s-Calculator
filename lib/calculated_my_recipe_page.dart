import "package:dough_calculator/models/field_models.dart";
import "package:dough_calculator/models/recipe_model.dart";
import "package:dough_calculator/notifiers_and_providers/quick_calculater.dart";
import "package:dough_calculator/utils/quick_calculate_recipe.dart";
import "package:dough_calculator/utils/constants.dart";
import "package:dough_calculator/themes.dart";
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalculatedMyRecipePage extends ConsumerStatefulWidget {
  const CalculatedMyRecipePage({super.key});

  @override
  ConsumerState<CalculatedMyRecipePage> createState() =>
      _CalculatedMyRecipePageState();
}

class _CalculatedMyRecipePageState
    extends ConsumerState<CalculatedMyRecipePage> {
  double _scaleMultiplier = 1.0;
  final TextEditingController _customScaleController = TextEditingController();
  Recipe? _recipe;

  Color get _accentColor => _recipe?.colorValue != null
      ? Color(_recipe!.colorValue!)
      : AppColors.primary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get recipe from route args only once
    if (_recipe == null) {
      final args = ModalRoute.of(context)!.settings.arguments as Map;
      _recipe = args["recipe"];

      // Set calculator type after frame builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final calcNotifier = ref.read(quickCalculateProvider.notifier);
          int typeIndex = 0;
          if (_recipe!.doughType == DoughType.sourdough) typeIndex = 1;
          if (_recipe!.doughType == DoughType.preferment) typeIndex = 2;
          calcNotifier.chooseCalculator(typeIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _customScaleController.dispose();
    super.dispose();
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return "${minutes}min";
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return "${hours}h";
    return "${hours}h ${mins}min";
  }

  @override
  Widget build(BuildContext context) {
    if (_recipe == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine the correct calculator function based on the recipe type
    final List<OutputFieldGroup> Function({
      bool isDoughWeightMode,
      bool weightIncludesMixins,
      List<Field>? doughInputs,
      List<Field>? enrichedInputs,
      List<Field>? flourDispersionInputs,
      List<Field>? mixinInputs,
    })
    calculator;

    if (_recipe!.doughType == DoughType.sourdough) {
      calculator = calculateSourDough;
    } else if (_recipe!.doughType == DoughType.preferment) {
      calculator = calculatePreferment;
    } else {
      calculator = calculateYeastDough;
    }

    // Apply scale to the base weight/inputs
    // For Classic, we scale the flour. For Sourdough/Preferment, we scale the total weight.
    final List<Field> scaledDoughInputs = _recipe!.doughInputs.map((f) {
      if (f.valueType == valueGram) {
        return Field(
          label: f.label,
          valueType: f.valueType,
          value: (f.value ?? 0.0) * _scaleMultiplier,
          name: f.name,
        );
      }
      return f;
    }).toList();

    final List<OutputFieldGroup> results = calculator(
      isDoughWeightMode: _recipe!.doughType != DoughType.classic,
      weightIncludesMixins: false,
      doughInputs: scaledDoughInputs,
      enrichedInputs: _recipe!.enrichedInputs,
      flourDispersionInputs: _recipe!.flourDispersionInputs,
      mixinInputs: _recipe!.mixinInputs,
    );

    final totalMinutes = _recipe!.instructions.fold(
      0,
      (sum, s) => sum + s.timeInMinutes,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Recipe Results")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(_recipe!, totalMinutes),
              const SizedBox(height: 20),
              _buildControlsCard(),
              const SizedBox(height: 20),

              // Ingredient groups
              ...results.map((group) {
                return _buildGroupCard(group: group, recipe: _recipe!);
              }),

              _buildPercentagesCard(results, _recipe!),

              // Instructions
              if (_recipe!.instructions.isNotEmpty)
                _buildInstructionsCard(_recipe!.instructions, totalMinutes),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Recipe recipe, int totalMinutes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withValues(alpha: 40 / 255),
            _accentColor.withValues(alpha: 10 / 255),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _accentColor.withValues(alpha: 60 / 255),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  recipe.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (totalMinutes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 40 / 255),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(totalMinutes),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (recipe.description != null && recipe.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              recipe.description!,
              style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMuted, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Scale Recipe",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [0.5, 1.0, 1.5, 2.0, 3.0].map((scale) {
                final isSelected = _scaleMultiplier == scale;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text("${scale}x"),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _scaleMultiplier = scale;
                          _customScaleController.text = "";
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customScaleController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Custom Scale (e.g. 1.2)",
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              final newScale = double.tryParse(val);
              if (newScale != null && newScale > 0) {
                setState(() => _scaleMultiplier = newScale);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard({
    required OutputFieldGroup group,
    required Recipe recipe,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                ...group.values.entries.map((entry) {
                  final String label = entry.key;

                  final isEgg = label.toLowerCase().contains("egg");
                  final String displayValue = isEgg
                      ? entry.value!.toStringAsFixed(0)
                      : "${entry.value?.toStringAsFixed(2)}g";

                  return _buildIngredientRow(label: label, value: displayValue);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(
    List<RecipeStep> instructions,
    int totalMinutes,
  ) {
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
              "Instructions",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: instructions.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final isLast = index == instructions.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accentColor.withValues(alpha: 120 / 255),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.description,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatTime(step.timeInMinutes),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentagesCard(List<OutputFieldGroup> groups, Recipe recipe) {
    final List<Widget> percentageRows = [];
    final Set<String> addedLabels = {};

    // Helper to find original field percentage by checking name and label
    double? findOriginalPct(String resultLabel, List<Field> inputs) {
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

    // Search across all input lists for a matching percentage
    double? findPctAcrossAll(String resultLabel) {
      double? pct = findOriginalPct(resultLabel, recipe.doughInputs);
      if (pct != null) return pct;
      pct = findOriginalPct(resultLabel, recipe.enrichedInputs);
      if (pct != null) return pct;
      pct = findOriginalPct(resultLabel, recipe.mixinInputs);
      return pct;
    }

    for (var group in groups) {
      if (group.name == "Total") continue;

      for (var entry in group.values.entries) {
        final label = entry.key;

        // Custom flours from dispersion
        if (group.name == "Dough" &&
            label == "Flour" &&
            recipe.flourDispersionInputs.isNotEmpty) {
          for (var f in recipe.flourDispersionInputs) {
            if (f.valueType == valuePercent && addedLabels.add(f.label)) {
              percentageRows.add(
                _buildPercentageRow(f.label, "${f.value!.toStringAsFixed(1)}%"),
              );
            }
          }
          continue;
        }

        double? originalPct;
        if (group.name == "Levain") {
          if (label.toLowerCase().contains("total") ||
              (!label.toLowerCase().contains("flour") &&
                  !label.toLowerCase().contains("water"))) {
            originalPct = findOriginalPct(levainLabel, recipe.doughInputs);
          }
        } else if (group.name == "Dough") {
          originalPct = findPctAcrossAll(label);
          if (label.toLowerCase().contains("flour")) {
            originalPct = 100.0;
          }
          if (label.toLowerCase().contains("water") && originalPct == null) {
            originalPct = findOriginalPct(hydrationLabel, recipe.doughInputs);
          }
        } else {
          originalPct = findPctAcrossAll(label);
        }

        final isEgg = label.toLowerCase().contains("egg");
        if (originalPct != null && !isEgg && addedLabels.add(label)) {
          percentageRows.add(
            _buildPercentageRow(label, "${originalPct.toStringAsFixed(1)}%"),
          );
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
}
