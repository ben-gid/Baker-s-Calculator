import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_theme.dart';

/// Shared by Home's jar and the calculator's, so the one flies into the other.
const jarHeroTag = 'starter-jar';

/// The jar — the app's one living visual. A fragment shader
/// (`shaders/starter_jar.frag`) draws the glass, the starter's moving surface
/// and its bubbles; this widget eases the level and dome to new values and
/// feeds the shader the time.
///
/// Motion is spent here and nowhere else, so the rest of the app can stay
/// still. It stops entirely when the platform asks for reduced motion, and the
/// ticker only runs while the jar's route is showing (`TickerMode`).
///
/// Until the shader has loaded — and always inside a widget test, where
/// `rootBundle` never completes — a plain painted jar stands in. That is also
/// why the ticker starts only once the shader is ready: an endless animation
/// would keep `pumpAndSettle` from ever settling.
class StarterJar extends StatefulWidget {
  const StarterJar({
    super.key,
    required this.level,
    this.dome = 0,
    this.fizz = 0.6,
    this.animate = true,
  });

  /// How full, 0..1 of the inside.
  final double level;

  /// 0..1: the risen dough doming at its peak.
  final double dome;

  /// 0..1: how lively the bubbles are.
  final double fizz;

  /// False draws a still jar — for the small ones on the recipe shelf.
  final bool animate;

  @override
  State<StarterJar> createState() => _StarterJarState();
}

class _StarterJarState extends State<StarterJar>
    with SingleTickerProviderStateMixin {
  /// Loaded once for every jar in the app.
  static Future<ui.FragmentProgram>? _loading;
  static ui.FragmentProgram? _program;

  final _time = ValueNotifier<double>(0);
  Ticker? _ticker;

  /// This jar's own instance: uniforms are per shader, and each jar has its own.
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (_program == null) {
      _loading ??= ui.FragmentProgram.fromAsset('shaders/starter_jar.frag');
      _loading!.then((program) {
        _program = program;
        if (mounted) setState(_syncTicker);
      }, onError: (Object e) => debugPrint('Starter jar shader: $e'));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(StarterJar old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  bool get _moving =>
      widget.animate &&
      _program != null &&
      !MediaQuery.disableAnimationsOf(context);

  void _syncTicker() {
    if (_moving) {
      _ticker ??= createTicker(
        (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
      )..start();
    } else {
      _ticker?.dispose();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final baking = Theme.of(context).extension<BakingColors>()!;
    final still = !widget.animate || MediaQuery.disableAnimationsOf(context);
    final palette = _JarColours(
      glass: colors.surfaceContainerHigh,
      rim: colors.outlineVariant,
      starter: baking.starter,
      deep: baking.starterDeep,
      bubble: baking.bubble,
    );

    // The level settles like a liquid would: a little past, then back.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.level.clamp(0, 1)),
      duration: still ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, level, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: widget.dome.clamp(0, 1)),
        duration: still ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, dome, _) {
          final program = _program;
          return CustomPaint(
            size: Size.infinite,
            painter: program == null
                ? _StillJarPainter(level: level, colours: palette)
                : _ShaderJarPainter(
                    shader: _shader ??= program.fragmentShader(),
                    time: _time,
                    level: level,
                    dome: dome,
                    fizz: widget.fizz,
                    colours: palette,
                  ),
          );
        },
      ),
    );
  }
}

class _JarColours {
  const _JarColours({
    required this.glass,
    required this.rim,
    required this.starter,
    required this.deep,
    required this.bubble,
  });

  final Color glass;
  final Color rim;
  final Color starter;
  final Color deep;
  final Color bubble;

  @override
  bool operator ==(Object other) =>
      other is _JarColours &&
      other.glass == glass &&
      other.rim == rim &&
      other.starter == starter &&
      other.deep == deep &&
      other.bubble == bubble;

  @override
  int get hashCode => Object.hash(glass, rim, starter, deep, bubble);
}

class _ShaderJarPainter extends CustomPainter {
  _ShaderJarPainter({
    required this.shader,
    required this.time,
    required this.level,
    required this.dome,
    required this.fizz,
    required this.colours,
  }) : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final double level;
  final double dome;
  final double fizz;
  final _JarColours colours;

  @override
  void paint(Canvas canvas, Size size) {
    var i = 0;
    void colour(Color c) => shader
      ..setFloat(i++, c.r)
      ..setFloat(i++, c.g)
      ..setFloat(i++, c.b)
      ..setFloat(i++, c.a);

    // Same order as the uniforms in starter_jar.frag.
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, time.value)
      ..setFloat(i++, level)
      ..setFloat(i++, dome)
      ..setFloat(i++, fizz);
    colour(colours.glass);
    colour(colours.rim);
    colour(colours.starter);
    colour(colours.deep);
    colour(colours.bubble);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderJarPainter old) =>
      old.level != level ||
      old.dome != dome ||
      old.fizz != fizz ||
      old.colours != colours;
}

/// The jar without the shader: same shape and colours, a flat surface and no
/// bubbles. Shown while the shader loads, and in tests.
class _StillJarPainter extends CustomPainter {
  _StillJarPainter({required this.level, required this.colours});

  final double level;
  final _JarColours colours;

  @override
  void paint(Canvas canvas, Size size) {
    final lidH = size.height * 0.085;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(1, lidH * 0.7, size.width - 1, size.height - 1),
      topLeft: Radius.circular(size.width * 0.18),
      topRight: Radius.circular(size.width * 0.18),
      bottomLeft: Radius.circular(size.width * 0.3),
      bottomRight: Radius.circular(size.width * 0.3),
    );
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRRect(body, Paint()..color = colours.glass);
    final top = body.top + size.height * 0.07;
    final bottom = body.bottom - 5;
    final surface = bottom - (bottom - top) * level;
    canvas.drawRect(
      Rect.fromLTRB(0, surface, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colours.starter, colours.deep],
        ).createShader(Rect.fromLTRB(0, surface, size.width, size.height)),
    );
    canvas.restore();
    canvas.drawRRect(
      body.deflate(1.6),
      Paint()
        ..color = colours.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, lidH / 2 + 0.5),
          width: size.width * 0.76,
          height: lidH,
        ),
        Radius.circular(lidH * 0.45),
      ),
      Paint()..color = colours.rim,
    );
  }

  @override
  bool shouldRepaint(_StillJarPainter old) =>
      old.level != level || old.colours != colours;
}
