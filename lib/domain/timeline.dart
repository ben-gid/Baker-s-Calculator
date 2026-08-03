/// Turns a recipe into a schedule.
///
/// Fermentation times are estimates, not physics: they assume a room around
/// 22-24 °C and are derived from how much leavening the recipe carries. Bakers
/// are expected to adjust them — every step's duration is editable, and the
/// whole plan hangs off one start time.
library;

import 'models/dough_style.dart';
import 'models/recipe_input.dart';

enum StepKind {
  preferment,
  autolyse,
  mix,
  bulk,
  fold,
  preshape,
  bench,
  shape,
  proof,
  bake,
}

class BakeStep {
  const BakeStep({
    required this.kind,
    required this.title,
    required this.duration,
    this.detail,
  });

  final StepKind kind;
  final String title;

  /// How long this step lasts. The next step starts when it ends.
  final Duration duration;

  final String? detail;

  /// Worth a notification. Mixing straight after autolyse is worth an alert;
  /// "shape" taking ten minutes is not something to be reminded about.
  bool get isAlarm => switch (kind) {
    StepKind.fold ||
    StepKind.bulk ||
    StepKind.proof ||
    StepKind.preferment ||
    StepKind.autolyse ||
    StepKind.bake => true,
    _ => false,
  };

  BakeStep withDuration(Duration duration) => BakeStep(
    kind: kind,
    title: title,
    duration: duration,
    detail: detail,
  );
}

/// A step pinned to a wall-clock time.
class ScheduledStep {
  const ScheduledStep({
    required this.step,
    required this.startsAt,
    required this.endsAt,
  });

  final BakeStep step;
  final DateTime startsAt;
  final DateTime endsAt;
}

class BakeTimeline {
  const BakeTimeline(this.steps);

  final List<BakeStep> steps;

  Duration get total =>
      steps.fold(Duration.zero, (sum, step) => sum + step.duration);

  BakeTimeline replaceStep(int index, Duration duration) => BakeTimeline([
    for (var i = 0; i < steps.length; i++)
      if (i == index) steps[i].withDuration(duration) else steps[i],
  ]);

  /// Lays the steps end to end from [start].
  List<ScheduledStep> scheduleFrom(DateTime start) {
    final scheduled = <ScheduledStep>[];
    var cursor = start;
    for (final step in steps) {
      final end = cursor.add(step.duration);
      scheduled.add(ScheduledStep(step: step, startsAt: cursor, endsAt: end));
      cursor = end;
    }
    return scheduled;
  }

  /// The start time that makes the bake finish at [finish] — for planning
  /// backwards from "bread out of the oven by 8am".
  DateTime startForFinish(DateTime finish) => finish.subtract(total);
}

Duration _hours(double value) =>
    Duration(minutes: (value * 60).round().clamp(1, 60 * 48));

BakeTimeline buildTimeline(RecipeInput input) {
  final enrichment = input.enrichmentOrEmpty;

  // Fat, sugar and eggs all slow yeast down; heavily enriched doughs take
  // noticeably longer than a lean loaf with the same leavening.
  final richness =
      (enrichment.fatPercent ?? 0) +
      (enrichment.sugarPercent ?? 0) +
      (enrichment.eggCount ?? 0) * 10;
  final richnessFactor = 1 + (richness / 100).clamp(0.0, 1.0) * 0.6;

  return switch (input.style) {
    DoughStyle.classic => _classicTimeline(input, richnessFactor),
    DoughStyle.sourdough => _sourdoughTimeline(input, richnessFactor),
    DoughStyle.preferment => _prefermentTimeline(input, richnessFactor),
  };
}

BakeTimeline _classicTimeline(RecipeInput input, double richnessFactor) {
  // Roughly inverse: double the yeast, halve the bulk.
  final yeast = (input.yeast ?? 1).clamp(0.1, 5);
  final bulk = (1.5 / yeast * richnessFactor).clamp(0.5, 6.0);

  return BakeTimeline([
    BakeStep(
      kind: StepKind.mix,
      title: 'Mix',
      duration: const Duration(minutes: 12),
      detail: 'Combine everything and knead to a smooth, elastic dough.',
    ),
    BakeStep(
      kind: StepKind.bulk,
      title: 'Bulk ferment',
      duration: _hours(bulk),
      detail: 'Until roughly doubled. Warmer room, faster rise.',
    ),
    const BakeStep(
      kind: StepKind.shape,
      title: 'Shape',
      duration: Duration(minutes: 10),
    ),
    BakeStep(
      kind: StepKind.proof,
      title: 'Final proof',
      duration: _hours(bulk * 0.6),
      detail: 'Until a poked dent springs back slowly.',
    ),
    BakeStep(
      kind: StepKind.bake,
      title: 'Bake',
      duration: _bakeDuration(input),
      detail: _bakeDetail(input),
    ),
  ]);
}

