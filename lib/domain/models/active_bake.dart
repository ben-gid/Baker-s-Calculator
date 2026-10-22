import '../calculator.dart';
import '../step_ingredients.dart';
import '../timeline.dart';
import 'recipe.dart';
import 'recipe_input.dart';

enum StepStatus { pending, done, skipped }

/// Where a step stands at a moment, for the checklist: [unticked] is a step
/// the clock has moved past without the baker ticking it.
enum StepProgress { done, skipped, unticked, current, upcoming }

/// What a reminder's buttons do.
enum BakeAction { done, extend }

/// How much "15 more min" adds.
const extendBy = Duration(minutes: 15);

class StepRecord {
  const StepRecord({
    this.status = StepStatus.pending,
    this.startedAt,
    this.endedAt,
    this.setsDone = 0,
  });

  final StepStatus status;

  /// When the step really ran. Set once the bake has moved past it; until
  /// then its times are the forecast in [ActiveBake.schedule].
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Sets of stretch and fold done so far.
  final int setsDone;

  StepRecord copyWith({
    StepStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? setsDone,
  }) => StepRecord(
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    setsDone: setsDone ?? this.setsDone,
  );

  StepRecord get unfrozen => StepRecord(status: status, setsDone: setsDone);
}

/// A bake the baker has started, kept so Home can say what is happening now.
///
/// Stores the plan as it was started — durations the baker edited included —
/// rather than recomputing it from the recipe, which would quietly reset those
/// edits. The recipe's input travels with it, loaf count and all, so each
/// step's grams stay right even if the recipe is edited or deleted mid-bake.
///
/// Time hangs off one **anchor**: the step the baker last restarted the clock
/// on and when. Everything before it has its real times frozen in [records];
/// from it on, the steps still to do are laid end to end, and the clock moves
/// from one to the next by itself. Done, Skip, Go back and "15 more min" each
/// move the anchor to now, so the forecast after it is always honest.
class ActiveBake {
  ActiveBake({
    required this.recipeId,
    required this.recipeName,
    required this.plan,
    required this.records,
    required this.anchor,
    required this.anchorStart,
    this.input,
    this.ratio = FeedRatio.r122,
    this.weighed = const {},
  }) : assert(plan.length == records.length);

  /// A bake about to start at [start], with the [skipped] steps already left
  /// out. A fold left out gives its time to the bulk after it: fewer folds is
  /// not less fermenting.
  factory ActiveBake.planned({
    required String recipeId,
    required String recipeName,
    required List<BakeStep> plan,
    required DateTime start,
    Set<int> skipped = const {},
    RecipeInput? input,
    FeedRatio ratio = FeedRatio.r122,
  }) {
    var steps = plan;
    for (final i in skipped) {
      steps = _handOverFoldTime(steps, i, plan[i].duration);
    }
    return ActiveBake(
      recipeId: recipeId,
      recipeName: recipeName,
      plan: steps,
      records: [
        for (var i = 0; i < plan.length; i++)
          StepRecord(
            status: skipped.contains(i)
                ? StepStatus.skipped
                : StepStatus.pending,
          ),
      ],
      anchor: 0,
      anchorStart: start,
      input: input,
      ratio: ratio,
    );
  }

  final String recipeId;
  final String recipeName;
  final List<BakeStep> plan;
  final List<StepRecord> records;
  final int anchor;
  final DateTime anchorStart;

  /// Null for a bake saved before steps carried ingredients.
  final RecipeInput? input;
  final FeedRatio ratio;

  /// Ingredient rows ticked as weighed, keyed by [weighedKey].
  final Set<String> weighed;

  static String weighedKey(int step, Ingredient row) => '$step:${row.name}';

  /// Every step pinned to the clock: real times behind the anchor, the
  /// forecast from it on. Steps done or skipped ahead of it take no time.
  late final List<ScheduledStep> schedule = _layOut();

  List<ScheduledStep> _layOut() {
    final out = <ScheduledStep>[];
    var cursor = anchorStart;
    for (var i = 0; i < plan.length; i++) {
      if (i < anchor) {
        final start = records[i].startedAt ?? anchorStart;
        out.add(
          ScheduledStep(
            step: plan[i],
            startsAt: start,
            endsAt: records[i].endedAt ?? start,
          ),
        );
        continue;
      }
      final end = _runs(i) ? cursor.add(plan[i].duration) : cursor;
      out.add(ScheduledStep(step: plan[i], startsAt: cursor, endsAt: end));
      cursor = end;
    }
    return out;
  }

