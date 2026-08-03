/// The only spacing, radius and duration values in the app.
///
/// Everything is a multiple of 4 so vertical rhythm holds across screens. If a
/// layout seems to need a value that isn't here, the layout is wrong.
library;

abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 48;

  /// Horizontal page margin. Grows on wider screens; see [pageMargin].
  static const double page = 16;
  static const double pageWide = 32;

  /// Room left under scrolling content so it clears the bottom nav bar.
  static const double scrollBottom = 96;
}

abstract final class Radii {
  static const double card = 16;
  static const double field = 12;
  static const double chip = 8;
  static const double pill = 999;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);
}

/// Minimum tap target. Android asks for 48, iOS for 44 — take the larger.
const double minTapTarget = 48;

/// Widths at which the layout changes shape.
abstract final class Breakpoints {
  static const double tablet = 700;
  static const double desktop = 1100;
}

double pageMargin(double width) =>
    width >= Breakpoints.tablet ? Insets.pageWide : Insets.page;
