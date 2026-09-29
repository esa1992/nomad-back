import 'dart:async';

import 'package:client/catalog/catalog_models.dart';
import 'package:client/games/alchiki/match_game.dart';
import 'package:client/games/alchiki/match_hud.dart';
import 'package:client/games/alchiki/match_page.dart';
import 'package:client/games/alchiki/pause_overlay.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/platform/session/match_socket.dart';
import 'package:client/platform/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const String _matchId = 'match-rejoin-1';
const String _token = 'reconnect-token';
const String _localSeat = 'host';
const String _playerId = '11111111-1111-1111-1111-111111111111';

class _StubApi extends NomadApi {
  _StubApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<GuestSession> mintGuest() async {
    await sessionStore.persist(
      playerId: _playerId,
      refreshToken: 'refresh-token',
    );
    accessToken = 'access-token';
    return const GuestSession(
      playerId: _playerId,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      guest: true,
    );
  }

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;

  @override
  Future<MatchStart> getMatch(String matchId) async {
    return MatchStart(
      matchId: matchId,
      difficulty: 'NORMAL',
      boneIds: const <String>['b1', 'b2', 'b3', 'b4', 'b5', 'b6'],
      turn: 'JOINER',
      status: 'IN_PLAY',
      mode: 'PRIVATE',
      hostId: _playerId,
      joinerId: '22222222-2222-2222-2222-222222222222',
      hostLabel: 'Guest-1111',
      joinerLabel: 'Guest-2222',
    );
  }

  @override
  Future<WsTicket> wsTicket(String matchId) async {
    return const WsTicket(ticket: 'ticket');
  }
}

class _ReconnectFlowApi extends _StubApi {
  _ReconnectFlowApi(SessionStore session) : super(session);

  int rejoinCalls = 0;
  int wsTicketCalls = 0;
  final List<String> callOrder = <String>[];
  int? reconnectSecondsLeft;

  @override
  Future<MatchStart> getMatch(String matchId) async {
    return MatchStart(
      matchId: matchId,
      difficulty: 'NORMAL',
      boneIds: const <String>['b1', 'b2', 'b3', 'b4', 'b5', 'b6'],
      turn: 'JOINER',
      status: 'IN_PLAY',
      mode: 'PRIVATE',
      hostId: _playerId,
      joinerId: '22222222-2222-2222-2222-222222222222',
      hostLabel: 'Guest-1111',
      joinerLabel: 'Guest-2222',
      reconnectSecondsLeft: reconnectSecondsLeft,
    );
  }

  @override
  Future<RejoinResult> rejoin(String matchId, String token) async {
    rejoinCalls++;
    callOrder.add('rejoin');
    return RejoinResult(
      match: await getMatch(matchId),
      reconnectToken: 'rotated-token',
    );
  }

  @override
  Future<WsTicket> wsTicket(String matchId) async {
    wsTicketCalls++;
    callOrder.add('wsTicket');
    return const WsTicket(ticket: 'ticket', reconnectToken: _token);
  }
}

class _FirstRejoinConflictApi extends _ReconnectFlowApi {
  _FirstRejoinConflictApi(SessionStore session) : super(session);

  @override
  Future<RejoinResult> rejoin(String matchId, String token) async {
    rejoinCalls++;
    callOrder.add('rejoin');
    if (rejoinCalls == 1) {
      throw NomadApiException('seat not dropped', statusCode: 409);
    }
    return RejoinResult(
      match: await getMatch(matchId),
      reconnectToken: 'rotated-token',
    );
  }
}

Future<void> _pumpLocalized(
  WidgetTester tester,
  Widget Function(AppLocalizations l10n) builder,
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

Future<void> _pumpApp(
  WidgetTester tester, {
  required SessionStore session,
  required NomadApi api,
  required String location,
}) async {
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
      child: NomadApp(initialLocation: location),
    ),
  );
}

Future<void> _pumpUntilRejoin(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  final int frames = SplashPage.minHold.inMilliseconds ~/ 50 + 20;
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Rejoin match').evaluate().isNotEmpty) {
      return;
    }
  }
}

Finder get _gameWidget => find.byWidgetPredicate(
      (Widget widget) => widget.runtimeType.toString().contains('GameWidget'),
    );

