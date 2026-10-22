import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../data/notification_service.dart';
import '../../domain/models/active_bake.dart';
import '../../domain/models/recipe.dart';
import '../../domain/timeline.dart';
import '../../state/providers.dart';
import '../widgets/action_bar.dart';
import '../widgets/bake_step_card.dart';
import '../widgets/dough_temp_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loaf_stepper.dart';
import '../widgets/motion.dart';
import '../widgets/panel.dart';
import '../widgets/starter_jar.dart';

/// A bake plan: every step laid end to end from a start time, with the grams
/// that go in at each one and reminders for the waiting.
///
/// The recipe's jar flies in and rises to its peak — where this plan takes the
/// dough — beside the two times. Down the timeline, the steps where the dough
/// is rising run in the starter's colour.
///
/// Before the bake, the start time is the only thing most bakers touch — pick
/// "out of the oven by 8am" and the whole plan slides. Steps that bread can do
/// without can be left out, the folds counted and the levain's feed chosen;
/// durations are editable because no formula knows how warm your kitchen is.
///
/// Once this recipe's bake is under way the same page is its live checklist:
/// the step under way open as its card, the rest ticked, unticked or left out,
/// and any of them a tap away from going back or skipping ahead.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key, required this.id, this.loaves});

  final String id;

  /// The loaf count from the recipe's page, for the grams. The recipe's own
  /// count when the plan is opened any other way.
  final int? loaves;

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  BakeTimeline? _timeline;
  FeedRatio _ratio = FeedRatio.r122;
  final Set<int> _skipped = {};
  DateTime _start = DateTime.now();
  bool _scheduling = false;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// A live checklist counts down; a plan being drawn up does not.
  void _syncTick(bool live) {
    if (!live) {
      _tick?.cancel();
      _tick = null;
    } else {
      _tick ??= Timer.periodic(
        const Duration(minutes: 1),
        (_) => setState(() {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final recipe = library.hasValue
        ? ref.read(libraryProvider.notifier).byId(widget.id)
        : null;

    if (library.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.search_off,
          title: 'Recipe not found',
          message: 'It may have been deleted from this device.',
          actionLabel: 'Back to recipes',
          onAction: () => context.go('/recipes'),
        ),
      );
    }

    final active = ref.watch(activeBakeProvider);
    final live = active != null && active.recipeId == recipe.id;
    _syncTick(live);

    if (live) return _livePlan(active);

    final input = recipe.input.copyWith(
      loaves: widget.loaves ?? recipe.input.loaves,
    );
    final timeline = _timeline ??= buildTimeline(input, ratio: _ratio);
    final draft = ActiveBake.planned(
      recipeId: recipe.id,
      recipeName: recipe.name,
      plan: timeline.steps,
      start: _start,
      skipped: _skipped,
      input: input,
      ratio: _ratio,
    );
    final steps = draft.schedule;
    final finish = steps.last.endsAt;
    final total = finish.difference(_start);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));

    return Scaffold(
      appBar: AppBar(title: Text('Plan: ${recipe.name}')),
      bottomNavigationBar: ActionBar(
        label: _scheduling ? 'Setting reminders' : 'Start bake',
        icon: Icons.notifications_active_outlined,
        onPressed: _scheduling ? null : () => _startBake(draft),
      ),
      body: SafeArea(
        child: ListView(
          padding: pagePadding(context),
          children: [
            _StartCard(
              recipeId: recipe.id,
              start: _start,
              finish: finish,
              total: total,
              onStartChanged: (value) => setState(() => _start = value),
              onFinishChanged: (value) =>
                  setState(() => _start = value.subtract(total)),
            ),
            const SizedBox(height: Insets.md),
            for (var i = 0; i < steps.length; i++)
              _StepTile(
                scheduled: steps[i],
                isLast: i == steps.length - 1,
                rows: draft.ingredients?[i] ?? const [],
                unit: unit,
                leftOut: _skipped.contains(i),
                onTap: () => _editDuration(
                  context,
                  timeline.steps[i],
                  (d) => setState(() => _timeline = timeline.replaceStep(i, d)),
                ),
                controls: [
                  if (timeline.steps[i].optional)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Include this step'),
                      value: !_skipped.contains(i),
                      onChanged: (on) => setState(
                        () => on ? _skipped.remove(i) : _skipped.add(i),
                      ),
                    ),
                  if (!_skipped.contains(i) &&
                      timeline.steps[i].kind == StepKind.levain)
                    Wrap(
                      spacing: Insets.sm,
                      children: [
                        for (final ratio in FeedRatio.values)
                          ChoiceChip(
                            label: Text(
                              '${ratio.label} · ${formatDuration(ratio.ripens)}',
                            ),
                            selected: ratio == _ratio,
                            onSelected: (_) => setState(() {
                              _ratio = ratio;
                              _timeline = timeline.replaceStep(i, ratio.ripens);
                            }),
                          ),
                      ],
                    ),
                  if (!_skipped.contains(i) && timeline.steps[i].sets != null)
                    LoafStepper(
                      label: 'Sets',
                      loaves: timeline.steps[i].sets!,
                      max: 4,
                      fewer: 'One fewer set',
                      more: 'One more set',
                      onChanged: (sets) => setState(
                        () => _timeline = timeline.withFoldSets(sets),
                      ),
                    ),
                ],
              ),
            // At the foot of the plan, for mixing day: how warm the water
            // needs to be.
            const SizedBox(height: Insets.lg),
            const DoughTempCard(),
          ],
        ),
      ),
    );
  }

  Widget _livePlan(ActiveBake bake) {
    final now = DateTime.now();
    final current = bake.currentAt(now);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final steps = bake.schedule;

    return Scaffold(
      appBar: AppBar(title: Text(bake.recipeName)),
      bottomNavigationBar: ActionBar(
        label: current == null ? 'Clear bake' : 'Stop bake',
        icon: Icons.stop_circle_outlined,
        onPressed: () => ref.read(activeBakeProvider.notifier).stop(),
      ),
      body: SafeArea(
        child: ListView(
          padding: pagePadding(context),
          children: [
            _LiveHeader(bake: bake, now: now),
            const SizedBox(height: Insets.md),
            for (var i = 0; i < steps.length; i++)
              if (i == current)
                _Spine(
                  scheduled: steps[i],
                  progress: StepProgress.current,
                  isLast: i == steps.length - 1,
                  child: BakeStepCard(bake: bake, index: i, now: now),
                )
              else
                _StepTile(
                  scheduled: steps[i],
                  isLast: i == steps.length - 1,
                  rows: bake.ingredients?[i] ?? const [],
                  unit: unit,
                  progress: bake.stateAt(i, now),
                  leftOut: bake.records[i].status == StepStatus.skipped,
                  onTap: () => _stepActions(bake, i, now),
                ),
            const SizedBox(height: Insets.lg),
            const DoughTempCard(),
          ],
        ),
      ),
    );
  }

  /// What can be done with a step that is not the one under way.
  Future<void> _stepActions(ActiveBake bake, int index, DateTime now) async {
    final controller = ref.read(activeBakeProvider.notifier);
    final step = bake.plan[index];
    final progress = bake.stateAt(index, now);
    final ahead = progress == StepProgress.upcoming;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: SectionLabel(step.title),
            ),
            const SizedBox(height: Insets.sm),
            if (ahead) ...[
              ListTile(
                leading: const Icon(Icons.skip_next),
                title: const Text('Skip to this step'),
                subtitle: const Text('Leaves out the steps before it'),
                onTap: () => Navigator.pop(context, 'skip'),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Change how long it takes'),
                onTap: () => Navigator.pop(context, 'retime'),
              ),
            ] else ...[
              if (progress != StepProgress.skipped)
                ListTile(
                  leading: Icon(
                    progress == StepProgress.done
                        ? Icons.remove_done
                        : Icons.check,
                  ),
                  title: Text(
                    progress == StepProgress.done ? 'Untick' : 'Tick as done',
                  ),
                  onTap: () => Navigator.pop(context, 'tick'),
                ),
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Go back to this step'),
                subtitle: const Text('It starts again now'),
                onTap: () => Navigator.pop(context, 'back'),
              ),
            ],
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
    if (!mounted) return;

    switch (choice) {
      case 'skip':
        controller.skipTo(index);
      case 'retime':
        await _editDuration(context, step, (d) => controller.retime(index, d));
      case 'tick':
        controller.tick(index);
      case 'back':
        final laterDone = bake.records
            .skip(index + 1)
            .any((r) => r.status == StepStatus.done);
        if (!laterDone) {
          controller.goBackTo(index, resetLater: false);
          return;
        }
        final reset = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Go back to ${step.title.toLowerCase()}?'),
            content: const Text(
              'It starts again now. The steps after it that you ticked can '
              'stay ticked, and be passed over, or be done again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Do them again'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep ticks'),
              ),
            ],
          ),
        );
        if (reset != null) controller.goBackTo(index, resetLater: reset);
    }
  }

  Future<void> _startBake(ActiveBake bake) async {
    setState(() => _scheduling = true);
    final messenger = ScaffoldMessenger.of(context);
    final ScheduleOutcome outcome = await ref
        .read(activeBakeProvider.notifier)
        .start(bake);

    if (!mounted) return;
    setState(() => _scheduling = false);

    final first = bake.schedule.firstWhere(
      (s) => s.step.isAlarm && s.endsAt != s.startsAt,
      orElse: () => bake.schedule.first,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          ScheduleOutcome.scheduled =>
            'Reminders set. First one at ${formatClock(first.endsAt)}.',
          ScheduleOutcome.permissionDenied =>
            'No notification permission — the plan is still here to follow.',
          ScheduleOutcome.unsupported =>
            'Reminders are not available on this device — the plan is still here.',
        }),
      ),
    );
  }
}

