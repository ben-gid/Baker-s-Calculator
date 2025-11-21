import 'package:dough_calculator/utils/functions.dart';
import 'package:dough_calculator/widgets/builders/build_segment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DoughSelector extends StatelessWidget {
  /// Currently selected segment index.
  final int selectedDough;

  /// Called when the user picks a new dough type.
  final void Function(int? newDoughIndex) onDoughChanged;

  const DoughSelector({
    super.key,
    required this.selectedDough,
    required this.onDoughChanged,
  });


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<int, Widget> doughSelectorSegments = {
      0: buildSegment(convertDoughIndex(0), selectedDough == 0, theme),
      1: buildSegment(convertDoughIndex(1), selectedDough == 1, theme),
      2: buildSegment(convertDoughIndex(2), selectedDough == 2, theme),
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl(
          children: doughSelectorSegments,
          groupValue: selectedDough,
          onValueChanged: onDoughChanged,
          thumbColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
