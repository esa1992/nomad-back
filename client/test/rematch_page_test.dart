import 'package:client/games/alchiki/match_game.dart';
import 'package:client/games/alchiki/match_page.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/platform/session/match_socket.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RematchApi extends NomadApi {
  _RematchApi(SessionStore session) : super(sessionStore: session);

  final List<String> wsTicketCalls = [];
  bool _accepted = false;

  @override
  Future<MatchStart> getMatch(String matchId) async {
    if (matchId == 'new-match-id') {
      return MatchStart(
        matchId: matchId,
        difficulty: 'NORMAL',
        boneIds: const <String>['b1', 'b2', 'b3', 'b4', 'b5', 'b6'],
        turn: 'JOINER',
        status: 'IN_PLAY',
        mode: 'PRIVATE',
        hostId: 'host-id',
        joinerId: 'joiner-id',
        hostLabel: 'Guest-HOST',
        joinerLabel: 'Guest-JOIN',
      );
    }
    return MatchStart(
      matchId: matchId,
      difficulty: 'NORMAL',
      boneIds: const <String>['b1', 'b2', 'b3', 'b4', 'b5', 'b6'],
      turn: 'HOST',
      status: 'HOST_WIN',
      mode: 'PRIVATE',
      hostId: 'host-id',
      joinerId: 'joiner-id',
      hostLabel: 'Guest-HOST',
      joinerLabel: 'Guest-JOIN',
      playerScore: 5,
      botScore: 2,
    );
  }

  @override
  Future<WsTicket> wsTicket(String matchId) async {
    wsTicketCalls.add(matchId);
    return const WsTicket(ticket: 'ticket');
  }

  int rematchCalls = 0;

  @override
  Future<RematchAccept> rematch(String matchId, {bool accept = true}) async {
    rematchCalls++;
    _accepted = true;
    return const RematchAccept(
      accepted: true,
      matchId: 'new-match-id',
      turn: 'JOINER',
    );
  }

  @override
  Future<RematchPoll> getRematch(String matchId) async {
    if (_accepted) {
      return const RematchPoll(
        acceptedHost: true,
        acceptedJoiner: true,
        rematchSeconds: 8,
        matchId: 'new-match-id',
      );
    }
    return const RematchPoll(
      acceptedHost: false,
      acceptedJoiner: false,
      rematchSeconds: 10,
    );
  }
}

void main() {
  testWidgets(
    'private ResultOverlay Again? then getRematch yields new matchId and GameWidget',
    (WidgetTester tester) async {
      final SessionStore session = SessionStore.memory();
      await session.persist(playerId: 'host-id', refreshToken: 'refresh');
      final _RematchApi api = _RematchApi(session);
      MatchSocket.debugConnect = (_) async => MatchSocket.stub();
      addTearDown(() {
        MatchSocket.debugConnect = null;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(session),
            nomadApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AlchikiMatchPage(
              mode: 'private',
              matchId: 'old-match-id',
              game: AlchikiMatchGame(difficulty: 'NORMAL', mode: 'private'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Again?'), findsOneWidget);
      await tester.tap(find.text('Again?'));
      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (api.wsTicketCalls.contains('new-match-id')) {
          break;
        }
      }
      await tester.pump();
      await tester.pump();

      expect(api.rematchCalls, greaterThan(0));
      expect(api.wsTicketCalls, contains('new-match-id'));
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget.runtimeType.toString().contains('GameWidget'),
        ),
        findsWidgets,
      );
    },
  );
}
