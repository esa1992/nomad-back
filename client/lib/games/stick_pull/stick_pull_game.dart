import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Flame 1D tug lane — no Forge2D / Alchiki imports (D-81).
class StickPullGame extends FlameGame {
  StickPullGame({this.shaftColor = const Color(0xFF8B5A2B)});

  static const Color felt = Color(0xFF1B6B3A);
  static const Color surround = Color(0xFF241810);
  static const Color rim = Color(0xFFE8D4A8);
  static const Color markerFill = Color(0xFFF4E8C8);
  static const Color accent = Color(0xFFF0B429);
  static const Color defaultShaft = Color(0xFF8B5A2B);
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
  Color backgroundColor() => surround;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(_Lane());
    add(_Stick());
    add(_MarkerKnot());
    add(_ThresholdTick(at: -0.85));
    add(_ThresholdTick(at: 0.85));
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
}

class _Lane extends PositionComponent with HasGameReference<StickPullGame> {
  @override
  Future<void> onLoad() async {
    size = game.size;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void render(Canvas canvas) {
    final RRect lane = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x * 0.18, size.y * 0.12, size.x * 0.64, size.y * 0.76),
      const Radius.circular(16),
    );
    canvas.drawRRect(lane, Paint()..color = StickPullGame.felt);
  }
}

class _Stick extends PositionComponent with HasGameReference<StickPullGame> {
  @override
  void render(Canvas canvas) {
    final double cx = game.size.x * 0.5;
    final double top = game.size.y * 0.16;
    final double bottom = game.size.y * 0.84;
    final Paint shaft = Paint()
      ..color = game.shaftColor
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint outline = Paint()
      ..color = StickPullGame.rim
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), outline);
    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), shaft);
  }
}

class _MarkerKnot extends PositionComponent with HasGameReference<StickPullGame> {
  @override
  void render(Canvas canvas) {
    final double cx = game.size.x * 0.5;
    final double top = game.size.y * 0.16;
    final double bottom = game.size.y * 0.84;
    // marker −1 = near/bottom, +1 = far/top
    final double t = (1 - game.displayMarker) * 0.5;
    final double y = top + (bottom - top) * t;
    final Color fill =
        game.thresholdFlash ? StickPullGame.accent : StickPullGame.markerFill;
    canvas.drawCircle(Offset(cx, y), 16, Paint()..color = fill);
    canvas.drawCircle(
      Offset(cx, y),
      16,
      Paint()
        ..color = StickPullGame.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

class _ThresholdTick extends PositionComponent with HasGameReference<StickPullGame> {
  _ThresholdTick({required this.at});

  final double at;

  @override
  void render(Canvas canvas) {
    final double cx = game.size.x * 0.5;
    final double top = game.size.y * 0.16;
    final double bottom = game.size.y * 0.84;
    final double t = (1 - at) * 0.5;
    final double y = top + (bottom - top) * t;
    final Paint paint = Paint()
      ..color = StickPullGame.rim
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx - 28, y), Offset(cx + 28, y), paint);
  }
}
