/// Input checking, separated from the calculator so the UI can show problems
/// while the baker types without ever running the math on nonsense.
///
/// [IssueSeverity.error] means `calculate()` would be wrong or would throw.
/// [IssueSeverity.warning] means the recipe is computable but unusual — those
/// are advisory and must never block anything.
library;

import 'models/dough_style.dart';
import 'models/recipe_input.dart';

enum IssueSeverity { error, warning }

/// Identifies which control an issue belongs to, so the UI can render the
/// message under the right field instead of in a banner at the top.
enum RecipeField {
  flourWeight,
  totalDoughWeight,
  hydration,
  salt,
  yeast,
  levainPercent,
  levainHydration,
  prefermentPercent,
  prefermentHydration,
  prefermentYeast,
  fat,
  sugar,
  eggs,
  flourBlend,
  mixIns,
  loaves,
}

class InputIssue {
  const InputIssue(this.field, this.message, this.severity);

  const InputIssue.error(this.field, this.message)
    : severity = IssueSeverity.error;
  const InputIssue.warning(this.field, this.message)
    : severity = IssueSeverity.warning;

  final RecipeField field;
  final String message;
  final IssueSeverity severity;

  @override
  String toString() => '${severity.name}: ${field.name} — $message';
}

extension IssueList on List<InputIssue> {
  bool get hasErrors => any((i) => i.severity == IssueSeverity.error);

  List<InputIssue> forField(RecipeField field) =>
      where((i) => i.field == field).toList();

  /// The message to show under [field] — errors win over warnings.
  InputIssue? firstFor(RecipeField field) {
    final matches = forField(field);
    if (matches.isEmpty) return null;
    return matches.firstWhere(
      (i) => i.severity == IssueSeverity.error,
      orElse: () => matches.first,
    );
  }
}