  bool _runs(int i) => records[i].status == StepStatus.pending;

  /// The step under way at [now] — or the first, if the bake has not begun.
  /// Null once the last step is over.
  int? currentAt(DateTime now) {
    for (var i = anchor; i < plan.length; i++) {
      if (_runs(i) && schedule[i].endsAt.isAfter(now)) return i;
    }
    return null;
  }

  /// The next step after [index] that will take any time.
  int? nextAfter(int index) {
    for (var i = index + 1; i < plan.length; i++) {
      if (i >= anchor && _runs(i)) return i;
    }
    return null;
  }

  StepProgress stateAt(int index, DateTime now) {
    switch (records[index].status) {
      case StepStatus.done:
        return StepProgress.done;
      case StepStatus.skipped:
        return StepProgress.skipped;
      case StepStatus.pending:
        final current = currentAt(now);
        if (index == current) return StepProgress.current;
        return current == null || index < current
            ? StepProgress.unticked
            : StepProgress.upcoming;
    }
  }

  /// The recipe for this bake's loaves, or null when there is no input to
  /// work it from.
  late final Recipe? recipe = _recipe();

  Recipe? _recipe() {
    final input = this.input;
    if (input == null) return null;
    try {
      return calculate(input);
    } on ArgumentError {
      // A stored input that no longer calculates still leaves a plan to follow.
      return null;
    }
  }

  /// What goes into the bowl at each step, a skipped step's rows carried on
  /// to the next. Null without a [recipe].
  late final List<List<Ingredient>>? ingredients = recipe == null
      ? null
      : stepIngredients(
          recipe!,
          plan,
          skipped: [for (final r in records) r.status == StepStatus.skipped],
          ratio: ratio,
        );

  /// How to feed the levain, for a sourdough bake.
  ({double starter, double flour, double water, double keepBack})? get feed =>
      recipe == null ? null : levainFeed(recipe!, ratio);

  // -------------------------------------------------------------------------
  // What the baker can do. Every operation is pure and takes the moment it
  // happened, and each first freezes the steps the clock has already moved
  // past, so their real times are kept.
  // -------------------------------------------------------------------------

  /// [index] is finished now; the next step starts now. Works on a step the
  /// clock already moved past too — tapping Done on a reminder ten minutes
  /// late restarts what follows from the tap.
  ActiveBake done(int index, DateTime now) {
    final b = _freeze(now);
    final started = _startedBy(b.schedule[index], now);
    final records = [...b.records];
    records[index] = records[index].copyWith(
      status: StepStatus.done,
      startedAt: started,
      endedAt: now,
      setsDone: b.plan[index].sets,
    );
    final unused = b.plan[index].duration - now.difference(started);
    return b
        ._with(plan: _handOverFoldTime(b.plan, index, unused), records: records)
        ._restartFrom(index + 1, now);
  }

  /// One set of stretch and fold done; the last set finishes the step.
  ActiveBake foldSetDone(int index, DateTime now) {
    final b = _freeze(now);
    final sets = b.records[index].setsDone + 1;
    if (sets >= (b.plan[index].sets ?? 1)) return b.done(index, now);
    final records = [...b.records];
    records[index] = records[index].copyWith(setsDone: sets);
    return b._with(records: records);
  }

  /// Jumps to [index], leaving out every step not yet done on the way.
  /// `skipTo(current + 1)` is a plain Skip; past the last step ends the bake.
  ActiveBake skipTo(int index, DateTime now) {
    final b = _freeze(now);
    final from = b.currentAt(now) ?? plan.length;
    final records = [...b.records];
    var steps = b.plan;
    for (var i = from; i < index && i < plan.length; i++) {
      if (records[i].status != StepStatus.pending) continue;
      final started = i == from ? _startedBy(b.schedule[i], now) : now;
      records[i] = records[i].copyWith(
        status: StepStatus.skipped,
        startedAt: started,
        endedAt: now,
      );
      // Only a bulk that is still to come can take the time.
      if (i + 1 >= index) {
        steps = _handOverFoldTime(
          steps,
          i,
          steps[i].duration - now.difference(started),
        );
      }
    }
    return b._with(plan: steps, records: records)._restartFrom(index, now);
  }

