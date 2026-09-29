import 'dart:math' as math;
import 'dart:ui';

import 'package:client/game/knucklebone_look.dart';
import 'package:client/input/throw_input.dart';
import 'package:client/schema/table_constants.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

/// Shooter disk. Brighter than bones; stripe so spin reads (D-07).
class SakaBody extends BodyComponent {
  static const Color fill = Color(0xFFFFF6D6);
  static const Color stripe = Color(0xFF8B4513);

  /// RESEARCH spawn: on the rim, Y-up south.
  static final Vector2 spawn = Vector2(0, -1.15);

  SakaBody({
    Color fill = SakaBody.fill,
    Color stripe = SakaBody.stripe,
    Vector2? spawn,
    this.id = 'saka',
  }) : stripeColor = stripe,
       spawnPoint = (spawn ?? SakaBody.spawn).clone(),
       super(
         paint: Paint()..color = fill,
         bodyDef: BodyDef(
           type: BodyType.dynamic,
           position: (spawn ?? SakaBody.spawn).clone(),
           linearDamping: TableConstants.linearDamping,
           angularDamping: TableConstants.angularDamping,
           isAwake: true,
           allowSleep: true,
         ),
         fixtureDefs: [
           FixtureDef(
             CircleShape()..radius = TableConstants.sakaRadiusM,
             density: _density,
             friction: TableConstants.friction,
             restitution: TableConstants.restitution,
           ),
         ],
       );

  final String id;
  final Color stripeColor;
  final Vector2 spawnPoint;

  static double get _density {
    final r = TableConstants.sakaRadiusM;
    final area = math.pi * r * r;
    return TableConstants.sakaMassKg / area;
  }

  void applyThrowImpulse(ThrowInput input) {
    final impulse = ThrowInput.impulseFromHoldMs(input.holdMs);
    final aimDir = Vector2(
      math.cos(input.aimAngleRad),
      math.sin(input.aimAngleRad),
    );
    body.applyLinearImpulse(aimDir * impulse, wake: true);
  }

  void snapToSpawn() {
    body.setTransform(spawnPoint.clone(), 0);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    body.setAwake(true);
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    KnuckleboneLook.paint(
      canvas,
      center: center,
      radius: radius,
      fill: paint.color,
      crease: stripeColor,
      bodyAngle: body.angle,
      shooter: true,
    );
  }
}
