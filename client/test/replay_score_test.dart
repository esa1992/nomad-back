import 'dart:math' as math;

import 'package:client/input/throw_input.dart';
import 'package:client/replay/authority_score.dart';
import 'package:client/replay/keyframe_player.dart';
import 'package:client/replay/throw_resolved.dart';
import 'package:flutter_test/flutter_test.dart';

String _resolvedJson({
  int schemaVersion = 1,
  bool yUp = true,
  double aimAngleRad = 0.5,
  int holdMs = 400,
  int seed = 1,
  String tableId = 'alchiki-proto-v1',
  int pocketedCount = 2,
  bool sakaOut = false,
  List<String> pocketedIds = const [],
  List<Map<String, Object?>>? keyframes,
}) {
  final frames = keyframes ??
      [
        {
          'tMs': 0,
          'bodies': [
            {'id': 'saka', 'x': 0.0, 'y': 0.0, 'angle': 0.0},
          ],
        },
        {
          'tMs': 100,
          'bodies': [
            {'id': 'saka', 'x': 10.0, 'y': 20.0, 'angle': math.pi / 2},
          ],
        },
      ];
  return '''
{
  "schemaVersion": $schemaVersion,
  "yUp": $yUp,
  "input": {
    "schemaVersion": 1,
    "yUp": true,
    "aimAngleRad": $aimAngleRad,
    "holdMs": $holdMs,
    "seed": $seed,
    "tableId": "$tableId"
  },
  "table": {
    "circleRadiusM": 1.4
  },
  "settled": true,
  "settleReason": "sleep",
  "simMs": 100,
  "pocketedCount": $pocketedCount,
  "sakaOut": $sakaOut,
  "pocketedIds": ${_encodeIds(pocketedIds)},
  "keyframes": ${_encodeFrames(frames)}
}
''';
}

String _encodeIds(List<String> ids) {
  return '[${ids.map((id) => '"$id"').join(', ')}]';
}

String _encodeFrames(List<Map<String, Object?>> frames) {
  final parts = frames.map((frame) {
    final bodies = (frame['bodies'] as List).map((raw) {
      final body = raw as Map<String, Object?>;
      return '{"id": "${body['id']}", "x": ${body['x']}, "y": ${body['y']}, "angle": ${body['angle']}}';
    }).join(', ');
    return '{"tMs": ${frame['tMs']}, "bodies": [$bodies]}';
  }).join(', ');
  return '[$parts]';
}

ThrowInput _input({
  double aimAngleRad = 0.5,
  int holdMs = 400,
}) {
  return ThrowInput(
    schemaVersion: 1,
    yUp: true,
    aimAngleRad: aimAngleRad,
    holdMs: holdMs,
    seed: 1,
    tableId: 'alchiki-proto-v1',
  );
}

class _PoseTarget implements ReplayTarget {
  _PoseTarget(this.id);

  @override
  final String id;
  double x = 0;
  double y = 0;
  double angle = 0;

  @override
  void setTransform(double x, double y, double angle) {
    this.x = x;
    this.y = y;
    this.angle = angle;
  }
}

