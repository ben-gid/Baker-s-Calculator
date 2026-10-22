import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/models/recipe_model.dart';
import 'package:dough_calculator/notifiers_and_providers/recipe_provider.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/utils/quick_fields.dart';
import 'package:dough_calculator/themes.dart';
import 'package:dough_calculator/widgets/form_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class RecipeFormPage extends ConsumerStatefulWidget {
  final Recipe? recipeToEdit;
  const RecipeFormPage({super.key, this.recipeToEdit});

  @override
  ConsumerState<RecipeFormPage> createState() => _RecipeFormPageState();
}

class _RecipeFormPageState extends ConsumerState<RecipeFormPage> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;
  late DoughType _selectedDoughType;
  late int? _selectedColorValue;

  late List<Field> _doughInputs;
  late List<Field> _flourDispersionInputs;
  late List<Field> _enrichedInputs;
  late List<Field> _mixinInputs;
  late List<RecipeStep> _instructions;

  @override
  void initState() {
    super.initState();
    final r = widget.recipeToEdit;
    _title = r?.title ?? "";
    _description = r?.description ?? "";
    _selectedDoughType = r?.doughType ?? DoughType.classic;
    _selectedColorValue = r?.colorValue;

    _doughInputs =
        r?.doughInputs.map((f) => _cloneField(f)).toList() ??
        _getInitialDoughInputs();
    _flourDispersionInputs =
        r?.flourDispersionInputs.map((f) => _cloneField(f)).toList() ?? [];
    _enrichedInputs =
        r?.enrichedInputs.map((f) => _cloneField(f)).toList() ??
        _getInitialEnrichmentInputs();
    _mixinInputs = r?.mixinInputs.map((f) => _cloneField(f)).toList() ?? [];
    _instructions =
        r?.instructions
            .map(
              (s) => RecipeStep(
                description: s.description,
                timeInMinutes: s.timeInMinutes,
              ),
            )
            .toList() ??
        [];
  }

  Field _cloneField(Field f) => Field(
    label: f.label,
    valueType: f.valueType,
    hint: f.hint,
    helperText: f.helperText,
    name: f.name,
    value: f.value,
  );

  List<Field> _getInitialDoughInputs() {
    switch (_selectedDoughType) {
      case DoughType.classic:
        return getFieldsFromGroup(yeastInputFields);
      case DoughType.sourdough:
        return getFieldsFromGroup(sourdoughInputFields);
      case DoughType.preferment:
        return getFieldsFromGroup(prefermentInputFields);
    }
  }

  List<Field> _getInitialEnrichmentInputs() {
    return enrichmentInputFields.fields.map((f) => _cloneField(f)).toList();
  }

  void _onDoughTypeChanged(DoughType? type) {
    if (type == null) return;
    setState(() {
      _selectedDoughType = type;
      _doughInputs = _getInitialDoughInputs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeToEdit == null ? "New Recipe" : "Edit Recipe"),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveRecipe),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            FormSection(
              title: "BASIC INFO",
              children: [
                TextFormField(
                  initialValue: _title,
                  decoration: const InputDecoration(
                    labelText: "Recipe Title",
                    hintText: "e.g. Sourdough Boule",
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Required" : null,
                  onSaved: (val) => _title = val ?? "",
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    hintText: "What makes this recipe special?",
                  ),
                  onSaved: (val) => _description = val ?? "",
                ),
              ],
            ),

            FormSection(
              title: "DOUGH TYPE",
              children: [
                const Text(
                  "Select the calculation logic for this recipe.",
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<DoughType>(
                    segments: DoughType.values.map((type) {
                      return ButtonSegment<DoughType>(
                        value: type,
                        label: Text(
                          type.name[0].toUpperCase() + type.name.substring(1),
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    selected: {_selectedDoughType},
                    onSelectionChanged: (Set<DoughType> newSelection) {
                      _onDoughTypeChanged(newSelection.first);
                    },
                  ),
                ),
              ],
            ),

            FormSection(
              title: "APPEARANCE",
              children: [
                Row(
                  children: [
                    const Text(
                      "Recipe Color",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedColorValue != null)
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(_selectedColorValue!),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppColors.recipeColors.length,
                    itemBuilder: (context, index) {
                      final color = AppColors.recipeColors[index];
                      final isSelected =
                          _selectedColorValue == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(
                          () => _selectedColorValue = color.toARGB32(),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.bg,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            FormSection(
              title: "DOUGH PARAMETERS",
              children: _buildFieldEditors(_doughInputs),
            ),

            FormSection(
              title: "ENRICHMENT",
              children: _buildFieldEditors(_enrichedInputs),
            ),

            FormSection(
              title: "MIXINS",
              trailing: IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                ),
                onPressed: () => setState(
                  () => _mixinInputs.add(
                    Field(label: "Mixin", valueType: valuePercent),
                  ),
                ),
              ),
              children: [
                if (_mixinInputs.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "No mixins added yet.",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ..._buildFieldEditors(_mixinInputs),
              ],
            ),

            FormSection(
              title: "INSTRUCTIONS",
              trailing: IconButton(
                icon: const Icon(Icons.playlist_add, color: AppColors.primary),
                onPressed: () => setState(
                  () => _instructions.add(
                    RecipeStep(description: "", timeInMinutes: 0),
                  ),
                ),
              ),
              children: [
                if (_instructions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "Add steps to track your timeline.",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ..._buildInstructionEditors(),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFieldEditors(List<Field> fields) {
    return fields.asMap().entries.map((entry) {
      final index = entry.key;
      final field = entry.value;

      String? helperText;
      if (field.label == hydrationLabel) {
        helperText = "Water weight relative to total flour.";
      } else if (field.label == saltLabel) {
        helperText = "Typically 1.8% to 2.2%.";
      } else if (field.label == levainLabel ||
          field.label == prefermentPercentlabel) {
        helperText = "The portion of flour/water pre-fermented.";
      } else if (field.label == yeastLabel) {
        helperText = "Use 0 for sourdough or long ferments.";
      }

      final isCustomMixin =
          !field.label.contains("Label") && (field.label == "Mixin");

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: field.value?.toString(),
                    decoration: InputDecoration(
                      labelText: field.label,
                      helperText: helperText,
                      helperMaxLines: 2,
                      suffixText: field.valueType == valuePercent
                          ? "%"
                          : (field.valueType == valueGram ? "g" : ""),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSaved: (val) => field.value = double.tryParse(val ?? ""),
                  ),
                ),
                if (fields == _mixinInputs)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      size: 20,
                      color: AppColors.danger,
                    ),
                    onPressed: () => setState(() => fields.removeAt(index)),
                  ),
              ],
            ),
            if (isCustomMixin || field.name != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextFormField(
                  initialValue: field.name,
                  decoration: InputDecoration(
                    labelText: "Custom Label (e.g. Whole Wheat)",
                    hintText: field.label,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onSaved: (val) => field.name = val,
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildInstructionEditors() {
    return _instructions.asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: TextFormField(
                initialValue: step.description,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "e.g. Bulk Fermentation",
                ),
                onChanged: (val) => _instructions[index] = RecipeStep(
                  description: val,
                  timeInMinutes: step.timeInMinutes,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: step.timeInMinutes.toString(),
                decoration: const InputDecoration(
                  labelText: "Time",
                  suffixText: "min",
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => _instructions[index] = RecipeStep(
                  description: step.description,
                  timeInMinutes: int.tryParse(val) ?? 0,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _instructions.removeAt(index)),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _saveRecipe() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final recipe = Recipe(
        id: widget.recipeToEdit?.id ?? const Uuid().v4(),
        title: _title,
        description: _description,
        doughType: _selectedDoughType,
        doughInputs: _doughInputs,
        flourDispersionInputs: _flourDispersionInputs,
        enrichedInputs: _enrichedInputs,
        mixinInputs: _mixinInputs,
        instructions: _instructions,
        colorValue: _selectedColorValue,
      );

      if (widget.recipeToEdit == null) {
        ref.read(recipeProvider.notifier).addRecipe(recipe);
      } else {
        ref.read(recipeProvider.notifier).updateRecipe(recipe);
      }
      Navigator.pop(context);
    }
  }
}
