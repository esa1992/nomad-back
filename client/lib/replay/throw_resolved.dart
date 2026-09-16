import 'dart:convert';

import 'package:client/input/throw_input.dart';

/// Closed JVM buffer. dart:convert only. Keyframes win over local poses (D-10).
class ThrowResolved {
  static const int schemaVersionRequired = 1;
  static const int maxKeyframes = 40;
  static const int maxBodies = 8;

  static const ThrowInput goldenInput = ThrowInput(
    schemaVersion: 1,
    yUp: true,
    aimAngleRad: 1.0471975512,
    holdMs: 640,
    seed: 1,
    tableId: 'alchiki-proto-v1',
  );

  const ThrowResolved({
    required this.schemaVersion,
    required this.yUp,
    required this.input,
    required this.pocketedCount,
    required this.sakaOut,
    required this.pocketedIds,
    required this.keyframes,
  });

  final int schemaVersion;
  final bool yUp;
  final ThrowInput input;
  final int pocketedCount;
  final bool sakaOut;
  final List<String> pocketedIds;
  final List<ReplayKeyframe> keyframes;

  /// HUD scored value: saka leaving the circle scores 0 (D-08, CR-02).
  int displayedScore() => sakaOut ? 0 : pocketedCount;

  static ThrowResolved parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('ThrowResolved JSON must be an object');
    }
    return parseMap(Map<String, Object?>.from(decoded));
  }

  static ThrowResolved parseMap(Map<String, Object?> json) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();
    if (schemaVersion != schemaVersionRequired) {
      throw FormatException(
        'schemaVersion must be $schemaVersionRequired, got $schemaVersion',
      );
    }
    if (json['yUp'] != true) {
      throw const FormatException('yUp must be true');
    }

    final inputRaw = json['input'];
    if (inputRaw is! Map) {
      throw const FormatException('input must be an object');
    }
    // ThrowInput.parse clamps holdMs — matching never re-throws file hold (T-01-03).
    final input = ThrowInput.parse(Map<String, Object?>.from(inputRaw));

    final pocketedRaw = json['pocketedCount'];
    if (pocketedRaw is! num || !pocketedRaw.toDouble().isFinite) {
      throw const FormatException('pocketedCount must be finite');
    }
    final pocketedCount = pocketedRaw.toInt();
    if (pocketedCount < 0) {
      throw const FormatException('pocketedCount must be >= 0');
    }

    final sakaOut = json['sakaOut'];
    if (sakaOut is! bool) {
      throw const FormatException('sakaOut must be a boolean');
    }

    final pocketedIds = <String>[];
    final idsRaw = json['pocketedIds'];
    if (idsRaw is List) {
      for (final id in idsRaw) {
        if (id is String && id.isNotEmpty) {
          pocketedIds.add(id);
        }
      }
    }

    final framesRaw = json['keyframes'];
    if (framesRaw is! List) {
      throw const FormatException('keyframes must be an array');
    }
    if (framesRaw.length > maxKeyframes) {
      throw FormatException('keyframes cap is $maxKeyframes');
    }

    final keyframes = <ReplayKeyframe>[];
    for (final frame in framesRaw) {
      if (frame is! Map) {
        throw const FormatException('keyframe must be an object');
      }
      keyframes.add(_parseKeyframe(Map<String, Object?>.from(frame)));
    }

    return ThrowResolved(
      schemaVersion: schemaVersionRequired,
      yUp: true,
      input: input,
      pocketedCount: pocketedCount,
      sakaOut: sakaOut,
      pocketedIds: List.unmodifiable(pocketedIds),
      keyframes: List.unmodifiable(keyframes),
    );
  }

  static ReplayKeyframe _parseKeyframe(Map<String, Object?> json) {
    final tRaw = json['tMs'];
    if (tRaw is! num || !tRaw.toDouble().isFinite) {
      throw const FormatException('tMs must be finite');
    }
    final bodiesRaw = json['bodies'];
    if (bodiesRaw is! List) {
      throw const FormatException('bodies must be an array');
    }
    if (bodiesRaw.length > maxBodies) {
      throw FormatException('bodies cap is $maxBodies');
    }
    final bodies = <ReplayBodyPose>[];
    for (final raw in bodiesRaw) {
      if (raw is! Map) {
        throw const FormatException('body pose must be an object');
      }
      bodies.add(_parseBody(Map<String, Object?>.from(raw)));
    }
    return ReplayKeyframe(tMs: tRaw.toInt(), bodies: List.unmodifiable(bodies));
  }

  static ReplayBodyPose _parseBody(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('body id is required');
    }
    return ReplayBodyPose(
      id: id,
      x: _finite(json['x'], 'x'),
      y: _finite(json['y'], 'y'),
      angle: _finite(json['angle'], 'angle'),
    );
  }

  static double _finite(Object? value, String field) {
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('$field must be finite');
    }
    return value.toDouble();
  }

  /// Replay only if input matches the last throw or the baked golden (D-10).
  static bool allowsReplay(ThrowResolved resolved, ThrowInput? lastInput) {
    if (resolved.input == goldenInput) {
      return true;
    }
    return lastInput != null && resolved.input == lastInput;
  }
}

class ReplayKeyframe {
  const ReplayKeyframe({required this.tMs, required this.bodies});

  final int tMs;
  final List<ReplayBodyPose> bodies;
}

class ReplayBodyPose {
  const ReplayBodyPose({
    required this.id,
    required this.x,
    required this.y,
    required this.angle,
  });

  final String id;
  final double x;
  final double y;
  final double angle;
}
