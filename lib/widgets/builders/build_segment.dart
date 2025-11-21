import 'package:flutter/material.dart';

/// builds a segment for Cupertino SlidingSegmentedControl with selected text 
/// color as onPrimary and unselected as onSurface
Widget buildSegment(String label, bool selected, ThemeData theme) {
  return Padding(
    padding: const EdgeInsets.symmetric( vertical: 6),
    child: Text(
      label,
      style: TextStyle(
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
      ),
    ),
  );
}
