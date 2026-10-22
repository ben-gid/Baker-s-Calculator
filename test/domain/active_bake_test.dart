import 'dart:convert';

import 'package:bakers_calculator/domain/models/active_bake.dart';
import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/models/recipe.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:bakers_calculator/domain/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

final start = DateTime(2026, 10, 21, 8);

DateTime after(int hours, [int minutes = 0]) =>
    start.add(Duration(hours: hours, minutes: minutes));

BakeStep step(StepKind kind, Duration length, {int? sets}) =>
    BakeStep(kind: kind, title: kind.name, duration: length, sets: sets);

/// Mix 30 min, bulk 4 h, shape 30 min, proof 2 h, bake 45 min: six hours of
/// fermenting, starting half an hour in.
ActiveBake loaf() => ActiveBake.planned(
  recipeId: 'r',
  recipeName: 'Loaf',
  start: start,
  plan: [
    step(StepKind.mix, const Duration(minutes: 30)),
    step(StepKind.bulk, const Duration(hours: 4)),
    step(StepKind.shape, const Duration(minutes: 30)),
    step(StepKind.proof, const Duration(hours: 2)),
    step(StepKind.bake, const Duration(minutes: 45)),
  ],
);

/// Autolyse 1 h, folds 2 h (four sets), bulk 3 h, bake 1 h.
ActiveBake folded({Set<int> skipped = const {}}) => ActiveBake.planned(
  recipeId: 'r',
  recipeName: 'Folded',
  start: start,
  skipped: skipped,
  plan: [
    step(StepKind.autolyse, const Duration(hours: 1)),
    step(StepKind.fold, const Duration(hours: 2), sets: 4),
    step(StepKind.bulk, const Duration(hours: 3)),
    step(StepKind.bake, const Duration(hours: 1)),
  ],
);

ActiveBake roundTrip(ActiveBake bake) => ActiveBake.fromJson(
  jsonDecode(jsonEncode(bake.toJson())) as Map<String, dynamic>,
);

