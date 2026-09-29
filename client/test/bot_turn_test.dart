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

class _BotTurnApi extends NomadApi {
  _BotTurnApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<MatchStart> startMatch({
    String difficulty = 'EASY',
    String game = 'ALCHIKI',
  }) async {
    return const MatchStart(
      matchId: 'bot-turn-match',
      difficulty: 'EASY',
      boneIds: <String>['b1', 'b2', 'b3', 'b4', 'b5'],
      turn: 'PLAYER',
    );
  }
}

ThrowResolved _botResolved({required List<String> pocketedIds}) {
  final String ids = pocketedIds.map((String id) => '"$id"').join(', ');
  return ThrowResolved.parse('''
{
  "schemaVersion": 1,
  "yUp": true,
  "input": {
    "schemaVersion": 1,
    "yUp": true,
    "aimAngleRad": 0.4,
    "holdMs": 280,
    "seed": 1,
    "tableId": "alchiki-match-v1"
  },
  "table": { "circleRadiusM": 1.4 },
  "settled": true,
  "settleReason": "sleep",
  "simMs": 80,
  "pocketedCount": ${pocketedIds.length},
  "sakaOut": false,
  "pocketedIds": [$ids],
  "keyframes": [
    {"tMs": 0, "bodies": [{"id": "saka", "x": 0.0, "y": -1.15, "angle": 0.0}]},
    {"tMs": 80, "bodies": [
      {"id": "saka", "x": 0.2, "y": -0.4, "angle": 0.1},
      {"id": "b2", "x": 0.11, "y": 0.19053, "angle": 0.0},
      {"id": "b3", "x": -0.11, "y": 0.19053, "angle": 0.0},
      {"id": "b4", "x": -0.22, "y": 0.0, "angle": 0.0},
      {"id": "b5", "x": -0.11, "y": -0.19053, "angle": 0.0}
    ]}
  ]
}
''');
}

void main() {
  testWidgets('when snapshot turn is BOT, Hold Throw is hidden and banner is botsTurn', (
    WidgetTester tester,
  ) async {
    final SessionStore session = SessionStore.memory();
    final AlchikiMatchGame game = AlchikiMatchGame(difficulty: 'EASY');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(session),
          nomadApiProvider.overrideWithValue(_BotTurnApi(session)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AlchikiMatchPage(difficulty: 'EASY', game: game),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final AlchikiMatchPageState state = tester.state(find.byType(AlchikiMatchPage));
    final ThrowInput botInput = ThrowInput(
      schemaVersion: 1,
      yUp: true,
      aimAngleRad: 0.4,
      holdMs: 280,
      seed: 1,
      tableId: TableConstants.matchTableId,
    );
    await state.playBotTurn(botInput, _botResolved(pocketedIds: const <String>[]));
    await tester.pump();

    expect(find.text('Hold Throw'), findsNothing);
    expect(find.text("Bot's turn"), findsOneWidget);
  });

  testWidgets(
    'after botThrow keyframe replay, saka is at -1.15 and pocketed bones stay gone',
    (WidgetTester tester) async {
      final SessionStore session = SessionStore.memory();
      final AlchikiMatchGame game = AlchikiMatchGame(difficulty: 'EASY');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(session),
            nomadApiProvider.overrideWithValue(_BotTurnApi(session)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AlchikiMatchPage(difficulty: 'EASY', game: game),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final AlchikiMatchPageState state = tester.state(
        find.byType(AlchikiMatchPage),
      );
      expect(state.game.isLoaded, isTrue);

      state.game.applyPlayerThrow(
        ThrowResolved.parse('''
{
  "schemaVersion": 1,
  "yUp": true,
  "input": {
    "schemaVersion": 1,
    "yUp": true,
    "aimAngleRad": 1.4,
    "holdMs": 640,
    "seed": 1,
    "tableId": "alchiki-match-v1"
  },
  "table": { "circleRadiusM": 1.4 },
  "settled": true,
  "settleReason": "sleep",
  "simMs": 100,
  "pocketedCount": 1,
  "sakaOut": false,
  "pocketedIds": ["b1"],
  "keyframes": [
    {"tMs": 0, "bodies": [{"id": "saka", "x": 0.0, "y": -1.15, "angle": 0.0}]},
    {"tMs": 100, "bodies": [
      {"id": "saka", "x": 0.3, "y": -0.2, "angle": 0.2},
      {"id": "b2", "x": 0.11, "y": 0.19053, "angle": 0.0}
    ]}
  ]
}
'''),
      );

      final ThrowInput botInput = ThrowInput(
        schemaVersion: 1,
        yUp: true,
        aimAngleRad: 0.4,
        holdMs: 280,
        seed: 1,
        tableId: TableConstants.matchTableId,
      );
      await state.playBotTurn(botInput, _botResolved(pocketedIds: const <String>[]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }

      expect(state.game.saka.body.worldCenter.x, closeTo(0, 1e-4));
      expect(state.game.saka.body.worldCenter.y, closeTo(-1.15, 1e-4));
      expect(
        state.game.bones.where((bone) => bone.isMounted).map((bone) => bone.boneId),
        isNot(contains('b1')),
      );
    },
  );
}
