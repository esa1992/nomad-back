import 'package:client/games/alchiki/match_game.dart';
import 'package:client/games/alchiki/match_page.dart';
import 'package:client/input/throw_input.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/replay/throw_resolved.dart';
import 'package:client/schema/table_constants.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoMatchApi extends NomadApi {
  _NoMatchApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<MatchStart> startMatch({
    String difficulty = 'EASY',
    String game = 'ALCHIKI',
  }) async {
    return const MatchStart(
      matchId: 'hold-test-match',
      difficulty: 'EASY',
      boneIds: ['b1', 'b2', 'b3', 'b4', 'b5'],
      turn: 'PLAYER',
    );
  }
}

String _playerThrowJson({
  required List<String> pocketedIds,
  required List<Map<String, Object?>> lastBodies,
}) {
  final ids = pocketedIds.map((id) => '"$id"').join(', ');
  final bodies = lastBodies
      .map(
        (body) =>
            '{"id": "${body['id']}", "x": ${body['x']}, "y": ${body['y']}, "angle": ${body['angle']}}',
      )
      .join(', ');
  return '''
{
  "schemaVersion": 1,
  "yUp": true,
  "input": {
    "schemaVersion": 1,
    "yUp": true,
    "aimAngleRad": 0.5,
    "holdMs": 400,
    "seed": 1,
    "tableId": "alchiki-match-v1"
  },
  "table": { "circleRadiusM": 1.4 },
  "settled": true,
  "settleReason": "sleep",
  "simMs": 100,
  "pocketedCount": ${pocketedIds.length},
  "sakaOut": false,
  "pocketedIds": [$ids],
  "keyframes": [
    {"tMs": 0, "bodies": [{"id": "saka", "x": 0.0, "y": -1.15, "angle": 0.0}]},
    {"tMs": 100, "bodies": [$bodies]}
  ]
}
''';
}

void main() {
  testWidgets('Hold Throw is not enabled before AlchikiMatchGame.isLoaded', (
    WidgetTester tester,
  ) async {
    final SessionStore session = SessionStore.memory();
    final game = AlchikiMatchGame(difficulty: 'EASY');
    expect(game.isLoaded, isFalse);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(session),
          nomadApiProvider.overrideWithValue(_NoMatchApi(session)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AlchikiMatchPage(difficulty: 'EASY', game: game),
        ),
      ),
    );

    final AlchikiMatchPageState state = tester.state(
      find.byType(AlchikiMatchPage),
    );
    expect(state.game.isLoaded, isFalse);
    expect(state.holdEnabled, isFalse);
    expect(find.text('Hold Throw'), findsOneWidget);
  });

  testWidgets(
    'after keyframe replay, saka is at -1.15 and pocketed bone stays gone',
    (WidgetTester tester) async {
      final game = AlchikiMatchGame(difficulty: 'EASY');
      await tester.pumpWidget(
        GameWidget(game: game),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(game.isLoaded, isTrue);

      final resolved = ThrowResolved.parse(
        _playerThrowJson(
          pocketedIds: const ['b1'],
          lastBodies: const [
            {'id': 'saka', 'x': 0.4, 'y': -0.2, 'angle': 0.3},
            {'id': 'b2', 'x': 0.11, 'y': 0.19053, 'angle': 0.0},
            {'id': 'b3', 'x': -0.11, 'y': 0.19053, 'angle': 0.0},
            {'id': 'b4', 'x': -0.22, 'y': 0.0, 'angle': 0.0},
            {'id': 'b5', 'x': -0.11, 'y': -0.19053, 'angle': 0.0},
          ],
        ),
      );
      game.applyPlayerThrow(resolved);
      game.startTurn();

      expect(game.saka.body.worldCenter.x, closeTo(0, 1e-4));
      expect(game.saka.body.worldCenter.y, closeTo(-1.15, 1e-4));
      expect(
        game.bones.where((bone) => bone.isMounted).map((bone) => bone.boneId),
        isNot(contains('b1')),
      );

      final ThrowInput input = ThrowInput(
        schemaVersion: 1,
        yUp: true,
        aimAngleRad: 0.5,
        holdMs: 400,
        seed: 1,
        tableId: TableConstants.matchTableId,
      );
      game.throwSaka(input);
      expect(game.saka.body.worldCenter.x, closeTo(0, 0.05));
      expect(game.saka.body.worldCenter.y, closeTo(-1.15, 0.05));
    },
  );
}
