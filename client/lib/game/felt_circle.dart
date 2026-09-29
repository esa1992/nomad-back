import 'dart:ui';

import 'package:client/game/knucklebone_look.dart';
import 'package:client/schema/table_constants.dart';
import 'package:flame/components.dart';

/// Packed-earth scoring circle. Not a collider (D-07).
class FeltCircle extends PositionComponent {
  static const Color fill = Color(0xFF5C3C22);
  static const Color rimIdle = Color(0xFFE8D4A8);
  static const Color rimFlash = Color(0xFFF0B429);

  FeltCircle()
    : super(
        anchor: Anchor.center,
        size: Vector2.all(TableConstants.circleRadiusM * 2),
      );

  /// Optional table_fx rim tint (presentation only; set at match start).
  Color? rimTint;

  double _flashRemainingS = 0;

  /// Accent rim for [ms] when a target first exits (D-07, UI-SPEC).
  void flashRim([int ms = 200]) {
    _flashRemainingS = ms / 1000;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashRemainingS > 0) {
      _flashRemainingS -= dt;
      if (_flashRemainingS < 0) {
        _flashRemainingS = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final r = TableConstants.circleRadiusM;
    final center = Offset(r, r);
    KnuckleboneLook.paintPit(
      canvas,
      center: center,
      radius: r,
      rim: _flashRemainingS > 0 ? rimFlash : (rimTint ?? rimIdle),
      flashing: _flashRemainingS > 0,
    );
  }
}
