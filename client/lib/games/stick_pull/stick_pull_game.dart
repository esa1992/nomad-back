import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Flame 1D tug lane — packed earth + sliding stick (no Forge2D).
class StickPullGame extends FlameGame {
  StickPullGame({this.shaftColor = const Color(0xFFD4B896)});

  static const Color earth = Color(0xFF5C3C22);
  static const Color earthDeep = Color(0xFF24160E);
  static const Color surround = Color(0xFF0E1410);
  static const Color rim = Color(0xFFE8D4A8);
  static const Color accent = Color(0xFFF0B429);
  static const Color defaultShaft = Color(0xFFD4B896);
  static const Color iceShaft = Color(0xFF7EB6D9);

  /// Presentation-only loadout paint at GameWidget create (D-83 / D-54).
  static Color shaftColorForLoadout(Map<String, String> loadout) {
    final String? sku = loadout['stick_pull'];
    if (sku == null || sku.isEmpty) {
      return defaultShaft;
    }
    final String key = sku.toLowerCase();
    if (key.contains('ice')) {
      return iceShaft;
    }
    return defaultShaft;
  }

  final Color shaftColor;

  /// Server marker in [-1, +1]; local near = bottom (−1).
  double marker = 0;
  double _displayMarker = 0;
  bool thresholdFlash = false;
  double _thresholdFlashLeft = 0;

  void setMarker(double value) {
    marker = value.clamp(-1.0, 1.0);
  }

  void flashThreshold() {
    thresholdFlash = true;
    _thresholdFlashLeft = 0.2;
  }

  /// Cream → accent pulse when local stamina exhausts (D-81 / UI-SPEC).
  void flashExhaust() {
    thresholdFlash = true;
    _thresholdFlashLeft = 0.2;
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(_Ground());
    add(_ThresholdTick(at: -0.85));
    add(_ThresholdTick(at: 0.85));
    add(_SlidingStick());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _displayMarker += (marker - _displayMarker) * (dt * 10).clamp(0.0, 1.0);
    if (_thresholdFlashLeft > 0) {
      _thresholdFlashLeft -= dt;
      if (_thresholdFlashLeft <= 0) {
        thresholdFlash = false;
        _thresholdFlashLeft = 0;
      }
    }
  }

  double get displayMarker => _displayMarker;

  Rect get laneRect {
    return Rect.fromLTWH(
      size.x * 0.14,
      size.y * 0.14,
      size.x * 0.72,
      size.y * 0.58,
    );
  }

  double markerY(double at) {
    final Rect lane = laneRect;
    final double t = (1 - at) * 0.5;
    return lane.top + lane.height * t;
  }
}

class _Ground extends PositionComponent with HasGameReference<StickPullGame> {
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void render(Canvas canvas) {
    final Rect lane = game.laneRect;
    final RRect pad = RRect.fromRectAndRadius(lane, const Radius.circular(12));
    canvas.drawRRect(
      pad,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.1,
          colors: const <Color>[
            Color(0xFF8A5E34),
            StickPullGame.earth,
            StickPullGame.earthDeep,
          ],
          stops: const <double>[0.05, 0.55, 1],
        ).createShader(lane),
    );
    canvas.drawRRect(
      pad,
      Paint()
        ..color = StickPullGame.rim.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Center groove the stick slides in.
    final double cx = lane.center.dx;
    canvas.drawLine(
      Offset(cx, lane.top + 12),
      Offset(cx, lane.bottom - 12),
      Paint()
        ..color = const Color(0x6624160E)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }
}

/// Light wood stick that slides toward local (bottom) or opponent (top).
class _SlidingStick extends PositionComponent with HasGameReference<StickPullGame> {
  @override
  void render(Canvas canvas) {
    final Rect lane = game.laneRect;
    final double y = game.markerY(game.displayMarker);
    final double half = lane.width * 0.38;
    final double cx = lane.center.dx;
    final Color wood = game.thresholdFlash
        ? StickPullGame.accent
        : game.shaftColor;
    final Color shade = Color.lerp(wood, const Color(0xFF3A2414), 0.35)!;
    final Color lit = Color.lerp(wood, const Color(0xFFFFFFF0), 0.35)!;

    final RRect body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, y), width: half * 2, height: 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[lit, wood, shade],
          stops: const <double>[0, 0.45, 1],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = StickPullGame.rim.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // End caps — round wood tips.
    canvas.drawCircle(Offset(cx - half + 4, y), 11, Paint()..color = lit);
    canvas.drawCircle(Offset(cx + half - 4, y), 11, Paint()..color = shade);
    canvas.drawCircle(
      Offset(cx - half + 4, y),
      11,
      Paint()
        ..color = StickPullGame.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(cx + half - 4, y),
      11,
      Paint()
        ..color = StickPullGame.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }
}

class _ThresholdTick extends PositionComponent with HasGameReference<StickPullGame> {
  _ThresholdTick({required this.at});

  final double at;

  @override
  void render(Canvas canvas) {
    final Rect lane = game.laneRect;
    final double y = game.markerY(at);
    final Paint paint = Paint()
      ..color = StickPullGame.rim.withValues(alpha: 0.75)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(lane.left + 16, y),
      Offset(lane.right - 16, y),
      paint,
    );
  }
}
