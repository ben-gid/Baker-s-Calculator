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
}