  /// Starts [index] again from now. With [resetLater], every step after it is
  /// to do again; otherwise the ones already done stay ticked and are passed
  /// over when the clock reaches them.
  ActiveBake goBackTo(int index, DateTime now, {required bool resetLater}) {
    final b = _freeze(now);
    final records = [
      for (var i = 0; i < plan.length; i++)
        if (i == index || (resetLater && i > index))
          const StepRecord()
        else
          b.records[i],
    ];
    return b._with(records: records)._restartFrom(index, now);
  }

  /// [index] runs until [extendBy] from now. A step the clock moved past is
  /// reopened from where it began.
  ActiveBake extend(int index, DateTime now) {
    final b = _freeze(now);
    final s = b.schedule[index];
    final base = s.endsAt.isAfter(now) ? s.endsAt : now;
    final steps = [...b.plan];
    steps[index] = steps[index].withDuration(
      base.add(extendBy).difference(s.startsAt),
    );
    final current = b.currentAt(now);
    if (current != null && index >= current) return b._with(plan: steps);

    final records = [...b.records];
    records[index] = records[index].copyWith(status: StepStatus.pending);
    return b
        ._with(plan: steps, records: records)
        ._restartFrom(index, s.startsAt);
  }

  /// A new length for a step still to come.
  ActiveBake retime(int index, Duration duration) => _with(
    plan: [
      for (var i = 0; i < plan.length; i++)
        i == index ? plan[i].withDuration(duration) : plan[i],
    ],
  );

  /// Ticks or unticks a step without moving the clock.
  ActiveBake tick(int index, DateTime now) {
    final b = _freeze(now);
    final records = [...b.records];
    records[index] = records[index].copyWith(
      status: records[index].status == StepStatus.done
          ? StepStatus.pending
          : StepStatus.done,
    );
    return b._with(records: records);
  }

  ActiveBake toggleWeighed(String key) => _with(
    weighed: weighed.contains(key)
        ? ({...weighed}..remove(key))
        : {...weighed, key},
  );

  /// A reminder's button, which carries the step it was for. A step already
  /// dealt with is left alone, so a stale reminder cannot rewind the bake.
  ActiveBake apply(BakeAction action, int index, DateTime now) {
    if (index < 0 || index >= plan.length) return this;
    if (records[index].status != StepStatus.pending) return this;
    return switch (action) {
      BakeAction.done =>
        plan[index].sets != null ? foldSetDone(index, now) : done(index, now),
      BakeAction.extend => extend(index, now),
    };
  }

  ActiveBake _freeze(DateTime now) {
    final current = currentAt(now) ?? plan.length;
    if (current <= anchor) return this;
    final records = [...this.records];
    for (var i = anchor; i < current; i++) {
      records[i] = records[i].copyWith(
        startedAt: schedule[i].startsAt,
        endedAt: schedule[i].endsAt,
      );
    }
    return _with(
      records: records,
      anchor: current,
      anchorStart: current < plan.length
          ? schedule[current].startsAt
          : schedule.last.endsAt,
    );
  }

  ActiveBake _restartFrom(int index, DateTime at) => _with(
    records: [
      for (var i = 0; i < plan.length; i++)
        i >= index ? records[i].unfrozen : records[i],
    ],
    anchor: index,
    anchorStart: at,
  );

  static DateTime _startedBy(ScheduledStep s, DateTime now) =>
      s.startsAt.isAfter(now) ? now : s.startsAt;

  /// Adds the [unused] time of a fold at [index] to the bulk straight after
  /// it. Anything else passes through untouched.
  static List<BakeStep> _handOverFoldTime(
    List<BakeStep> plan,
    int index,
    Duration unused,
  ) {
    if (plan[index].kind != StepKind.fold ||
        unused <= Duration.zero ||
        index + 1 >= plan.length ||
        plan[index + 1].kind != StepKind.bulk) {
      return plan;
    }
    return [
      for (var i = 0; i < plan.length; i++)
        i == index + 1
            ? plan[i].withDuration(plan[i].duration + unused)
            : plan[i],
    ];
  }