Future<void> _editDuration(
  BuildContext context,
  BakeStep step,
  ValueChanged<Duration> onChanged,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: step.duration.inHours.clamp(0, 23),
      minute: step.duration.inMinutes.remainder(60),
    ),
    helpText: 'How long for ${step.title.toLowerCase()}?',
    builder: (context, child) => MediaQuery(
      // A duration is hours and minutes, never am/pm.
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (picked == null) return;
  final duration = Duration(hours: picked.hour, minutes: picked.minute);
  if (duration > Duration.zero) onChanged(duration);
}

/// The live plan's header: the jar at the height the dough has reached, and
/// the two times that matter now.
class _LiveHeader extends StatelessWidget {
  const _LiveHeader({required this.bake, required this.now});

  final ActiveBake bake;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rise = bake.riseAt(now);
    return Row(
      children: [
        Hero(
          tag: recipeJarTag(bake.recipeId),
          child: SizedBox(
            width: 76,
            height: 98,
            child: StarterJar(
              level: rise.level,
              dome: rise.ready ? 1 : 0,
              fizz: 0.9,
            ),
          ),
        ),
        const SizedBox(width: Insets.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Under way'),
              const SizedBox(height: Insets.xs),
              Text(
                'Out of the oven ${_dayLabel(bake.schedule.last.endsAt)} '
                '${formatClock(bake.schedule.last.endsAt)}',
                style: numeric(theme.textTheme.titleMedium),
              ),
              const SizedBox(height: Insets.xs),
              BakeDots(bake: bake, now: now),
              const SizedBox(height: Insets.xs),
              Text(
                'Tap a step to tick it, go back to it or skip ahead.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.recipeId,
    required this.start,
    required this.finish,
    required this.total,
    required this.onStartChanged,
    required this.onFinishChanged,
  });

  final String recipeId;
  final DateTime start;
  final DateTime finish;
  final Duration total;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onFinishChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RiseIn(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: recipeJarTag(recipeId),
            child: const SizedBox(
              width: 76,
              height: 98,
              child: StarterJar(
                level: ActiveBake.peakLevel,
                dome: 1,
                fizz: 0.9,
              ),
            ),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('Timing'),
                const SizedBox(height: Insets.xs),
                _TimeRow(
                  label: 'Start',
                  value: start,
                  onChanged: onStartChanged,
                ),
                _TimeRow(
                  label: 'Out of the oven',
                  value: finish,
                  onChanged: onFinishChanged,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  '${formatDuration(total)} in all. Set either time — the '
                  'other follows.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: value.subtract(const Duration(days: 7)),
      lastDate: value.add(const Duration(days: 30)),
      helpText: 'Pick the day',
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      helpText: 'Pick the time',
    );
    if (time == null) return;

    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(Radii.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall),
                  Text(
                    '${_dayLabel(value)} ${formatClock(value)}',
                    style: numeric(theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_calendar_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

String _dayLabel(DateTime value) {
  final today = DateTime.now();
  final isToday =
      value.year == today.year &&
      value.month == today.month &&
      value.day == today.day;
  if (isToday) return 'today';

  final tomorrow = today.add(const Duration(days: 1));
  final isTomorrow =
      value.year == tomorrow.year &&
      value.month == tomorrow.month &&
      value.day == tomorrow.day;
  if (isTomorrow) return 'tomorrow';

  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[value.weekday - 1];
}

/// The clock time and the step's mark down the left, so the steps read as one
/// continuous plan. Where the dough is rising the line runs thicker, in the
/// starter's colour.
class _Spine extends StatelessWidget {
  const _Spine({
    required this.scheduled,
    required this.isLast,
    required this.child,
    this.progress,
  });

  final ScheduledStep scheduled;
  final bool isLast;
  final Widget child;

  /// Null before the bake, when every step carries the plain dot.
  final StepProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    final colors = theme.colorScheme;
    final rising = scheduled.step.ferments;

    // A Stack sized by the card, with the spine stretched beside it, rather
    // than an IntrinsicHeight row: chips and switches under-report their
    // intrinsic height and the card would overflow.
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 64,
          child: Column(
            children: [
              Text(
                formatClock(scheduled.startsAt),
                style: numeric(theme.textTheme.labelMedium),
              ),
              const SizedBox(height: Insets.xs),
              SizedBox(
                height: 12,
                child: Center(
                  child: progress != null
                      ? ProgressMark(progress!)
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rising
                                ? baking.starter
                                : colors.outlineVariant,
                            border: rising
                                ? Border.all(
                                    color: baking.starterDeep,
                                    width: 2,
                                  )
                                : null,
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Container(
                  width: rising ? 4 : 2,
                  margin: const EdgeInsets.symmetric(vertical: Insets.xs),
                  decoration: BoxDecoration(
                    color: isLast
                        ? Colors.transparent
                        : rising
                        ? baking.starterDeep
                        : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 64, bottom: Insets.md),
          child: child,
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.scheduled,
    required this.isLast,
    required this.rows,
    required this.unit,
    required this.onTap,
    this.leftOut = false,
    this.progress,
    this.controls = const [],
  });

  final ScheduledStep scheduled;
  final bool isLast;
  final List<Ingredient> rows;
  final MassUnit unit;
  final VoidCallback onTap;
  final bool leftOut;
  final StepProgress? progress;

  /// The plan's own settings for this step: include it, its feed, its folds.
  final List<Widget> controls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    final colors = theme.colorScheme;
    final step = scheduled.step;
    final faded = leftOut || progress == StepProgress.done;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: faded ? colors.onSurfaceVariant : null,
    );

    return _Spine(
      scheduled: scheduled,
      isLast: isLast,
      progress: progress,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(step.title, style: titleStyle)),
                    if (step.isAlarm && !leftOut)
                      Padding(
                        padding: const EdgeInsets.only(right: Insets.sm),
                        child: Icon(
                          Icons.notifications_outlined,
                          size: 16,
                          color: baking.proof,
                        ),
                      ),
                    Text(
                      leftOut ? 'Left out' : _length(step),
                      style: numeric(theme.textTheme.labelMedium),
                    ),
                  ],
                ),
                if (!leftOut && progress == null && step.detail != null) ...[
                  const SizedBox(height: Insets.xs),
                  Text(step.detail!, style: theme.textTheme.bodySmall),
                ],
                if (!leftOut && rows.isNotEmpty) ...[
                  const SizedBox(height: Insets.sm),
                  StepRows(rows: rows, unit: unit),
                ],
                ...controls,
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _length(BakeStep step) => step.sets == null
      ? formatDuration(step.duration)
      : '${step.sets} × ${formatDuration(foldInterval)}';
}
