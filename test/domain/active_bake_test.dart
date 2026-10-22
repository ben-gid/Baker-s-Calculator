import 'dart:convert';

import 'package:bakers_calculator/domain/models/active_bake.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:bakers_calculator/domain/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 21, 8);
  final steps = buildTimeline(
    const RecipeInput(levainPercent: 20),
  ).replaceStep(0, const Duration(minutes: 90)).scheduleFrom(start);
  final bake = ActiveBake(
    recipeId: 'r1',
    recipeName: 'Country Sourdough',
    steps: steps,
  );

  test('survives a JSON round trip, edited durations included', () {
    final back = ActiveBake.fromJson(
      jsonDecode(jsonEncode(bake.toJson())) as Map<String, dynamic>,
    );
    expect(back.recipeName, 'Country Sourdough');
    expect(back.steps.first.step.duration, const Duration(minutes: 90));
    expect(back.steps.first.step.kind, steps.first.step.kind);
    expect(back.steps.last.endsAt, steps.last.endsAt);
  });

  test('malformed JSON is a FormatException, not a crash', () {
    expect(
      () => ActiveBake.fromJson({'recipeId': 1}),
      throwsA(isA<FormatException>()),
    );
  });

  test('stepAt finds the step under way, the first before it starts, and '
      'nothing once it is done', () {
    expect(bake.stepAt(start.subtract(const Duration(hours: 1))), steps.first);
    expect(bake.stepAt(start.add(const Duration(minutes: 30))), steps.first);
    expect(bake.stepAt(start.add(const Duration(minutes: 91))), steps[1]);
    expect(bake.stepAt(steps.last.endsAt), isNull);
    expect(bake.stepAfter(steps.first), steps[1]);
    expect(bake.stepAfter(steps.last), isNull);
  });

  group('riseAt', () {
    // Mix 30 min, bulk 4 h, shape 30 min, proof 2 h, bake 45 min: six hours of
    // fermenting, starting half an hour in.
    ActiveBake loaf() {
      var at = start;
      ScheduledStep step(StepKind kind, Duration length) {
        final s = ScheduledStep(
          step: BakeStep(kind: kind, title: kind.name, duration: length),
          startsAt: at,
          endsAt: at.add(length),
        );
        at = s.endsAt;
        return s;
      }

      return ActiveBake(
        recipeId: 'r',
        recipeName: 'Loaf',
        steps: [
          step(StepKind.mix, const Duration(minutes: 30)),
          step(StepKind.bulk, const Duration(hours: 4)),
          step(StepKind.shape, const Duration(minutes: 30)),
          step(StepKind.proof, const Duration(hours: 2)),
          step(StepKind.bake, const Duration(minutes: 45)),
        ],
      );
    }

    DateTime after(int hours, [int minutes = 0]) =>
        start.add(Duration(hours: hours, minutes: minutes));

    test('rests until fermenting starts', () {
      final rise = loaf().riseAt(after(0, 10));
      expect(rise.level, ActiveBake.restLevel);
      expect(rise.ready, isFalse);
    });

    test('rises with the share of fermenting time that has passed', () {
      // Two of the six fermenting hours: a third of the way up.
      const third =
          ActiveBake.restLevel +
          (ActiveBake.peakLevel - ActiveBake.restLevel) / 3;
      final rise = loaf().riseAt(after(2, 30));
      expect(rise.level, closeTo(third, 1e-9));
      expect(rise.ready, isFalse);
    });

    test('shaping holds the level rather than knocking it back', () {
      final bake = loaf();
      expect(bake.riseAt(after(4, 45)).level, bake.riseAt(after(4, 30)).level);
    });

    test('is ready at its peak once the proof is done', () {
      final rise = loaf().riseAt(after(7, 5));
      expect(rise.level, ActiveBake.peakLevel);
      expect(rise.ready, isTrue);
    });
  });
}
