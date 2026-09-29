import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 2.5D astragalus (alchik) — presentation only. Colliders stay circles.
abstract final class KnuckleboneLook {
  static void paint(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color fill,
    required Color crease,
    required double bodyAngle,
    bool shooter = false,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    canvas.save();
    canvas.rotate(-bodyAngle);
    final double rx = radius * (shooter ? 1.22 : 1.16);
    final double ry = radius * (shooter ? 0.72 : 0.68);
    final Rect shadow = Rect.fromCenter(
      center: Offset(rx * 0.12, -ry * 0.55),
      width: rx * 2.15,
      height: ry * 1.35,
    );
    canvas.drawOval(
      shadow,
      Paint()
        ..color = const Color(0x73000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
    );
    canvas.restore();

    final double long = radius * (shooter ? 1.18 : 1.12);
    final double short = radius * (shooter ? 0.78 : 0.74);
    final Rect body = Rect.fromCenter(
      center: Offset.zero,
      width: long * 2,
      height: short * 2,
    );
    final Color lit = Color.lerp(fill, const Color(0xFFFFFFF4), 0.34)!;
    final Color shade = Color.lerp(fill, const Color(0xFF1A1008), 0.42)!;
    canvas.drawOval(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.42),
          radius: 1.05,
          colors: <Color>[lit, fill, shade],
          stops: const <double>[0, 0.46, 1],
        ).createShader(body),
    );

    final RRect facet = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -short * 0.12),
        width: long * 1.35,
        height: short * 0.95,
      ),
      Radius.circular(short * 0.55),
    );
    canvas.drawRRect(
      facet,
      Paint()..color = Color.lerp(fill, lit, 0.35)!.withValues(alpha: 0.55),
    );

    canvas.drawOval(
      body,
      Paint()
        ..color = crease.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.07,
    );

    final Paint mark = Paint()
      ..color = crease
      ..strokeWidth = radius * (shooter ? 0.16 : 0.14)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-long * 0.62, short * 0.04),
      Offset(long * 0.62, -short * 0.04),
      mark,
    );
    if (!shooter) {
      canvas.drawLine(
        Offset(long * 0.08, -short * 0.35),
        Offset(long * 0.55, short * 0.08),
        Paint()
          ..color = crease.withValues(alpha: 0.85)
          ..strokeWidth = radius * 0.1
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-long * 0.28, -short * 0.32),
        width: long * 0.42,
        height: short * 0.26,
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );
    canvas.restore();
  }

  static void paintPit(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color rim,
    required bool flashing,
  }) {
    const Color earthDeep = Color(0xFF24160E);
    const Color earthMid = Color(0xFF5C3C22);
    const Color earthLit = Color(0xFF8A5E34);

    // Soft contact shadow under the rim only — no large surround disk over the steppe.
    canvas.drawCircle(
      center,
      radius * 1.04,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05),
    );

    final Rect pit = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.18, -0.28),
          radius: 1.05,
          colors: const <Color>[earthLit, earthMid, earthDeep],
          stops: const <double>[0.08, 0.55, 1],
        ).createShader(pit),
    );

    canvas.drawCircle(
      center,
      radius * 0.86,
      Paint()
        ..color = const Color(0x22000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08,
    );

    final math.Random grit = math.Random(7);
    for (int i = 0; i < 90; i++) {
      final double ang = grit.nextDouble() * math.pi * 2;
      final double dist = math.sqrt(grit.nextDouble()) * radius * 0.93;
      final double speck = radius * (0.012 + grit.nextDouble() * 0.018);
      canvas.drawCircle(
        center + Offset(math.cos(ang) * dist, math.sin(ang) * dist),
        speck,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF3A2414),
            const Color(0xFFC4A574),
            grit.nextDouble(),
          )!
              .withValues(alpha: 0.35 + grit.nextDouble() * 0.25),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = flashing ? const Color(0xFFF0B429) : rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.024,
    );
    canvas.drawCircle(
      center,
      radius * 0.985,
      Paint()
        ..color = const Color(0x66F4E8C8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.007,
    );
  }
}