/// Returns every problem with [input]. An empty list means `calculate()` is
/// safe to call.
List<InputIssue> validate(RecipeInput input) {
  final issues = <InputIssue>[];

  /// An empty box is an error, not a zero — the baker is allowed to clear a
  /// field, they just get no recipe until they refill it.
  void present(double? value, RecipeField field, String label) {
    if (value == null) {
      issues.add(InputIssue.error(field, '$label is required'));
    }
  }

  void required(double? value, RecipeField field, String label) {
    present(value, field, label);
    if (value != null && value <= 0) {
      issues.add(InputIssue.error(field, '$label must be greater than zero'));
    }
  }

  void range(
    double? value,
    RecipeField field, {
    required double min,
    required double max,
    required String label,
    double? warnBelow,
    double? warnAbove,
    String? warning,
  }) {
    if (value == null) return;
    if (value < min || value > max) {
      issues.add(
        InputIssue.error(field, '$label must be between $min and $max'),
      );
      return;
    }
    if (warning != null &&
        ((warnBelow != null && value < warnBelow) ||
            (warnAbove != null && value > warnAbove))) {
      issues.add(InputIssue.warning(field, warning));
    }
  }

  switch (input.style) {
    case DoughStyle.classic:
      required(input.flourWeight, RecipeField.flourWeight, 'Flour weight');
      required(input.yeast, RecipeField.yeast, 'Yeast');
      range(
        input.yeast,
        RecipeField.yeast,
        min: 0,
        max: 10,
        label: 'Yeast',
        warnAbove: 3,
        warning: 'Over 3% yeast ferments very fast and can taste boozy',
      );
    case DoughStyle.sourdough:
      required(
        input.totalDoughWeight,
        RecipeField.totalDoughWeight,
        'Dough weight',
      );
      required(input.levainPercent, RecipeField.levainPercent, 'Levain');
      required(
        input.levainHydration,
        RecipeField.levainHydration,
        'Levain hydration',
      );
      range(
        input.levainPercent,
        RecipeField.levainPercent,
        min: 0,
        max: 100,
        label: 'Levain',
        warnAbove: 40,
        warning: 'Levain above 40% ferments quickly — watch the bulk closely',
      );
      range(
        input.levainHydration,
        RecipeField.levainHydration,
        min: 0,
        max: 300,
        label: 'Levain hydration',
      );
    case DoughStyle.preferment:
      required(
        input.totalDoughWeight,
        RecipeField.totalDoughWeight,
        'Dough weight',
      );
      required(
        input.prefermentPercent,
        RecipeField.prefermentPercent,
        'Preferment',
      );
      required(
        input.prefermentHydration,
        RecipeField.prefermentHydration,
        'Preferment hydration',
      );
      required(
        input.prefermentYeast,
        RecipeField.prefermentYeast,
        'Preferment yeast',
      );
      range(
        input.prefermentPercent,
        RecipeField.prefermentPercent,
        min: 0,
        max: 100,
        label: 'Preferment',
      );
      range(
        input.prefermentHydration,
        RecipeField.prefermentHydration,
        min: 0,
        max: 300,
        label: 'Preferment hydration',
      );
      range(
        input.prefermentYeast,
        RecipeField.prefermentYeast,
        min: 0,
        max: 10,
        label: 'Preferment yeast',
      );
  }

  // Eggs and fat are liquid too, but they are not counted in hydration. A
  // brioche at 40% hydration handles like a much wetter dough, so the "too
  // stiff" warning has to look past the hydration figure alone.
  final enrichmentLiquid =
      (input.enrichmentOrEmpty.fatPercent ?? 0) +
      (input.enrichmentOrEmpty.eggCount ?? 0) * 7;
  present(input.hydration, RecipeField.hydration, 'Hydration');
  present(input.salt, RecipeField.salt, 'Salt');
  range(
    input.hydration,
    RecipeField.hydration,
    min: 0,
    max: 250,
    label: 'Hydration',
    warnBelow: enrichmentLiquid >= 15 ? 0 : 50,
    warnAbove: 95,
    warning: (input.hydration ?? 0) > 95
        ? 'Very slack dough — hard to shape by hand'
        : 'Very stiff dough — this will be hard to mix',
  );
  range(
    input.salt,
    RecipeField.salt,
    min: 0,
    max: 15,
    label: 'Salt',
    warnBelow: 1.4,
    warnAbove: 2.8,
    warning: (input.salt ?? 0) > 2.8
        ? 'Over 2.8% salt slows fermentation noticeably'
        : 'Under 1.4% salt tastes flat and slackens the dough',
  );

  final enrichment = input.enrichment;
  if (enrichment != null) {
    range(
      enrichment.fatPercent,
      RecipeField.fat,
      min: 0,
      max: 100,
      label: 'Fat',
    );
    range(
      enrichment.sugarPercent,
      RecipeField.sugar,
      min: 0,
      max: 100,
      label: 'Sugar',
    );
    final eggs = enrichment.eggCount;
    if (eggs != null && (eggs < 0 || eggs > 24)) {
      issues.add(
        const InputIssue.error(
          RecipeField.eggs,
          'Eggs must be between 0 and 24',
        ),
      );
    }
  }

  if (input.flourBlend.isNotEmpty) {
    if (input.flourBlend.any((part) => part.name.trim().isEmpty)) {
      issues.add(
        const InputIssue.error(RecipeField.flourBlend, 'Name every flour'),
      );
    }
    if (input.flourBlend.any((part) => part.percent == null)) {
      issues.add(
        const InputIssue.error(
          RecipeField.flourBlend,
          'Give every flour a percentage',
        ),
      );
    } else if (input.flourBlend.any((part) => part.percent! < 0)) {
      issues.add(
        const InputIssue.error(
          RecipeField.flourBlend,
          'Flour percentages cannot be negative',
        ),
      );
    } else {
      final total = input.flourBlend.fold(0.0, (sum, p) => sum + p.percent!);
      if ((total - 100).abs() > 0.01) {
        issues.add(
          InputIssue.error(
            RecipeField.flourBlend,
            'Flours must add up to 100% — currently ${_trim(total)}%',
          ),
        );
      }
    }
  }

  if (input.mixIns.any((m) => m.percent == null)) {
    issues.add(
      const InputIssue.error(
        RecipeField.mixIns,
        'Give every mix-in a percentage',
      ),
    );
  } else if (input.mixIns.any((m) => m.percent! < 0)) {
    issues.add(
      const InputIssue.error(
        RecipeField.mixIns,
        'Mix-in percentages cannot be negative',
      ),
    );
  }
  if (input.mixIns.any((m) => m.name.trim().isEmpty)) {
    issues.add(const InputIssue.error(RecipeField.mixIns, 'Name every mix-in'));
  }

  if (input.loaves < 1) {
    issues.add(const InputIssue.error(RecipeField.loaves, 'Make at least one'));
  }

  // The inverse styles divide (doughWeight - eggWeight) by the denominator, so
  // heavy enrichment on a small dough can drive the flour weight to zero or
  // below. Catch it here rather than showing negative grams.
  if (!input.style.isForward && input.totalDoughWeight != null) {
    final remaining =
        input.totalDoughWeight! - input.enrichmentOrEmpty.eggGrams;
    if (remaining <= 0) {
      issues.add(
        InputIssue.error(
          RecipeField.eggs,
          'The eggs alone weigh more than the whole dough',
        ),
      );
    }
  }

  return issues;
}

String _trim(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
}
