import 'dart:math' as math;

import 'package:forge2d/forge2d.dart';

/// Drag-around-saka aim. Canonical angle is CCW from +X in Y-up meters (D-04).
class AimController {
  double aimAngleRad = 0;

  void updateFromWorldPoint(Vector2 worldYUp, Vector2 sakaPos) {
    final dx = worldYUp.x - sakaPos.x;
    final dy = worldYUp.y - sakaPos.y;
    if (dx * dx + dy * dy < 1e-10) {
      return;
    }
    aimAngleRad = math.atan2(dy, dx);
  }

  Vector2 get aimDir => Vector2(math.cos(aimAngleRad), math.sin(aimAngleRad));
}
