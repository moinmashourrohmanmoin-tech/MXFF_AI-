import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// The three orb states share one visual language (red core, green particles,
/// rotating rings) but animate differently:
///  - idle:      calm slow rotation
///  - listening: green pulse rings expand outward
///  - thinking:  fast counter-rotating swirl
///  - speaking:  core pulses with outward waves
enum OrbState { idle, listening, thinking, speaking }

class MxffOrb extends StatefulWidget {
  const MxffOrb({super.key, this.size = 280, this.state = OrbState.idle});
  final double size;
  final OrbState state;

  @override
  State<MxffOrb> createState() => _MxffOrbState();
}

class _MxffOrbState extends State<MxffOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.square(widget.size),
        painter: OrbPainter(_c.value, widget.state),
      ),
    );
  }
}

class OrbPainter extends CustomPainter {
  OrbPainter(this.t, this.state);
  final double t; // 0..1 loop
  final OrbState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.34;

    switch (state) {
      case OrbState.idle:
        _paintGlow(canvas, center, r, 1.0);
        _paintBody(canvas, center, r);
        _paintParticles(canvas, center, r, speed: 1.0, greenBias: 0.55);
        _paintRings(canvas, center, r, speed: 1.0, rings: 2);
        _paintCore(canvas, center, r, pulse: 0.0);
        break;
      case OrbState.listening:
        _paintGlow(canvas, center, r, 1.2);
        _paintBody(canvas, center, r);
        _paintParticles(canvas, center, r, speed: 2.2, greenBias: 0.85);
        _paintRings(canvas, center, r, speed: 2.4, rings: 3);
        _paintWave(canvas, center, r, 3);
        _paintCore(canvas, center, r, pulse: 0.15 * math.sin(t * math.pi * 6));
        break;
      case OrbState.thinking:
        _paintGlow(canvas, center, r, 1.35);
        _paintBody(canvas, center, r);
        _paintParticles(canvas, center, r, speed: 4.0, greenBias: 0.5);
        _paintRings(canvas, center, r, speed: -3.5, rings: 3);
        _paintCore(canvas, center, r, pulse: 0.1 * math.sin(t * math.pi * 10));
        break;
      case OrbState.speaking:
        _paintGlow(canvas, center, r, 1.3);
        _paintBody(canvas, center, r);
        _paintParticles(canvas, center, r, speed: 2.6, greenBias: 0.65);
        _paintRings(canvas, center, r, speed: 2.0, rings: 2);
        _paintWave(canvas, center, r, 4);
        _paintCore(canvas, center, r,
            pulse: 0.28 * (0.5 + 0.5 * math.sin(t * math.pi * 8)));
        break;
    }

    _paintStars(canvas, size);
  }

  void _paintGlow(Canvas canvas, Offset c, double r, double strength) {
    canvas.drawCircle(
      c,
      r * 1.7,
      Paint()
        ..shader = RadialGradient(colors: [
          kNeonRed.withOpacity(0.28 * strength),
          kNeonGreen.withOpacity(0.10 * strength),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: c, radius: r * 1.7)),
    );
  }

  void _paintBody(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(colors: [
          Color(0xFF16261F),
          Color(0xFF050A08),
          Colors.black,
        ]).createShader(Rect.fromCircle(center: c, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  void _paintParticles(
    Canvas canvas,
    Offset c,
    double r, {
    required double speed,
    required double greenBias,
  }) {
    final rand = math.Random(8);
    final paint = Paint();
    for (var i = 0; i < 220; i++) {
      final a = rand.nextDouble() * math.pi * 2 + t * math.pi * 2 * speed;
      final d = r * (0.22 + rand.nextDouble() * 0.92);
      final p = c + Offset(math.cos(a) * d, math.sin(a) * d * 0.92);
      final isGreen = rand.nextDouble() < greenBias;
      paint.color = (isGreen ? kNeonGreen : kNeonRed)
          .withOpacity(0.55 + rand.nextDouble() * 0.4);
      canvas.drawCircle(p, rand.nextDouble() * 1.7 + 0.5, paint);
    }
  }

  void _paintRings(
    Canvas canvas,
    Offset c,
    double r, {
    required double speed,
    required int rings,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < rings; i++) {
      canvas.save();
      canvas.rotate(t * math.pi * 2 * speed + i * 0.9);
      paint.color = (i.isEven ? kNeonGreen : kCyan).withOpacity(0.55);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: r * (2.6 + i * 0.16),
          height: r * (0.66 + i * 0.1),
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintCore(Canvas canvas, Offset c, double r, {required double pulse}) {
    final coreR = r * (0.22 + pulse);
    canvas.drawCircle(
      c,
      coreR * 1.9,
      Paint()
        ..shader = RadialGradient(colors: [
          kNeonRed.withOpacity(0.5),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: c, radius: coreR * 1.9)),
    );
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = const RadialGradient(colors: [
          Colors.white,
          kNeonRed,
          Color(0xFF660018),
        ]).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
  }

  void _paintWave(Canvas canvas, Offset c, double r, int waves) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var i = 0; i < waves; i++) {
      final phase = (t * waves + i) / waves;
      final radius = r * (1.0 + phase * 1.4);
      paint.color = kNeonGreen.withOpacity((1 - phase) * 0.35);
      canvas.drawCircle(c, radius, paint);
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final paint = Paint();
    for (var i = 0; i < 40; i++) {
      final p = Offset(rand.nextDouble() * size.width,
          rand.nextDouble() * size.height);
      final tw = 0.25 + 0.55 * (0.5 + 0.5 * math.sin((t + i / 40) * math.pi * 2));
      paint.color = Colors.white.withOpacity(tw * 0.5);
      canvas.drawCircle(p, rand.nextDouble() * 1.2 + 0.3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OrbPainter old) =>
      old.t != t || old.state != state;
}