  ActiveBake _with({
    List<BakeStep>? plan,
    List<StepRecord>? records,
    int? anchor,
    DateTime? anchorStart,
    Set<String>? weighed,
  }) => ActiveBake(
    recipeId: recipeId,
    recipeName: recipeName,
    plan: plan ?? this.plan,
    records: records ?? this.records,
    anchor: anchor ?? this.anchor,
    anchorStart: anchorStart ?? this.anchorStart,
    input: input,
    ratio: ratio,
    weighed: weighed ?? this.weighed,
  );

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
    for (final s in schedule) {
      if (!s.step.ferments) continue;
      final length = s.endsAt.difference(s.startsAt);
      total += length;
      if (!now.isAfter(s.startsAt)) continue;
      final done = now.difference(s.startsAt);
      elapsed += done < length ? done : length;
    }
    if (total == Duration.zero) {
      final over = currentAt(now) == null;
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

  Map<String, dynamic> toJson() => {
    'recipeId': recipeId,
    'recipeName': recipeName,
    if (input != null) 'input': input!.toJson(),
    'ratio': ratio.name,
    'anchor': anchor,
    'anchorStart': anchorStart.toIso8601String(),
    if (weighed.isNotEmpty) 'weighed': weighed.toList(),
    'steps': [
      for (var i = 0; i < plan.length; i++)
        {
          'kind': plan[i].kind.name,
          'title': plan[i].title,
          if (plan[i].detail != null) 'detail': plan[i].detail,
          'seconds': plan[i].duration.inSeconds,
          if (plan[i].sets != null) 'sets': plan[i].sets,
          'status': records[i].status.name,
          if (records[i].startedAt != null)
            'startedAt': records[i].startedAt!.toIso8601String(),
          if (records[i].endedAt != null)
            'endedAt': records[i].endedAt!.toIso8601String(),
          if (records[i].setsDone > 0) 'setsDone': records[i].setsDone,
        },
    ],
  };

  /// Throws [FormatException] on anything malformed. A bake saved before steps
  /// could be ticked loads with every step to do, its times exactly as saved.
  factory ActiveBake.fromJson(Map<String, dynamic> json) {
    try {
      final raw = [for (final s in json['steps'] as List) s as Map];
      if (raw.isEmpty) throw const FormatException('A bake with no steps');
      final legacy = json['anchor'] == null;
      final input = json['input'];
      return ActiveBake(
        recipeId: json['recipeId'] as String,
        recipeName: json['recipeName'] as String,
        plan: [for (final s in raw) _step(s, legacy: legacy)],
        records: [
          for (final s in raw)
            legacy
                ? const StepRecord()
                : StepRecord(
                    status: StepStatus.values.byName(s['status'] as String),
                    startedAt: _time(s['startedAt']),
                    endedAt: _time(s['endedAt']),
                    setsDone: s['setsDone'] as int? ?? 0,
                  ),
        ],
        anchor: legacy ? 0 : json['anchor'] as int,
        anchorStart: legacy
            ? DateTime.parse(raw.first['startsAt'] as String)
            : DateTime.parse(json['anchorStart'] as String),
        input: input == null
            ? null
            : RecipeInput.fromJson(input as Map<String, dynamic>),
        ratio: json['ratio'] == null
            ? FeedRatio.r122
            : FeedRatio.values.byName(json['ratio'] as String),
        weighed: {
          for (final key in json['weighed'] as List? ?? const []) key as String,
        },
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed bake: $e');
    } on ArgumentError catch (e) {
      throw FormatException('Unknown bake step: $e');
    }
  }

  static DateTime? _time(Object? raw) =>
      raw == null ? null : DateTime.parse(raw as String);

  static BakeStep _step(Map json, {required bool legacy}) => BakeStep(
    kind: StepKind.values.byName(json['kind'] as String),
    title: json['title'] as String,
    duration: legacy
        ? DateTime.parse(
            json['endsAt'] as String,
          ).difference(DateTime.parse(json['startsAt'] as String))
        : Duration(seconds: json['seconds'] as int),
    detail: json['detail'] as String?,
    sets: json['sets'] as int?,
  );
}
