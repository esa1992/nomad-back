import 'package:client/games/alchiki/match_hud.dart';
import 'package:client/games/alchiki/match_page.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MatchHud _hud(
  AppLocalizations l10n, {
  bool isPrivate = false,
  String? opponentLabel,
  bool isPlayerTurn = false,
  int youScore = 0,
  int botScore = 0,
  String difficulty = 'EASY',
}) {
  return MatchHud(
    l10n: l10n,
    youScore: youScore,
    botScore: botScore,
    difficulty: difficulty,
    preview: 0,
    scored: null,
    sakaOut: false,
    turnClockLabel: 'turn 20',
    matchClockLabel: 'match 4:00',
    isPlayerTurn: isPlayerTurn,
    showTimeout: false,
    isPrivate: isPrivate,
    opponentLabel: opponentLabel,
  );
}

Future<void> _pumpHud(
  WidgetTester tester,
  MatchHud Function(AppLocalizations l10n) builder,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(body: builder(AppLocalizations.of(context)));
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
    'private HUD shows opponentsTurn, Guest-C9D0 pair, NORMAL, not Bot',
    (WidgetTester tester) async {
      await _pumpHud(
        tester,
        (AppLocalizations l10n) => _hud(
          l10n,
          isPrivate: true,
          opponentLabel: 'Guest-C9D0',
          isPlayerTurn: false,
          difficulty: 'NORMAL',
        ),
      );

      expect(find.text("Opponent's turn"), findsOneWidget);
      expect(find.text('You 0 — Guest-C9D0 0'), findsOneWidget);
      expect(find.text('First to 5 · NORMAL'), findsOneWidget);
      expect(find.textContaining('Bot'), findsNothing);
    },
  );

  testWidgets('bot HUD defaults still show botsTurn and not opponentsTurn', (
    WidgetTester tester,
  ) async {
    await _pumpHud(tester, (AppLocalizations l10n) => _hud(l10n));

    expect(find.text("Bot's turn"), findsOneWidget);
    expect(find.text("Opponent's turn"), findsNothing);
  });

  test('mapPrivateSeatHud remaps joiner scores and JOINER turn', () {
    final PrivateSeatHud hud = mapPrivateSeatHud(
      localPlayerId: 'J',
      hostId: 'H',
      joinerId: 'J',
      playerScore: 2,
      botScore: 1,
      turn: 'JOINER',
    );
    expect(hud.youScore, 1);
    expect(hud.oppScore, 2);
    expect(hud.localSeat, 'joiner');
    expect(hud.isPlayerTurn, isTrue);
  });

  test('mapPrivateSeatHud remaps host scores and not JOINER turn', () {
    final PrivateSeatHud hud = mapPrivateSeatHud(
      localPlayerId: 'H',
      hostId: 'H',
      joinerId: 'J',
      playerScore: 2,
      botScore: 1,
      turn: 'JOINER',
    );
    expect(hud.youScore, 2);
    expect(hud.oppScore, 1);
    expect(hud.localSeat, 'host');
    expect(hud.isPlayerTurn, isFalse);
  });
}
