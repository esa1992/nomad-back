import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Static 8×8 dp disk 16px above the parked opponent saka (D-35). No angle.
class AimingMarker extends PositionComponent {
  AimingMarker({
    required this.isShown,
    required this.opponentWorldPos,
    required this.cameraZoom,
  }) : super(priority: 12, anchor: Anchor.center);

  static const Color fill = Color(0x66F4E8C8);
  static const double sizeDp = 8;
  static const double offsetDp = 16;

  final bool Function() isShown;
  final Vector2 Function() opponentWorldPos;
  final double Function() cameraZoom;

  @override
  void render(Canvas canvas) {
    if (!isShown()) {
      return;
    }
    final double zoom = cameraZoom();
    if (zoom <= 0) {
      return;
    }
    final double radiusM = (sizeDp / 2) / zoom;
    final Vector2 above = opponentWorldPos() + Vector2(0, offsetDp / zoom);
    canvas.drawCircle(
      above.toOffset(),
      radiusM,
      Paint()..color = fill,
    );
  }
}
