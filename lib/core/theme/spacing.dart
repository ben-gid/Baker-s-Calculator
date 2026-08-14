/// The only spacing and radius values in the app.
///
/// Everything is a multiple of 4 so vertical rhythm holds across screens. If a
/// layout seems to need a value that isn't here, the layout is wrong.
library;

import 'package:flutter/widgets.dart';

abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Horizontal page margin. Grows on wider screens; see [pageMargin].
  static const double page = 16;
  static const double pageWide = 32;

  /// Room left under scrolling content. Small, because nothing floats over it:
  /// the nav bar and the action bar both take their own space in the scaffold,
  /// so this is breathing room at the end of a list, not clearance.
  static const double scrollBottom = 24;
}

/// Corner radii. Generous and soft: a filled surface with a large radius is the
/// container language, the way a grouped iOS list or a Material 3 filled card
/// reads. Nothing in the app has a square corner.
///
/// The three steps are proportional to what they wrap — a panel holding several
/// controls is rounder than a control, and anything that reads as a control in
/// its own right is a full [pill].
abstract final class Radii {
  static const double card = 20;
  static const double field = 14;
  static const double chip = 12;

  /// Fully round. Applied to a fixed-height box, so any value past half the
  /// height gives the same shape — [BorderRadius.circular] clamps for us.
  static const double pill = 999;
}

/// Border widths. Containers are told apart by their **fill**, not by a rule:
/// panels sit on a slightly darker page, and fields on a slightly darker panel.
/// A border here is the exception — a hairline in `outlineVariant` for a
/// divider, or [focus] in `primary` for the one control that has the keyboard.
abstract final class Borders {
  static const double hair = 1;
  static const double focus = 2;
}

/// Minimum tap target. Android asks for 48, iOS for 44 — take the larger.
const double minTapTarget = 48;

/// Widths at which the layout changes shape.
abstract final class Breakpoints {
  static const double tablet = 700;
}

double pageMargin(double width) =>
    width >= Breakpoints.tablet ? Insets.pageWide : Insets.page;

/// Padding for a full screen of scrolling content: a margin that widens on
/// large screens, and a little room at the end.
EdgeInsets pagePadding(
  BuildContext context, {
  double top = Insets.lg,
  double bottom = Insets.scrollBottom,
}) {
  final margin = pageMargin(MediaQuery.sizeOf(context).width);
  return EdgeInsets.fromLTRB(margin, top, margin, bottom);
}