BakeTimeline _sourdoughTimeline(RecipeInput input, double richnessFactor) {
  final levain = (input.levainPercent ?? 20).clamp(5, 60);
  // 20% levain is the reference point at about 5.5 hours.
  final bulk = (5.5 * (20 / levain) * richnessFactor).clamp(2.5, 10.0);
  final foldWindow = _hours(bulk * 0.45);

  return BakeTimeline([
    const BakeStep(
      kind: StepKind.autolyse,
      title: 'Autolyse',
      duration: Duration(minutes: 45),
      detail: 'Flour and water only. Rest before the levain and salt go in.',
    ),
    const BakeStep(
      kind: StepKind.mix,
      title: 'Add levain and salt',
      duration: Duration(minutes: 15),
    ),
    BakeStep(
      kind: StepKind.fold,
      title: 'Stretch and fold',
      duration: foldWindow,
      detail: 'Four sets, about 30 minutes apart.',
    ),
    BakeStep(
      kind: StepKind.bulk,
      title: 'Finish bulk',
      duration: _hours(bulk) - foldWindow,
      detail: 'Until risen by about half and domed.',
    ),
    const BakeStep(
      kind: StepKind.preshape,
      title: 'Preshape',
      duration: Duration(minutes: 20),
    ),
    const BakeStep(
      kind: StepKind.shape,
      title: 'Shape',
      duration: Duration(minutes: 10),
    ),
    const BakeStep(
      kind: StepKind.proof,
      title: 'Cold proof',
      duration: Duration(hours: 12),
      detail: 'Overnight in the fridge. Bake straight from cold.',
    ),
    BakeStep(
      kind: StepKind.bake,
      title: 'Bake',
      duration: _bakeDuration(input),
      detail: _bakeDetail(input),
    ),
  ]);
}

BakeTimeline _prefermentTimeline(RecipeInput input, double richnessFactor) {
  final prefermentYeast = (input.prefermentYeast ?? 0.2).clamp(0.05, 3);
  // A poolish at 0.2% yeast is an overnight affair; more yeast, less waiting.
  final ripen = (12 * (0.2 / prefermentYeast)).clamp(2.0, 16.0);

  return BakeTimeline([
    BakeStep(
      kind: StepKind.preferment,
      title: 'Build the preferment',
      duration: _hours(ripen),
      detail: 'Ready when domed and just starting to fall.',
    ),
    const BakeStep(
      kind: StepKind.mix,
      title: 'Mix the final dough',
      duration: Duration(minutes: 15),
    ),
    BakeStep(
      kind: StepKind.bulk,
      title: 'Bulk ferment',
      duration: _hours(2 * richnessFactor),
    ),
    const BakeStep(
      kind: StepKind.shape,
      title: 'Shape',
      duration: Duration(minutes: 10),
    ),
    BakeStep(
      kind: StepKind.proof,
      title: 'Final proof',
      duration: _hours(1.25 * richnessFactor),
    ),
    BakeStep(
      kind: StepKind.bake,
      title: 'Bake',
      duration: _bakeDuration(input),
      detail: _bakeDetail(input),
    ),
  ]);
}

/// Enriched doughs bake cooler and shorter; lean hearth loaves go long and hot.
Duration _bakeDuration(RecipeInput input) {
  final enrichment = input.enrichmentOrEmpty;
  final isEnriched =
      (enrichment.fatPercent ?? 0) + (enrichment.sugarPercent ?? 0) > 8 ||
      (enrichment.eggCount ?? 0) > 0;
  return isEnriched
      ? const Duration(minutes: 30)
      : const Duration(minutes: 45);
}

String _bakeDetail(RecipeInput input) {
  final enrichment = input.enrichmentOrEmpty;
  final isEnriched =
      (enrichment.fatPercent ?? 0) + (enrichment.sugarPercent ?? 0) > 8 ||
      (enrichment.eggCount ?? 0) > 0;
  return isEnriched
      ? '180 °C until deep golden and 90 °C inside.'
      : '250 °C covered for 20 minutes, then uncovered at 230 °C.';
}