void main() {
  test('sakaOut true with pocketedCount 2 yields displayedScore 0', () {
    final resolved = ThrowResolved.parse(
      _resolvedJson(pocketedCount: 2, sakaOut: true),
    );
    expect(resolved.sakaOut, isTrue);
    expect(resolved.displayedScore(), 0);
    expect(
      AuthorityScore.displayedScore(resolved, lastInput: resolved.input),
      0,
    );
  });

  test('scored value equals ThrowResolved.pocketedCount', () {
    final resolved = ThrowResolved.parse(_resolvedJson(pocketedCount: 2));
    expect(
      AuthorityScore.readPocketedCount(
        resolved,
        lastInput: resolved.input,
      ),
      2,
    );
  });

  test('forged client pocketedCount is ignored', () {
    final resolved = ThrowResolved.parse(_resolvedJson(pocketedCount: 1));
    const forgedClientCount = 6;
    final scored = AuthorityScore.readPocketedCount(
      resolved,
      lastInput: resolved.input,
    );
    expect(scored, 1);
    expect(scored, isNot(forgedClientCount));
  });

  test('null resolved leaves scored blank', () {
    expect(
      AuthorityScore.readPocketedCount(null, lastInput: _input()),
      isNull,
    );
  });

  test('input mismatch disables replay and scored', () {
    final resolved = ThrowResolved.parse(_resolvedJson());
    final last = _input(aimAngleRad: 1.2, holdMs: 800);
    expect(ThrowResolved.allowsReplay(resolved, last), isFalse);
    expect(
      AuthorityScore.readPocketedCount(resolved, lastInput: last),
      isNull,
    );
  });

  test('matching last ThrowInput allows replay', () {
    final resolved = ThrowResolved.parse(_resolvedJson());
    expect(ThrowResolved.allowsReplay(resolved, resolved.input), isTrue);
  });

  test('baked golden input allows replay even if last throw differs', () {
    final resolved = ThrowResolved.parse(
      _resolvedJson(
        aimAngleRad: ThrowResolved.goldenInput.aimAngleRad,
        holdMs: ThrowResolved.goldenInput.holdMs,
        pocketedCount: 0,
      ),
    );
    expect(ThrowResolved.allowsReplay(resolved, _input()), isTrue);
    expect(
      AuthorityScore.readPocketedCount(resolved, lastInput: _input()),
      0,
    );
  });

  test('parse rejects schemaVersion other than 1', () {
    expect(
      () => ThrowResolved.parse(_resolvedJson(schemaVersion: 2)),
      throwsA(isA<FormatException>()),
    );
  });

  test('parse rejects yUp other than true', () {
    expect(
      () => ThrowResolved.parse(_resolvedJson(yUp: false)),
      throwsA(isA<FormatException>()),
    );
  });

  test('parse rejects non-finite numbers', () {
    expect(
      () => ThrowResolved.parse(_resolvedJson(aimAngleRad: double.nan)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ThrowResolved.parse(
        _resolvedJson(
          keyframes: [
            {
              'tMs': 0,
              'bodies': [
                {'id': 'saka', 'x': double.infinity, 'y': 0.0, 'angle': 0.0},
              ],
            },
          ],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('parse rejects more than 40 keyframes', () {
    final frames = [
      for (var i = 0; i < 41; i++)
        {
          'tMs': i * 10,
          'bodies': [
            {'id': 'saka', 'x': 0.0, 'y': 0.0, 'angle': 0.0},
          ],
        },
    ];
    expect(
      () => ThrowResolved.parse(_resolvedJson(keyframes: frames)),
      throwsA(isA<FormatException>()),
    );
  });

  test('parse rejects more than 8 bodies', () {
    final bodies = [
      for (var i = 0; i < 9; i++)
        {'id': 'b$i', 'x': 0.0, 'y': 0.0, 'angle': 0.0},
    ];
    expect(
      () => ThrowResolved.parse(
        _resolvedJson(
          keyframes: [
            {'tMs': 0, 'bodies': bodies},
          ],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('applyFrame lerps position and nlerps angle between JVM keyframes', () {
    final frames = [
      ReplayKeyframe(
        tMs: 0,
        bodies: const [
          ReplayBodyPose(id: 'saka', x: 0, y: 0, angle: 0),
        ],
      ),
      ReplayKeyframe(
        tMs: 100,
        bodies: const [
          ReplayBodyPose(id: 'saka', x: 10, y: 20, angle: math.pi / 2),
        ],
      ),
    ];
    final saka = _PoseTarget('saka');
    KeyframePlayer.applyFrame(50, frames, [saka]);
    expect(saka.x, closeTo(5, 1e-9));
    expect(saka.y, closeTo(10, 1e-9));
    expect(saka.angle, closeTo(math.pi / 4, 1e-9));
  });
}