Future<void> _pumpUntilGameWidget(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (_gameWidget.evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _pumpMatchPage(
  WidgetTester tester, {
  required SessionStore session,
  required NomadApi api,
  required String matchId,
}) async {
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
          matchId: matchId,
          game: AlchikiMatchGame(difficulty: 'NORMAL', mode: 'private'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Rejoin overlay finds Rejoin match and does not find Back to catalog',
    (WidgetTester tester) async {
      await _pumpLocalized(
        tester,
        (AppLocalizations l10n) => RejoinOverlay(
          l10n: l10n,
          secondsLeft: 30,
          onRejoin: () {},
        ),
      );

      expect(find.text('Rejoin match'), findsOneWidget);
      expect(find.text('Back to catalog'), findsNothing);
    },
  );

  testWidgets('HUD-style banner finds Reconnecting', (WidgetTester tester) async {
    await _pumpLocalized(
      tester,
      (AppLocalizations l10n) => MatchHud(
        l10n: l10n,
        youScore: 0,
        botScore: 0,
        difficulty: 'NORMAL',
        preview: 0,
        scored: null,
        sakaOut: false,
        turnClockLabel: 'turn 20',
        matchClockLabel: 'match 4:00',
        isPlayerTurn: true,
        showTimeout: false,
        isPrivate: true,
        opponentLabel: 'Guest-C9D0',
        reconnectLabel: l10n.reconnecting('30'),
      ),
    );

    expect(find.textContaining('Reconnecting'), findsOneWidget);
  });

  test(
    'SessionStore.memory persistReconnect round-trips token, matchId, and localSeat',
    () async {
      final SessionStore session = SessionStore.memory();
      await session.persistReconnect(
        token: _token,
        matchId: _matchId,
        localSeat: _localSeat,
      );
      expect(await session.reconnectToken(), _token);
      expect(await session.reconnectMatchId(), _matchId);
      expect(await session.reconnectLocalSeat(), _localSeat);
    },
  );

  testWidgets(
    'cold start splash with reconnectMatchId opens Rejoin match not catalog',
    (WidgetTester tester) async {
      final SessionStore session = SessionStore.memory();
      await session.persist(
        playerId: _playerId,
        refreshToken: 'refresh-token',
      );
      await session.persistReconnect(
        token: _token,
        matchId: _matchId,
        localSeat: _localSeat,
      );
      final _StubApi api = _StubApi(session);
      await _pumpApp(
        tester,
        session: session,
        api: api,
        location: '/splash',
      );
      await _pumpUntilRejoin(tester);

      expect(find.text('Rejoin match'), findsOneWidget);
      expect(find.text('Create room'), findsNothing);
      final String location = GoRouter.of(
        tester.element(find.text('Rejoin match')),
      ).routeInformationProvider.value.uri.toString();
      expect(location, contains('mode=private'));
      expect(location, contains(_matchId));
    },
  );

  testWidgets(
    'cold start catalog with persistReconnect finds Rejoin match',
    (WidgetTester tester) async {
      final SessionStore session = SessionStore.memory();
      await session.persist(
        playerId: _playerId,
        refreshToken: 'refresh-token',
      );
      await session.persistReconnect(
        token: _token,
        matchId: _matchId,
        localSeat: _localSeat,
      );
      final _StubApi api = _StubApi(session);
      await _pumpApp(tester, session: session, api: api, location: '/');
      await _pumpUntilRejoin(tester);

      expect(find.text('Rejoin match'), findsOneWidget);
      expect(find.text('Create room'), findsNothing);
      final String location = GoRouter.of(
        tester.element(find.text('Rejoin match')),
      ).routeInformationProvider.value.uri.toString();
      expect(location, contains('mode=private'));
      expect(location, contains(_matchId));
    },
  );

  testWidgets(
    'isolate-alive socket drop POSTs rejoin then wsTicket and hides Rejoin match',
    (WidgetTester tester) async {
      final SessionStore session = SessionStore.memory();
      await session.persist(
        playerId: _playerId,
        refreshToken: 'refresh-token',
      );
      final _ReconnectFlowApi api = _ReconnectFlowApi(session);
      final StreamController<Map<String, dynamic>> incoming =
          StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(() async {
        if (!incoming.isClosed) {
          await incoming.close();
        }
      });
      int connects = 0;
      MatchSocket.debugConnect = (_) async {
        connects++;
        if (connects == 1) {
          return MatchSocket.stub(incoming: incoming);
        }
        return MatchSocket.stub();
      };
      addTearDown(() {
        MatchSocket.debugConnect = null;
      });

      await _pumpMatchPage(
        tester,
        session: session,
        api: api,
        matchId: _matchId,
      );
      await _pumpUntilGameWidget(tester);
      expect(_gameWidget, findsWidgets);

      await session.persistReconnect(
        token: _token,
        matchId: _matchId,
        localSeat: _localSeat,
      );
      if (!incoming.isClosed) {
        await incoming.close();
      }
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final int rejoinAt = api.callOrder.indexOf('rejoin');
        if (api.rejoinCalls >= 1 &&
            rejoinAt >= 0 &&
            api.callOrder.lastIndexOf('wsTicket') > rejoinAt) {
          break;
        }
      }

      expect(api.rejoinCalls, 1);
      final int rejoinAt = api.callOrder.indexOf('rejoin');
      expect(rejoinAt, greaterThanOrEqualTo(0));
      expect(api.callOrder.lastIndexOf('wsTicket'), greaterThan(rejoinAt));
      expect(find.text('Rejoin match'), findsNothing);
    },
  );

  testWidgets(
    'isolate-alive first rejoin 409 keeps token then tickets and hides Rejoin match',
    (WidgetTester tester) async {
      final SessionStore session = SessionStore.memory();
      await session.persist(
        playerId: _playerId,
        refreshToken: 'refresh-token',
      );
      final _FirstRejoinConflictApi api = _FirstRejoinConflictApi(session);
      final StreamController<Map<String, dynamic>> incoming =
          StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(() async {
        if (!incoming.isClosed) {
          await incoming.close();
        }
      });
      int connects = 0;
      MatchSocket.debugConnect = (_) async {
        connects++;
        if (connects == 1) {
          return MatchSocket.stub(incoming: incoming);
        }
        return MatchSocket.stub();
      };
      addTearDown(() {
        MatchSocket.debugConnect = null;
      });

      await _pumpMatchPage(
        tester,
        session: session,
        api: api,
        matchId: _matchId,
      );
      await _pumpUntilGameWidget(tester);
      expect(_gameWidget, findsWidgets);

      await session.persistReconnect(
        token: _token,
        matchId: _matchId,
        localSeat: _localSeat,
      );
      if (!incoming.isClosed) {
        await incoming.close();
      }
      for (int i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final int rejoinAt = api.callOrder.indexOf('rejoin');
        if (await session.reconnectToken() != null &&
            rejoinAt >= 0 &&
            api.callOrder.lastIndexOf('wsTicket') > rejoinAt) {
          break;
        }
      }

      expect(await session.reconnectToken(), isNotNull);
      final int rejoinAt = api.callOrder.indexOf('rejoin');
      expect(rejoinAt, greaterThanOrEqualTo(0));
      expect(api.callOrder.lastIndexOf('wsTicket'), greaterThan(rejoinAt));
      expect(find.text('Rejoin match'), findsNothing);
    },
  );

  testWidgets(
    'process-death overlay seeds reconnecting padded 12 from reconnectSecondsLeft not a fresh 30',
    (WidgetTester tester) async {
      final SessionStore session = SessionStore.memory();
      await session.persist(
        playerId: _playerId,
        refreshToken: 'refresh-token',
      );
      await session.persistReconnect(
        token: _token,
        matchId: _matchId,
        localSeat: _localSeat,
      );
      final _ReconnectFlowApi api = _ReconnectFlowApi(session);
      api.reconnectSecondsLeft = 12;
      MatchSocket.debugConnect = (_) async => MatchSocket.stub();
      addTearDown(() {
        MatchSocket.debugConnect = null;
      });

      await _pumpMatchPage(
        tester,
        session: session,
        api: api,
        matchId: _matchId,
      );
      await _pumpUntilRejoin(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Reconnecting… 12'), findsOneWidget);
      expect(find.text('Reconnecting… 30'), findsNothing);
      expect(find.text('Rejoin match'), findsOneWidget);
    },
  );
}
