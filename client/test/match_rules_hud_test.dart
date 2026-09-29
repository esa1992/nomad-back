import 'package:client/games/alchiki/match_page.dart';
import 'package:client/howto/alchiki_howto_page.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _HudApi extends NomadApi {
  _HudApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<MatchStart> startMatch({
    String difficulty = 'EASY',
    String game = 'ALCHIKI',
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return MatchStart(
      matchId: 'rules-hud-match',
      difficulty: 'EASY',
      boneIds: const <String>['b1', 'b2', 'b3', 'b4', 'b5'],
      turn: 'PLAYER',
      playerScore: 0,
      botScore: 0,
      turnDeadlineEpochMs: now + 20000,
      matchDeadlineEpochMs: now + 4 * 60 * 1000,
      hardCapEpochMs: now + 5 * 60 * 1000,
    );
  }
}

Future<void> _pumpMatchHud(WidgetTester tester) async {
  final SessionStore session = SessionStore.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(_HudApi(session)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AlchikiMatchPage(difficulty: 'EASY'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('match HUD shows you, bot, clear-circle goal, clocks, and pause', (
    WidgetTester tester,
  ) async {
    await _pumpMatchHud(tester);

    expect(find.textContaining('You'), findsWidgets);
    expect(find.textContaining('Bot'), findsWidgets);
    expect(find.textContaining('Clear circle'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && (widget.data?.startsWith('turn ') ?? false),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && (widget.data?.startsWith('match ') ?? false),
      ),
      findsOneWidget,
    );
  });

  testWidgets('fromPause how-to shows howtoCircleTitle and backToMatch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AlchikiHowToPage(difficulty: 'EASY', fromPause: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The circle'), findsOneWidget);
    expect(find.text('Back to match'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });
}
