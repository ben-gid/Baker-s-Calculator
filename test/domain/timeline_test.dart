import 'package:bakers_calculator/domain/models/dough_style.dart';
import 'package:bakers_calculator/domain/models/recipe_input.dart';
import 'package:bakers_calculator/domain/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

const _classic = RecipeInput(
  style: DoughStyle.classic,
  flourWeight: 500,
  hydration: 70,
  salt: 2,
  yeast: 1,
);

const _sourdough = RecipeInput(
  style: DoughStyle.sourdough,
  totalDoughWeight: 900,
  hydration: 75,
  salt: 2,
  levainPercent: 20,
  levainHydration: 100,
);

const _preferment = RecipeInput(
  style: DoughStyle.preferment,
  totalDoughWeight: 900,
  hydration: 72,
  salt: 2,
  prefermentPercent: 30,
  prefermentHydration: 100,
  prefermentYeast: 0.2,
);

Duration stepOfKind(BakeTimeline timeline, StepKind kind) =>
    timeline.steps.firstWhere((s) => s.kind == kind).duration;

void main() {
  group('shape of each timeline', () {
    test('classic runs mix to bake with no preferment step', () {
      final steps = buildTimeline(_classic).steps.map((s) => s.kind);
      expect(steps.first, StepKind.mix);
      expect(steps.last, StepKind.bake);
      expect(steps, isNot(contains(StepKind.preferment)));
      expect(steps, isNot(contains(StepKind.autolyse)));
    });

    test('sourdough autolyses, folds and cold proofs', () {
      final steps = buildTimeline(_sourdough).steps.map((s) => s.kind);
      expect(steps.first, StepKind.autolyse);
      expect(steps, containsAll([StepKind.fold, StepKind.preshape]));
      expect(steps.last, StepKind.bake);
    });

    test('preferment starts by building the preferment', () {
      final steps = buildTimeline(_preferment).steps.map((s) => s.kind);
      expect(steps.first, StepKind.preferment);
    });

    test('no step has a zero or negative duration', () {
      for (final input in [_classic, _sourdough, _preferment]) {
        for (final step in buildTimeline(input).steps) {
          expect(
            step.duration,
            greaterThan(Duration.zero),
            reason: '${input.style.name} / ${step.title}',
          );
        }
      }
    });
  });

  group('fermentation responds to the recipe', () {
    test('more yeast means a shorter bulk', () {
      final slow = stepOfKind(buildTimeline(_classic), StepKind.bulk);
      final fast = stepOfKind(
        buildTimeline(_classic.copyWith(yeast: 2)),
        StepKind.bulk,
      );
      expect(fast, lessThan(slow));
    });

    test('more levain means a shorter bulk', () {
      final slow = stepOfKind(buildTimeline(_sourdough), StepKind.bulk);
      final fast = stepOfKind(
        buildTimeline(_sourdough.copyWith(levainPercent: 40)),
        StepKind.bulk,
      );
      expect(fast, lessThan(slow));
    });

    test('enrichment slows fermentation down', () {
      final lean = stepOfKind(buildTimeline(_classic), StepKind.bulk);
      final rich = stepOfKind(
        buildTimeline(
          _classic.copyWith(
            enrichment: const Enrichment(
              fatPercent: 30,
              sugarPercent: 15,
              eggCount: 3,
            ),
          ),
        ),
        StepKind.bulk,
      );
      expect(rich, greaterThan(lean));
    });

    test('enriched doughs get a shorter, cooler bake', () {
      final lean = stepOfKind(buildTimeline(_classic), StepKind.bake);
      final rich = stepOfKind(
        buildTimeline(
          _classic.copyWith(enrichment: const Enrichment(fatPercent: 20)),
        ),
        StepKind.bake,
      );
      expect(rich, lessThan(lean));
      expect(
        buildTimeline(
          _classic.copyWith(enrichment: const Enrichment(fatPercent: 20)),
        ).steps.last.detail,
        contains('180'),
      );
    });

    test('absurd leavening still produces a sane schedule', () {
      for (final yeast in [0.01, 0.5, 50.0]) {
        final bulk = stepOfKind(
          buildTimeline(_classic.copyWith(yeast: yeast)),
          StepKind.bulk,
        );
        expect(bulk, greaterThanOrEqualTo(const Duration(minutes: 30)));
        expect(bulk, lessThanOrEqualTo(const Duration(hours: 6)));
      }
    });
  });

  group('scheduling', () {
    test('steps run end to end from the start time', () {
      final timeline = buildTimeline(_classic);
      final start = DateTime(2026, 3, 1, 9);
      final scheduled = timeline.scheduleFrom(start);

      expect(scheduled.first.startsAt, start);
      for (var i = 1; i < scheduled.length; i++) {
        expect(scheduled[i].startsAt, scheduled[i - 1].endsAt);
      }
      expect(scheduled.last.endsAt, start.add(timeline.total));
    });

    test('planning backwards from a finish time', () {
      final timeline = buildTimeline(_sourdough);
      final outOfOven = DateTime(2026, 3, 2, 8);

      final start = timeline.startForFinish(outOfOven);

      expect(timeline.scheduleFrom(start).last.endsAt, outOfOven);
      // A sourdough with an overnight cold proof starts the day before.
      expect(
        start.isBefore(outOfOven.subtract(const Duration(hours: 12))),
        isTrue,
      );
    });

    test('editing one step shifts everything after it', () {
      final timeline = buildTimeline(_classic);
      final bulkIndex = timeline.steps.indexWhere(
        (s) => s.kind == StepKind.bulk,
      );

      final longer = timeline.replaceStep(bulkIndex, const Duration(hours: 3));

      expect(longer.total, greaterThan(timeline.total));
      expect(longer.steps[bulkIndex].duration, const Duration(hours: 3));
      // Nothing else changed.
      expect(
        longer.steps.map((s) => s.title),
        timeline.steps.map((s) => s.title),
      );
    });

    test('only the waiting steps are worth an alarm', () {
      final alarms = buildTimeline(_sourdough).steps.where((s) => s.isAlarm);
      expect(alarms.map((s) => s.kind), isNot(contains(StepKind.shape)));
      expect(alarms.map((s) => s.kind), contains(StepKind.proof));
    });
  });
}
