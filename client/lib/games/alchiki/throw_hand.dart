import 'dart:math' as math;

import 'package:client/game/knucklebone_look.dart';
import 'package:client/input/aim_controller.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// First-person throw arm in screen space. Ignores hits so Hold Throw stays free.
class ThrowHandHud extends PositionComponent {
  ThrowHandHud({
    required this.aim,
    required this.visible,
    required this.chargeT,
    required this.flickT,
    required this.sakaFill,
    required this.sakaCrease,
  }) : super(priority: 80, anchor: Anchor.bottomCenter);

  final AimController Function() aim;
  final bool Function() visible;
  final double Function() chargeT;
  final double Function() flickT;
  final Color Function() sakaFill;
  final Color Function() sakaCrease;

  void _place(Vector2 size) {
    // Sit just below the scoring circle (south rim), above Hold Throw.
    position = Vector2(size.x * 0.5, size.y * 0.72);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final Vector2? gameSize = findGame()?.size;
    if (gameSize != null && gameSize.x > 0 && gameSize.y > 0) {
      _place(gameSize);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _place(size);
  }

  @override
  void render(Canvas canvas) {
    if (!visible()) {
      return;
    }
    final double charge = chargeT().clamp(0.0, 1.0);
    final double flick = flickT().clamp(0.0, 1.0);
    final double opacity = 0.58 * (1 - flick * 0.9);
    if (opacity <= 0.02) {
      return;
    }
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    final double wind = charge * 28 - flick * 56;
    canvas.translate(0, wind);
    canvas.rotate(math.pi / 2 - aim().aimAngleRad);
    _paintArm(canvas, charge);
    canvas.restore();
  }

  void _paintArm(Canvas canvas, double charge) {
    const Color skin = Color(0xFFC9A07A);
    const Color skinDeep = Color(0xFF9A704E);
    const Color skinLit = Color(0xFFE0C09A);
    final Paint fill = Paint()..color = skin;
    final Paint shade = Paint()..color = skinDeep;
    final Paint lit = Paint()..color = skinLit;

    // Forearm rising from bottom of HUD.
    final Path forearm = Path()
      ..moveTo(-22, 110)
      ..quadraticBezierTo(-28, 50, -18, 18)
      ..lineTo(18, 18)
      ..quadraticBezierTo(28, 50, 22, 110)
      ..close();
    canvas.drawPath(forearm, fill);
    canvas.drawPath(
      Path()
        ..moveTo(-14, 108)
        ..quadraticBezierTo(-18, 55, -10, 22)
        ..lineTo(-2, 22)
        ..quadraticBezierTo(-8, 55, -6, 108)
        ..close(),
      shade,
    );

    // Palm / back of hand.
    final Path palm = Path()
      ..moveTo(-30, 16)
      ..quadraticBezierTo(-36, -6, -22, -22)
      ..quadraticBezierTo(0, -30, 24, -20)
      ..quadraticBezierTo(34, -4, 28, 14)
      ..quadraticBezierTo(8, 24, -30, 16)
      ..close();
    canvas.drawPath(palm, fill);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-8, -2), width: 22, height: 16),
      lit,
    );

    // Thumb (left).
    final Path thumb = Path()
      ..moveTo(-28, -4)
      ..quadraticBezierTo(-44, -10, -46, -22)
      ..quadraticBezierTo(-38, -30, -26, -18)
      ..close();
    canvas.drawPath(thumb, fill);
    canvas.drawPath(thumb, Paint()
      ..color = skinDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Fingers curling around the saka.
    _finger(canvas, const Offset(-10, -26), -0.35, fill, shade);
    _finger(canvas, const Offset(2, -30), -0.05, fill, shade);
    _finger(canvas, const Offset(14, -26), 0.28, fill, shade);
    _finger(canvas, const Offset(24, -18), 0.55, fill, shade);

    // Held saka between thumb and fingers.
    canvas.save();
    canvas.translate(0, -22 - charge * 5);
    canvas.scale(1.05, 1.05);
    KnuckleboneLook.paint(
      canvas,
      center: Offset.zero,
      radius: 15,
      fill: sakaFill(),
      crease: sakaCrease(),
      bodyAngle: 0.35,
      shooter: true,
    );
    canvas.restore();
  }

  void _finger(
    Canvas canvas,
    Offset base,
    double tilt,
    Paint fill,
    Paint shade,
  ) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    final RRect digit = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-6, -28, 12, 32),
      const Radius.circular(6),
    );
    canvas.drawRRect(digit, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -26, 4, 28),
        const Radius.circular(3),
      ),
      shade,
    );
    // Knuckle tip.
    canvas.drawOval(
      const Rect.fromLTWH(-5, -30, 10, 10),
      fill,
    );
    canvas.restore();
  }
}
