import 'models/active_bake.dart';

/// What the home-screen widget needs to follow [bake] without the app: every
/// step still to run, laid end to end on the clock.
///
/// The widget draws at moments the app never sees, so it is handed the whole
/// forecast and picks for itself: the step under way is the first whose
/// `endsAt` is still ahead, the same rule as [ActiveBake.currentAt]. Times are
/// epoch milliseconds so neither platform has to parse a date.
Map<String, Object?> bakeSnapshot(ActiveBake bake) {
  final schedule = bake.schedule;
  return {
    'recipeId': bake.recipeId,
    'recipeName': bake.recipeName,
    'loaves': bake.input?.loaves,
    'steps': [
      for (var i = bake.anchor; i < bake.plan.length; i++)
        if (bake.records[i].status == StepStatus.pending)
          {
            'step': i,
            'title': schedule[i].step.title,
            'startsAt': schedule[i].startsAt.millisecondsSinceEpoch,
            'endsAt': schedule[i].endsAt.millisecondsSinceEpoch,
            'next': switch (bake.nextAfter(i)) {
              final next? => schedule[next].step.title,
              null => null,
            },
            if (schedule[i].step.sets case final sets?)
              'sets': 'Set ${bake.records[i].setsDone + 1} of $sets',
          },
    ],
  };
}
