import '../timeline.dart';

/// A bake the baker has started, kept so Home can say what is happening now.
///
/// Stores the schedule as it was started — durations the baker edited on the
/// plan included — rather than recomputing it from the recipe, which would
/// quietly reset those edits.
class ActiveBake {
  const ActiveBake({
    required this.recipeId,
    required this.recipeName,
    required this.steps,
  });

  final String recipeId;
  final String recipeName;
  final List<ScheduledStep> steps;

  /// The step under way at [now], or the first one if the bake has not begun
  /// yet. Null once the last step is done.
  ScheduledStep? stepAt(DateTime now) {
    for (final step in steps) {
      if (step.endsAt.isAfter(now)) return step;
    }
    return null;
  }

  /// How far the dough has risen at [now], for Home's jar: [level] climbs
  /// from [restLevel] to [peakLevel] with the share of fermenting time (bulk,
  /// folds and proof) that has passed, and [ready] turns true once all of it
  /// is behind — the dough is at its peak and wants the oven.
  ///
  /// Shaping knocks real dough back; the jar deliberately does not, so it only
  /// ever rises while you watch it.
  ({double level, bool ready}) riseAt(DateTime now) {
    var total = Duration.zero;
    var elapsed = Duration.zero;
    for (final s in steps) {
      if (!s.step.ferments) continue;
      final length = s.endsAt.difference(s.startsAt);
      total += length;
      if (!now.isAfter(s.startsAt)) continue;
      final done = now.difference(s.startsAt);
      elapsed += done < length ? done : length;
    }
    if (total == Duration.zero) {
      final over = stepAt(now) == null;
      return (level: over ? peakLevel : restLevel, ready: over);
    }
    final share = elapsed.inSeconds / total.inSeconds;
    return (
      level: restLevel + (peakLevel - restLevel) * share,
      ready: share >= 1,
    );
  }

  static const restLevel = 0.35;
  static const peakLevel = 0.85;

  ScheduledStep? stepAfter(ScheduledStep step) {
    final index = steps.indexOf(step);
    return index < 0 || index + 1 >= steps.length ? null : steps[index + 1];
  }

  Map<String, dynamic> toJson() => {
    'recipeId': recipeId,
    'recipeName': recipeName,
    'steps': [
      for (final s in steps)
        {
          'kind': s.step.kind.name,
          'title': s.step.title,
          if (s.step.detail != null) 'detail': s.step.detail,
          'startsAt': s.startsAt.toIso8601String(),
          'endsAt': s.endsAt.toIso8601String(),
        },
    ],
  };

  /// Throws [FormatException] on anything malformed.
  factory ActiveBake.fromJson(Map<String, dynamic> json) {
    try {
      return ActiveBake(
        recipeId: json['recipeId'] as String,
        recipeName: json['recipeName'] as String,
        steps: [
          for (final raw in json['steps'] as List)
            _step(raw as Map<String, dynamic>),
        ],
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed bake: $e');
    } on ArgumentError catch (e) {
      throw FormatException('Unknown bake step: $e');
    }
  }

  static ScheduledStep _step(Map<String, dynamic> json) {
    final startsAt = DateTime.parse(json['startsAt'] as String);
    final endsAt = DateTime.parse(json['endsAt'] as String);
    return ScheduledStep(
      step: BakeStep(
        kind: StepKind.values.byName(json['kind'] as String),
        title: json['title'] as String,
        duration: endsAt.difference(startsAt),
        detail: json['detail'] as String?,
      ),
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }
}
