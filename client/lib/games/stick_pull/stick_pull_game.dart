import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Flame 1D tug lane — packed earth + volumetric stick (no Forge2D).
class StickPullGame extends FlameGame {
  StickPullGame({this.shaftColor = const Color(0xFFD4B896)});

  static const Color earth = Color(0xFF5C3C22);
  static const Color earthDeep = Color(0xFF24160E);
  static const Color earthLit = Color(0xFF8A5E34);
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
    _displayMarker += (marker - _displayMarker) * (dt * 18).clamp(0.0, 1.0);
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
  List<Offset>? _grit;
  List<double>? _gritSize;
  List<Color>? _gritColor;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    _grit = null;
  }

  void _ensureGrit(Rect lane) {
    if (_grit != null) {
      return;
    }
    final math.Random grit = math.Random(11);
    final List<Offset> pts = <Offset>[];
    final List<double> sizes = <double>[];
    final List<Color> colors = <Color>[];
    for (int i = 0; i < 160; i++) {
      pts.add(
        Offset(
          lane.left + grit.nextDouble() * lane.width,
          lane.top + grit.nextDouble() * lane.height,
        ),
      );
      sizes.add(0.6 + grit.nextDouble() * 1.8);
      colors.add(
        Color.lerp(
          const Color(0xFF3A2414),
          const Color(0xFFC4A574),
          grit.nextDouble(),
        )!
            .withValues(alpha: 0.28 + grit.nextDouble() * 0.35),
      );
    }
    _grit = pts;
    _gritSize = sizes;
    _gritColor = colors;
  }

  @override
  void render(Canvas canvas) {
    final Rect lane = game.laneRect;
    final RRect pad = RRect.fromRectAndRadius(lane, const Radius.circular(14));
    _ensureGrit(lane);

    // Soft contact shadow under the pit (Alchiki paintPit style).
    canvas.drawRRect(
      pad.inflate(3),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.save();
    canvas.clipRRect(pad);

    // Packed earth bowl — lit upper-left like Alchiki pit.
    canvas.drawRect(
      lane,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.22, -0.35),
          radius: 1.15,
          colors: const <Color>[
            StickPullGame.earthLit,
            StickPullGame.earth,
            StickPullGame.earthDeep,
          ],
          stops: const <double>[0.06, 0.5, 1],
        ).createShader(lane),
    );

    // Inner shade ring — dug bowl feel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        lane.deflate(lane.shortestSide * 0.04),
        const Radius.circular(10),
      ),
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lane.shortestSide * 0.055,
    );

    // Soil grit / pebbles.
    final List<Offset> pts = _grit!;
    final List<double> sizes = _gritSize!;
    final List<Color> colors = _gritColor!;
    for (int i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], sizes[i], Paint()..color = colors[i]);
    }

    // Center groove the stick slides in — recessed dirt trench.
    final double cx = lane.center.dx;
    final Rect trench = Rect.fromCenter(
      center: Offset(cx, lane.center.dy),
      width: 18,
      height: lane.height - 28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trench, const Radius.circular(9)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const <Color>[
            Color(0x8824160E),
            Color(0xCC1A1008),
            Color(0x8824160E),
          ],
        ).createShader(trench),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trench, const Radius.circular(9)),
      Paint()
        ..color = const Color(0x44C4A574)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.restore();

    // Cream rim (idle) — Alchiki felt rim language.
    canvas.drawRRect(
      pad,
      Paint()
        ..color = StickPullGame.rim.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawRRect(
      pad.deflate(1.2),
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

/// Volumetric wood shaft — cylindrical shading + end grain.
class _SlidingStick extends PositionComponent with HasGameReference<StickPullGame> {
  @override
  void render(Canvas canvas) {
    final Rect lane = game.laneRect;
    final double y = game.markerY(game.displayMarker);
    final double half = lane.width * 0.38;
    final double cx = lane.center.dx;
    final double thickness = 28;
    final Color wood = game.thresholdFlash
        ? StickPullGame.accent
        : game.shaftColor;
    final Color shade = Color.lerp(wood, const Color(0xFF2A180C), 0.55)!;
    final Color mid = Color.lerp(wood, const Color(0xFF5A3A1C), 0.2)!;
    final Color lit = Color.lerp(wood, const Color(0xFFFFFFF0), 0.45)!;

    final Rect bodyRect = Rect.fromCenter(
      center: Offset(cx, y),
      width: half * 2,
      height: thickness,
    );
    final RRect body = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(thickness / 2),
    );

    // Ground contact shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, y + thickness * 0.42),
        width: half * 1.85,
        height: 10,
      ),
      Paint()
        ..color = const Color(0x77000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Barrel fill — top-lit cylinder.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[lit, wood, mid, shade],
          stops: const <double>[0.0, 0.32, 0.62, 1.0],
        ).createShader(bodyRect),
    );

    // Specular ridge along the top.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bodyRect.left + 10,
          bodyRect.top + 3,
          bodyRect.width - 20,
          thickness * 0.22,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0x55FFFFFF),
    );

    // Side depth strokes.
    canvas.drawRRect(
      body,
      Paint()
        ..color = StickPullGame.rim.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    _paintEndGrain(canvas, Offset(cx - half + 6, y), thickness * 0.48, lit, shade);
    _paintEndGrain(canvas, Offset(cx + half - 6, y), thickness * 0.48, shade, lit);
  }

  void _paintEndGrain(
    Canvas canvas,
    Offset c,
    double r,
    Color outer,
    Color inner,
  ) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[inner, outer, Color.lerp(outer, const Color(0xFF1A1008), 0.35)!],
          stops: const <double>[0.15, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.55,
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      c,
      r * 0.28,
      Paint()..color = const Color(0x553A2414),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = StickPullGame.rim.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
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
      ..color = StickPullGame.rim.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(lane.left + 16, y),
      Offset(lane.right - 16, y),
      paint,
    );
  }
}
