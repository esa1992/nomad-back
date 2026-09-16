import 'dart:math' as math;

import 'package:client/replay/throw_resolved.dart';

/// Closed-buffer playback target. Forge2D bodies adapt this in the game.
abstract class ReplayTarget {
  String get id;
  void setTransform(double x, double y, double angle);
}

/// Interpolates a closed JVM keyframe buffer. Not a live 60 Hz stream (D-10, D-11).
class KeyframePlayer {
  static void applyFrame(
    double tMs,
    List<ReplayKeyframe> keyframes,
    List<ReplayTarget> bodies,
  ) {
    if (keyframes.isEmpty) {
      return;
    }
    var i = keyframes.lastIndexWhere((frame) => frame.tMs <= tMs);
    if (i < 0) {
      i = 0;
    }
    final a = keyframes[i];
    final b = keyframes[math.min(i + 1, keyframes.length - 1)];
    final span = (b.tMs - a.tMs).toDouble();
    final u = span == 0 ? 1.0 : ((tMs - a.tMs) / span).clamp(0.0, 1.0);
    final posesA = {for (final pose in a.bodies) pose.id: pose};
    final posesB = {for (final pose in b.bodies) pose.id: pose};

    for (final body in bodies) {
      final from = posesA[body.id];
      if (from == null) {
        continue;
      }
      final to = posesB[body.id] ?? from;
      body.setTransform(
        _lerp(from.x, to.x, u),
        _lerp(from.y, to.y, u),
        _nlerpAngle(from.angle, to.angle, u),
      );
    }
  }

  static double _lerp(double a, double b, double u) => a + (b - a) * u;

  static double _nlerpAngle(double a, double b, double u) {
    final ax = math.cos(a);
    final ay = math.sin(a);
    final bx = math.cos(b);
    final by = math.sin(b);
    final x = ax + (bx - ax) * u;
    final y = ay + (by - ay) * u;
    final len = math.sqrt(x * x + y * y);
    if (len < 1e-12) {
      return a + (b - a) * u;
    }
    return math.atan2(y / len, x / len);
  }
}
