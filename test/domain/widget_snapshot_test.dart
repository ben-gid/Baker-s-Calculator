import 'package:bakers_calculator/domain/widget_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_bake_test.dart' show after, folded, loaf, start;

/// The widget's own rule, as the Kotlin and Swift sides apply it.
int? widgetStep(Map<String, Object?> snapshot, DateTime now) {
  for (final s in snapshot['steps']! as List) {
    final step = s as Map;
    if ((step['endsAt'] as int) > now.millisecondsSinceEpoch) {
      return step['step'] as int;
    }
  }
  return null;
}

void main() {
  test('the widget picks the step the app would, at any moment', () {
    final bakes = [
      loaf(),
      loaf().done(0, after(0, 10)),
      loaf().skipTo(3, after(1)),
      folded(skipped: {0}),
      folded().foldSetDone(1, after(1, 30)),
      loaf().extend(1, after(3)),
    ];
    for (final bake in bakes) {
      final snapshot = bakeSnapshot(bake);
      for (var m = -60; m < 12 * 60; m += 5) {
        final now = start.add(Duration(minutes: m));
        expect(widgetStep(snapshot, now), bake.currentAt(now), reason: '$m');
      }
    }
  });

  test('a fold says which set is next', () {
    final bake = folded().foldSetDone(1, after(1, 30));
    final steps = bakeSnapshot(bake)['steps']! as List;
    final fold = steps.cast<Map>().firstWhere((s) => s['step'] == 1);
    expect(fold['sets'], 'Set 2 of 4');
    expect(fold['next'], 'bulk');
  });

  test('a finished bake leaves the widget nothing to count down', () {
    final bake = loaf().skipTo(5, after(1));
    expect(bakeSnapshot(bake)['steps'], isEmpty);
    expect(bake.currentAt(after(1)), isNull);
  });
}
