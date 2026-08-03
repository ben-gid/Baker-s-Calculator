import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../data/notification_service.dart';
import '../../domain/timeline.dart';
import '../../state/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';

/// A bake plan: every step laid end to end from a start time, with reminders.
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
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(title: Text('Plan: ${recipe.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scheduling ? null : () => _startBake(recipe.name, steps),
        icon: _scheduling
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.notifications_active_outlined),
        label: Text(_scheduling ? 'Setting reminders' : 'Start bake'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            pageMargin(width),
            Insets.lg,
            pageMargin(width),
            Insets.scrollBottom,
          ),
          children: [
            _StartCard(
              start: _start,
              finish: steps.last.endsAt,
              total: timeline.total,
              onStartChanged: (value) => setState(() => _start = value),
              onFinishChanged: (value) => setState(
                () => _start = timeline.startForFinish(value),
              ),
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
          ],
        ),
      ),
    );
  }

  Future<void> _startBake(String name, List<ScheduledStep> steps) async {
    setState(() => _scheduling = true);
    final messenger = ScaffoldMessenger.of(context);

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
    required this.start,
    required this.finish,
    required this.total,
    required this.onStartChanged,
    required this.onFinishChanged,
  });

  final DateTime start;
  final DateTime finish;
  final Duration total;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onFinishChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Timing',
      note: 'Total ${formatDuration(total)} from first mix to out of the oven.',
      children: [
        _TimeRow(
          label: 'Start',
          value: start,
          onChanged: onStartChanged,
        ),
        const Divider(height: Insets.xl),
        _TimeRow(
          label: 'Out of the oven',
          value: finish,
          onChanged: onFinishChanged,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'Set either one — the other follows.',
          style: theme.textTheme.bodySmall,
        ),
      ],
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
      borderRadius: BorderRadius.circular(Radii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            Text(
              '${_dayLabel(value)} ${formatClock(value)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: tabularFigures,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Icon(Icons.edit_calendar_outlined, color: theme.colorScheme.primary),
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

  const names = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
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
    final step = scheduled.step;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A spine down the left so the steps read as one continuous plan.
          SizedBox(
            width: 64,
            child: Column(
              children: [
                Text(
                  formatClock(scheduled.startsAt),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFeatures: tabularFigures,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: Insets.xs),
                    color: isLast
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant,
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
                  borderRadius: BorderRadius.circular(Radii.card),
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
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontFeatures: tabularFigures,
                              ),
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
