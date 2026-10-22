import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../data/notification_service.dart';
import '../../domain/models/active_bake.dart';
import '../../domain/timeline.dart';
import '../../state/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/action_bar.dart';
import '../widgets/dough_temp_card.dart';
import '../widgets/motion.dart';
import '../widgets/panel.dart';
import '../widgets/starter_jar.dart';

/// A bake plan: every step laid end to end from a start time, with reminders.
///
/// The recipe's jar flies in and rises to its peak — where this plan takes the
/// dough — beside the two times. Down the timeline, the steps where the dough
/// is rising run in the starter's colour.
///
/// The start time is the only thing most bakers touch — pick "out of the oven
/// by 8am" and the whole plan slides. Individual durations are editable because
/// no formula knows how warm your kitchen is.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  BakeTimeline? _timeline;
  DateTime _start = DateTime.now();
  bool _scheduling = false;

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

    final timeline = _timeline ??= buildTimeline(recipe.input);
    final steps = timeline.scheduleFrom(_start);

    return Scaffold(
      appBar: AppBar(title: Text('Plan: ${recipe.name}')),
      bottomNavigationBar: ActionBar(
        label: _scheduling ? 'Setting reminders' : 'Start bake',
        icon: Icons.notifications_active_outlined,
        onPressed: _scheduling
            ? null
            : () => _startBake(recipe.id, recipe.name, steps),
      ),
      body: SafeArea(
        child: ListView(
          padding: pagePadding(context),
          children: [
            _StartCard(
              recipeId: recipe.id,
              start: _start,
              finish: steps.last.endsAt,
              total: timeline.total,
              onStartChanged: (value) => setState(() => _start = value),
              onFinishChanged: (value) =>
                  setState(() => _start = timeline.startForFinish(value)),
            ),
            const SizedBox(height: Insets.md),
            for (var i = 0; i < steps.length; i++)
              _StepTile(
                scheduled: steps[i],
                isLast: i == steps.length - 1,
                onDurationChanged: (duration) => setState(
                  () => _timeline = timeline.replaceStep(i, duration),
                ),
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

  Future<void> _startBake(
    String id,
    String name,
    List<ScheduledStep> steps,
  ) async {
    setState(() => _scheduling = true);
    final messenger = ScaffoldMessenger.of(context);

    // Recorded whatever happens to the reminders: a refused permission still
    // leaves a bake under way, and Home can still count it down.
    ref
        .read(activeBakeProvider.notifier)
        .start(ActiveBake(recipeId: id, recipeName: name, steps: steps));

    final ScheduleOutcome outcome = await ref
        .read(notificationServiceProvider)
        .scheduleBake(recipeName: name, steps: steps);

    if (!mounted) return;
    setState(() => _scheduling = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          ScheduleOutcome.scheduled =>
            'Reminders set. First one at ${formatClock(steps.first.endsAt)}.',
          ScheduleOutcome.permissionDenied =>
            'No notification permission — the plan is still here to follow.',
          ScheduleOutcome.unsupported =>
            'Reminders are not available on this device — the plan is still here.',
        }),
      ),
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

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.scheduled,
    required this.isLast,
    required this.onDurationChanged,
  });

  final ScheduledStep scheduled;
  final bool isLast;
  final ValueChanged<Duration> onDurationChanged;

  Future<void> _editDuration(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: scheduled.step.duration.inHours.clamp(0, 23),
        minute: scheduled.step.duration.inMinutes.remainder(60),
      ),
      helpText: 'How long for ${scheduled.step.title.toLowerCase()}?',
      builder: (context, child) => MediaQuery(
        // A duration is hours and minutes, never am/pm.
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final duration = Duration(hours: picked.hour, minutes: picked.minute);
    if (duration > Duration.zero) onDurationChanged(duration);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baking = theme.extension<BakingColors>()!;
    final colors = theme.colorScheme;
    final step = scheduled.step;
    final rising = step.ferments;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A spine down the left so the steps read as one continuous plan.
          // Where the dough is rising it runs thicker, in the starter's colour.
          SizedBox(
            width: 64,
            child: Column(
              children: [
                Text(
                  formatClock(scheduled.startsAt),
                  style: numeric(theme.textTheme.labelMedium),
                ),
                const SizedBox(height: Insets.xs),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rising ? baking.starter : colors.outlineVariant,
                    border: rising
                        ? Border.all(color: baking.starterDeep, width: 2)
                        : null,
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: Card(
                child: InkWell(
                  onTap: () => _editDuration(context),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                step.title,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            if (step.isAlarm)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: Insets.sm,
                                ),
                                child: Icon(
                                  Icons.notifications_outlined,
                                  size: 16,
                                  color: baking.proof,
                                ),
                              ),
                            Text(
                              formatDuration(step.duration),
                              style: numeric(theme.textTheme.labelMedium),
                            ),
                          ],
                        ),
                        if (step.detail != null) ...[
                          const SizedBox(height: Insets.xs),
                          Text(step.detail!, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
