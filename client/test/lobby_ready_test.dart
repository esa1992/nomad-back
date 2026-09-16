import 'package:client/howto/alchiki_howto_page.dart';
import 'package:client/howto/howto_seen_store.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MemoryHowToSeenStore extends HowToSeenStore {
  _MemoryHowToSeenStore({this.seen = false});

  bool seen;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async {
    seen = true;
  }
}

class _LobbyApi extends NomadApi {
  _LobbyApi(
    SessionStore session, {
    this.joinerLabel,
    this.readyLobby,
  }) : super(sessionStore: session);

  final String? joinerLabel;
  final RoomLobby? readyLobby;

  @override
  Future<RoomLobby> getRoom(String id) async {
    return RoomLobby(
      roomId: id,
      code: 'K7M4Q',
      hostLabel: 'Guest-A1B2',
      joinerLabel: joinerLabel,
      status: 'LOBBY',
      idleExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<RoomLobby> readyRoom(String id) async {
    return readyLobby ?? await getRoom(id);
  }

  @override
  Future<RoomLobby> leaveRoom(String id) async {
    return await getRoom(id);
  }
}

Future<void> _pumpLobby(
  WidgetTester tester, {
  required NomadApi api,
  required SessionStore session,
  HowToSeenStore? howTo,
  String location = '/lobby?roomId=room-1&code=K7M4Q&hostLabel=Guest-A1B2',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(api),
        howToSeenStoreProvider.overrideWithValue(
          howTo ?? _MemoryHowToSeenStore(),
        ),
      ],
      child: NomadApp(initialLocation: location),
    ),
  );
  await tester.pump();
  await tester.pump();
}

InkWell _readyInkWell(WidgetTester tester) {
  return tester.widget<InkWell>(
    find
        .ancestor(
          of: find.text('Ready').first,
          matching: find.byType(InkWell),
        )
        .first,
  );
}

void main() {
  testWidgets('Ready is disabled when no joiner sits', (
    WidgetTester tester,
  ) async {
    final SessionStore session = SessionStore.memory();
    await _pumpLobby(
      tester,
      session: session,
      api: _LobbyApi(session),
    );

    expect(find.text('Ready'), findsWidgets);
    expect(_readyInkWell(tester).onTap, isNull);
  });

  testWidgets('host Leave lobby opens Leave this room? confirm', (
    WidgetTester tester,
  ) async {
    final SessionStore session = SessionStore.memory();
    await _pumpLobby(
      tester,
      session: session,
      api: _LobbyApi(session, joinerLabel: 'Guest-C9D0'),
    );

    await tester.tap(find.text('Leave lobby'));
    await tester.pump();

    expect(find.text('Leave this room?'), findsOneWidget);
  });

  testWidgets('howto.alchiki.seen skips pager and goes to mode=private', (
    WidgetTester tester,
  ) async {
    final SessionStore session = SessionStore.memory();
    final _MemoryHowToSeenStore store = _MemoryHowToSeenStore(seen: true);
    await _pumpLobby(
      tester,
      session: session,
      howTo: store,
      api: _LobbyApi(
        session,
        joinerLabel: 'Guest-C9D0',
        readyLobby: RoomLobby(
          roomId: 'room-1',
          code: 'K7M4Q',
          hostLabel: 'Guest-A1B2',
          joinerLabel: 'Guest-C9D0',
          hostReady: true,
          joinerReady: true,
          bothReady: true,
          status: 'STARTED',
          idleExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
          matchId: 'match-1',
        ),
      ),
    );

    await tester.tap(find.text('Ready').first);
    await tester.pump();
    await tester.pump();

    expect(find.byType(AlchikiHowToPage), findsNothing);
    final String location = GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).routeInformationProvider.value.uri.toString();
    expect(location, contains('mode=private'));
  });
}
