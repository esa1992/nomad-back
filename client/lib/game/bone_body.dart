import 'dart:math' as math;
import 'dart:ui';

import 'package:client/schema/table_constants.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

/// Fully-outside pocket: distance from origin exceeds circle plus body radius.
bool isFullyOutside(
  double centerX,
  double centerY,
  double circleR,
  double bodyR,
) {
  return math.sqrt(centerX * centerX + centerY * centerY) > circleR + bodyR;
}

/// Target disk. Lighter than the saka; tick so rotation reads (D-07).
class BoneBody extends BodyComponent {
  static const Color fill = Color(0xFFD4A574);
  static const Color tick = Color(0xFF6B4423);

  final String boneId;
  final Vector2 spawn;

  BoneBody({required this.boneId, required Vector2 spawn})
    : spawn = spawn.clone(),
      super(
        paint: Paint()..color = fill,
        bodyDef: BodyDef(
          type: BodyType.dynamic,
          position: spawn.clone(),
          linearDamping: TableConstants.linearDamping,
          angularDamping: TableConstants.angularDamping,
          isAwake: true,
          allowSleep: true,
        ),
        fixtureDefs: [
          FixtureDef(
            CircleShape()..radius = TableConstants.boneRadiusM,
            density: _density,
            friction: TableConstants.friction,
            restitution: TableConstants.restitution,
          ),
        ],
      );

  static double get _density {
    final r = TableConstants.boneRadiusM;
    final area = math.pi * r * r;
    return TableConstants.boneMassKg / area;
  }

  void snapToSpawn() {
    body.setTransform(spawn.clone(), 0);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    body.setAwake(true);
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, paint);
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = radius * 0.16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(center.dx + radius, center.dy), tickPaint);
  }
}