void main() {
  group('the clock', () {
    test('moves on by itself, and the bake ends after its last step', () {
      final bake = loaf();
      expect(bake.currentAt(start.subtract(const Duration(hours: 1))), 0);
      expect(bake.currentAt(after(0, 10)), 0);
      expect(bake.currentAt(after(0, 31)), 1);
      expect(bake.currentAt(after(7, 44)), 4);
      expect(bake.currentAt(after(7, 45)), isNull);
    });

    test('a step the clock passed is unticked, not done', () {
      final bake = loaf();
      expect(bake.stateAt(0, after(1)), StepProgress.unticked);
      expect(bake.stateAt(1, after(1)), StepProgress.current);
      expect(bake.stateAt(2, after(1)), StepProgress.upcoming);
    });

    test('a step skipped before starting takes no time', () {
      final bake = folded(skipped: {0});
      expect(bake.schedule[1].startsAt, start);
      expect(bake.currentAt(start), 1);
    });
  });

  group('done', () {
    test('early pulls everything after it forward to now', () {
      final bake = loaf().done(0, after(0, 10));
      expect(bake.stateAt(0, after(0, 10)), StepProgress.done);
      expect(bake.schedule[1].startsAt, after(0, 10));
      expect(bake.schedule.last.endsAt, after(7, 25));
    });

    test('late on a step the clock passed restarts what follows from now', () {
      // The reminder for the mix is tapped twenty minutes after it ended.
      final bake = loaf().done(0, after(0, 50));
      expect(bake.records[0].status, StepStatus.done);
      expect(bake.records[0].endedAt, after(0, 50));
      expect(bake.schedule[1].startsAt, after(0, 50));
      expect(bake.currentAt(after(0, 50)), 1);
    });

    test('keeps the real times of the steps the clock moved past', () {
      final bake = loaf().done(1, after(4));
      expect(bake.records[0].startedAt, start);
      expect(bake.records[0].endedAt, after(0, 30));
      expect(bake.schedule[0].endsAt, after(0, 30));
      expect(bake.stateAt(0, after(4)), StepProgress.unticked);
    });
  });

  group('skipTo', () {
    test('leaves out every step on the way and starts the target now', () {
      final bake = loaf().skipTo(3, after(0, 10));
      expect(bake.records.map((r) => r.status).take(3), [
        StepStatus.skipped,
        StepStatus.skipped,
        StepStatus.skipped,
      ]);
      expect(bake.currentAt(after(0, 10)), 3);
      expect(bake.schedule[3].startsAt, after(0, 10));
    });

    test('past the last step ends the bake', () {
      expect(loaf().skipTo(5, after(1)).currentAt(after(1)), isNull);
    });
  });

  group('goBackTo', () {
    test('resetting makes every later step to do again', () {
      final bake = loaf()
          .done(0, after(0, 30))
          .done(1, after(4, 30))
          .goBackTo(0, after(5), resetLater: true);
      expect(bake.records.every((r) => r.status == StepStatus.pending), isTrue);
      expect(bake.schedule[0].startsAt, after(5));
      expect(bake.schedule[1].startsAt, after(5, 30));
    });

    test('keeping ticks passes over the steps already done', () {
      final bake = loaf()
          .done(0, after(0, 30))
          .done(1, after(4, 30))
          .goBackTo(0, after(5), resetLater: false);
      expect(bake.records[1].status, StepStatus.done);
      // The mix runs again, then the clock goes straight on to shaping.
      expect(bake.schedule[2].startsAt, after(5, 30));
      expect(bake.nextAfter(0), 2);
    });
  });

  group('extend', () {
    test('a step the clock moved past runs until 15 minutes from now', () {
      final bake = loaf().extend(1, after(4, 35));
      expect(bake.currentAt(after(4, 35)), 1);
      expect(bake.schedule[1].endsAt, after(4, 50));
      expect(bake.schedule[1].startsAt, after(0, 30));
    });

    test('the step under way gets 15 more minutes', () {
      final bake = loaf().extend(1, after(2));
      expect(bake.schedule[1].endsAt, after(4, 45));
    });
  });

  group('folds', () {
    test('count their sets and finish on the last one', () {
      var bake = folded();
      for (var set = 1; set < 4; set++) {
        bake = bake.foldSetDone(1, after(1, set * 30));
        expect(bake.records[1].setsDone, set);
        expect(bake.records[1].status, StepStatus.pending);
      }
      bake = bake.foldSetDone(1, after(3));
      expect(bake.records[1].status, StepStatus.done);
    });

    test('ending early gives the rest of their time to bulk', () {
      // One hour into a two-hour fold window.
      final bake = folded().done(1, after(2));
      expect(bake.plan[2].duration, const Duration(hours: 4));
      expect(bake.schedule[2].endsAt, after(6));
    });

    test('skipping them mid-way does the same', () {
      final bake = folded().skipTo(2, after(2));
      expect(bake.plan[2].duration, const Duration(hours: 4));
    });

    test('left out before the start, bulk takes all of their time', () {
      final bake = folded(skipped: {1});
      expect(bake.plan[2].duration, const Duration(hours: 5));
    });
  });

  group('reminder buttons', () {
    test('Done on a fold reminder counts one set', () {
      final bake = folded().apply(BakeAction.done, 1, after(1, 30));
      expect(bake.records[1].setsDone, 1);
    });

    test('a stale reminder for a step already done changes nothing', () {
      final bake = loaf().done(0, after(0, 20));
      expect(identical(bake.apply(BakeAction.done, 0, after(1)), bake), isTrue);
    });
  });

  test('retiming a step to come moves everything after it', () {
    final bake = loaf().retime(3, const Duration(hours: 3));
    expect(bake.schedule.last.endsAt, after(8, 45));
  });

  test('tick marks a passed step without moving the clock', () {
    final bake = loaf().tick(0, after(1));
    expect(bake.records[0].status, StepStatus.done);
    expect(bake.schedule[1].startsAt, after(0, 30));
  });

  group('ingredients', () {
    const input = RecipeInput(
      style: DoughStyle.sourdough,
      totalDoughWeight: 900,
      hydration: 75,
      salt: 2,
      levainPercent: 20,
      levainHydration: 100,
      loaves: 2,
    );

    test('come from the input carried with the bake, loaves included', () {
      final plan = buildTimeline(input).steps;
      final bake = ActiveBake.planned(
        recipeId: 'r',
        recipeName: 'Two loaves',
        start: start,
        plan: plan,
        input: input,
      );
      final mix = plan.indexWhere((s) => s.kind == StepKind.mix);
      double grams(List<Ingredient> rows) =>
          rows.fold(0.0, (s, i) => s + i.grams);
      // The levain and salt for two loaves: twice what one loaf takes.
      final one = ActiveBake.planned(
        recipeId: 'r',
        recipeName: 'One loaf',
        start: start,
        plan: plan,
        input: input.copyWith(loaves: 1),
      );
      expect(
        grams(bake.ingredients![mix]),
        closeTo(grams(one.ingredients![mix]) * 2, 1e-9),
      );
    });

    test('a skipped step hands its rows on', () {
      final plan = buildTimeline(input).steps;
      final autolyse = plan.indexWhere((s) => s.kind == StepKind.autolyse);
      final bake = ActiveBake.planned(
        recipeId: 'r',
        recipeName: 'Loaf',
        start: start,
        plan: plan,
        input: input,
      ).skipTo(autolyse + 1, start);
      expect(bake.ingredients![autolyse], isEmpty);
      expect(
        bake.ingredients![autolyse + 1].map((i) => i.name),
        containsAll(['Flour', 'Water', 'Levain', 'Salt']),
      );
    });
  });

  group('JSON', () {
    test('survives a round trip, mid-bake', () {
      final bake = folded()
          .done(0, after(0, 50))
          .foldSetDone(1, after(1))
          .toggleWeighed('0:Flour');
      final back = roundTrip(bake);
      expect(back.toJson(), bake.toJson());
      expect(back.schedule.last.endsAt, bake.schedule.last.endsAt);
      expect(back.records[1].setsDone, 1);
    });

    test('a bake saved before steps could be ticked still loads', () {
      final legacy = {
        'recipeId': 'r1',
        'recipeName': 'Country Sourdough',
        'steps': [
          {
            'kind': 'mix',
            'title': 'Mix',
            'startsAt': start.toIso8601String(),
            'endsAt': after(0, 30).toIso8601String(),
          },
          {
            'kind': 'bulk',
            'title': 'Bulk ferment',
            'startsAt': after(0, 30).toIso8601String(),
            'endsAt': after(4, 30).toIso8601String(),
          },
        ],
      };
      final bake = ActiveBake.fromJson(legacy);
      expect(bake.input, isNull);
      expect(bake.ingredients, isNull);
      expect(bake.schedule.last.endsAt, after(4, 30));
      expect(bake.currentAt(after(1)), 1);
    });

    test('malformed JSON is a FormatException, not a crash', () {
      expect(
        () => ActiveBake.fromJson({'recipeId': 1}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('riseAt', () {
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
