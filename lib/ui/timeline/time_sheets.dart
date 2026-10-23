import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../widgets/loaf_stepper.dart';
import '../widgets/motion.dart';

/// How long a step takes: hours and minutes on two steppers. A duration is not
/// a time of day, so no clock face, and a cold proof can run past a day.
Future<Duration?> showDurationSheet(
  BuildContext context, {
  required String title,
  required Duration initial,
}) => showModalBottomSheet<Duration>(
  context: context,
  showDragHandle: true,
  builder: (context) => _DurationSheet(title: title, initial: initial),
);

/// A day and a time on one wheel, in the clock Settings chose.
Future<DateTime?> showDateTimeSheet(
  BuildContext context, {
  required String title,
  required DateTime initial,
}) => showModalBottomSheet<DateTime>(
  context: context,
  showDragHandle: true,
  builder: (context) => _DateTimeSheet(title: title, initial: initial),
);

class _DurationSheet extends StatefulWidget {
  const _DurationSheet({required this.title, required this.initial});

  final String title;
  final Duration initial;

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  late int _hours = widget.initial.inHours;
  late int _minutes = widget.initial.inMinutes.remainder(60);

  Duration get _value => Duration(hours: _hours, minutes: _minutes);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Sheet(
      title: widget.title,
      onSave: _value > Duration.zero
          ? () => Navigator.pop(context, _value)
          : null,
      children: [
        RollingText(
          formatDuration(_value),
          style: numeric(theme.textTheme.displaySmall),
        ),
        const SizedBox(height: Insets.md),
        LoafStepper(
          label: 'Hours',
          loaves: _hours,
          min: 0,
          // The engine's own ceiling on a step: two days.
          max: 48,
          fewer: 'One hour less',
          more: 'One hour more',
          onChanged: (h) => setState(() => _hours = h),
        ),
        LoafStepper(
          label: 'Minutes',
          loaves: _minutes,
          min: 0,
          max: 55,
          step: 5,
          fewer: 'Five minutes less',
          more: 'Five minutes more',
          onChanged: (m) => setState(() => _minutes = m),
        ),
      ],
    );
  }
}

class _DateTimeSheet extends StatefulWidget {
  const _DateTimeSheet({required this.title, required this.initial});

  final String title;
  final DateTime initial;

  @override
  State<_DateTimeSheet> createState() => _DateTimeSheetState();
}

class _DateTimeSheetState extends State<_DateTimeSheet> {
  late DateTime _value = widget.initial;

  static const _rowHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _Sheet(
      title: widget.title,
      onSave: () => Navigator.pop(context, _value),
      children: [
        SizedBox(
          height: _rowHeight * 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // One field-fill band behind the chosen row, in place of
              // Cupertino's grey lozenge per column.
              Container(
                height: _rowHeight,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.field),
                ),
              ),
              CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: theme.brightness,
                  primaryColor: colors.primary,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: numeric(
                      theme.textTheme.titleLarge,
                    ).copyWith(color: colors.onSurface),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: widget.initial,
                  minimumDate: widget.initial.subtract(const Duration(days: 7)),
                  maximumDate: widget.initial.add(const Duration(days: 30)),
                  use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                  backgroundColor: Colors.transparent,
                  itemExtent: _rowHeight,
                  selectionOverlayBuilder:
                      (
                        context, {
                        required columnCount,
                        required selectedIndex,
                      }) => null,
                  onDateTimeChanged: (value) => setState(() => _value = value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The title, what is being picked, and Cancel / Save — the save-recipe
/// sheet's shape.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.children,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Insets.lg),
            ...children,
            const SizedBox(height: Insets.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: FilledButton(
                    onPressed: onSave,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
