import 'package:flutter/material.dart';

/// The app's one motion idea: things *rise*. A section arrives by drifting up a
/// few pixels as it fades in, and later sections wait a beat — a short stagger,
/// so a screen assembles rather than appears.
///
/// Plays once, on first build. With reduced motion it is just [child].
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, this.delay = Duration.zero, required this.child});

  /// How long to wait before rising. Keep it short: 60 ms a step.
  final Duration delay;
  final Widget child;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  static const _rise = Duration(milliseconds: 420);

  // The delay is the front of the controller's own run rather than a Timer, so
  // nothing is left pending if the screen closes first.
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.delay + _rise,
  )..forward();

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / (widget.delay + _rise).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Text that rolls when it changes: the old value slides up and out as the new
/// one rises into place, like a counter. For totals that move as you type.
///
/// It is still one [Text] once the roll finishes, so it reads and finds like
/// any other.
class RollingText extends StatelessWidget {
  const RollingText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // The Stack sizes each Text to its own width, so textAlign alone can
      // place nothing: the Stack has to.
      layoutBuilder: (current, previous) => Stack(
        alignment: textAlign == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(text);
        return ClipRect(
          child: SlideTransition(
            position: Tween(
              begin: Offset(0, incoming ? 0.6 : -0.6),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
