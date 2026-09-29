import 'dart:math' as math;
import 'dart:ui';

import 'package:client/game/bone_body.dart';
import 'package:client/game/saka_body.dart';
import 'package:client/schema/table_constants.dart';
import 'package:flame/components.dart';

class _TrailDot {
  _TrailDot(this.pos, this.age);

  final Vector2 pos;
  double age;
}

class _DustPuff {
  _DustPuff(this.pos)
    : age = 0,
      seed = pos.x * 13.1 + pos.y * 7.7;

  final Vector2 pos;
  final double seed;
  double age;
}

/// Motion ribbon + dirt puffs. Presentation only — does not touch bodies.
class ThrowJuice extends PositionComponent {
  ThrowJuice({
    required this.isLive,
    required this.saka,
    required this.bones,
    required this.trailColor,
    required this.onImpact,
  }) : super(priority: 8);

  final bool Function() isLive;
  final SakaBody Function() saka;
  final List<BoneBody> Function() bones;
  final Color Function() trailColor;
  final void Function() onImpact;

  final List<_TrailDot> _trail = <_TrailDot>[];
  final List<_DustPuff> _dust = <_DustPuff>[];
  final Map<String, double> _lastDist = <String, double>{};
  final Map<String, double> _cool = <String, double>{};
  double _sampleAcc = 0;

  @override
  void update(double dt) {
    super.update(dt);
    for (final String id in _cool.keys.toList()) {
      _cool[id] = (_cool[id] ?? 0) - dt;
    }
    for (final _TrailDot dot in _trail) {
      dot.age += dt;
    }
    _trail.removeWhere((_TrailDot d) => d.age > 0.32);
    for (final _DustPuff puff in _dust) {
      puff.age += dt;
    }
    _dust.removeWhere((_DustPuff p) => p.age > 0.42);

    if (!isLive()) {
      _trail.clear();
      _lastDist.clear();
      return;
    }
    if (!saka().isMounted) {
      return;
    }
    _sampleAcc += dt;
    if (_sampleAcc >= 0.018) {
      _sampleAcc = 0;
      _trail.add(_TrailDot(saka().body.worldCenter.clone(), 0));
    }
    _detectHits();
  }

  void _detectHits() {
    final Vector2 from = saka().body.worldCenter;
    const double pad = 0.025;
    for (final BoneBody bone in bones()) {
      if (!bone.isMounted) {
        continue;
      }
      final Vector2 to = bone.body.worldCenter;
      final double dist = from.distanceTo(to);
      final double limit =
          TableConstants.sakaRadiusM + TableConstants.boneRadiusM + pad;
      final double? prev = _lastDist[bone.boneId];
      _lastDist[bone.boneId] = dist;
      if (prev == null) {
        continue;
      }
      final bool closing = dist < prev - 0.004;
      final bool touching = dist < limit;
      final double cool = _cool[bone.boneId] ?? 0;
      if (touching && closing && cool <= 0) {
        _dust.add(_DustPuff((from + to) / 2));
        _cool[bone.boneId] = 0.14;
        onImpact();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final Color tint = trailColor();
    for (final _TrailDot dot in _trail) {
      final double t = (dot.age / 0.32).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dot.pos.x, dot.pos.y),
          width: 0.11 * (1 - t * 0.4),
          height: 0.07 * (1 - t * 0.4),
        ),
        Paint()..color = tint.withValues(alpha: 0.38 * (1 - t)),
      );
    }
    for (final _DustPuff puff in _dust) {
      final double t = (puff.age / 0.42).clamp(0.0, 1.0);
      final double spread = 0.04 + t * 0.14;
      for (int i = 0; i < 5; i++) {
        final double a = puff.seed + i * 1.26;
        canvas.drawCircle(
          Offset(
            puff.pos.x + math.cos(a) * spread,
            puff.pos.y + math.sin(a) * spread * 0.7,
          ),
          0.03 * (1 - t),
          Paint()
            ..color = const Color(0xFFC4A574).withValues(alpha: 0.42 * (1 - t)),
        );
      }
    }
  }
}
