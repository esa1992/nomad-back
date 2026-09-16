import 'dart:ui';

import 'package:client/schema/table_constants.dart';
import 'package:flame/components.dart';

/// Render-only parlor felt. Not a collider (D-07).
class FeltCircle extends PositionComponent {
  static const Color fill = Color(0xFF1B6B3A);
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
    canvas.drawCircle(
      center,
      r,
      Paint()..color = fill,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = _flashRemainingS > 0
            ? rimFlash
            : (rimTint ?? rimIdle)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.03,
    );
  }
}
