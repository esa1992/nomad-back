import 'package:client/catalog/catalog_models.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wave 0 RED stubs for MODE-03 Searching / 8s fallback (greens in 05-03 / 05-04).
/// EN copy from 05-UI-SPEC (`cancelSearch`, `playVsBot`, `inviteFriend`).

class _StubApi extends NomadApi {
  _StubApi(SessionStore session) : super(sessionStore: session);

  bool dequeued = false;
  bool createdRoom = false;
  bool startedBot = false;
  String? botDifficulty;

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;

  @override
  Future<WalletBalance> fetchWallet() async =>
      const WalletBalance(coins: 0, gems: 0);

  @override
  Future<CasualQueueStatus> pollCasual() async =>
      const CasualQueueStatus(status: 'SEARCHING');

  @override
  Future<CasualQueueStatus> dequeueCasual() async {
    dequeued = true;
    return const CasualQueueStatus(status: 'IDLE');
  }

  @override
  Future<RoomCreated> createRoom({String game = 'ALCHIKI'}) async {
    createdRoom = true;
    return RoomCreated(
      roomId: 'room-1',
      code: 'ABCD',
      hostLabel: 'Guest-AAAA',
      idleExpiresAt: DateTime.utc(2099),
    );
  }

  @override
  Future<RoomLobby> getRoom(String roomId) async {
    return RoomLobby(
      roomId: roomId,
      code: 'ABCD',
      hostLabel: 'Guest-AAAA',
      joinerLabel: null,
      hostReady: false,
      joinerReady: false,
      bothReady: false,
      matchId: null,
      status: 'WAITING',
      idleExpiresAt: DateTime.utc(2099),
    );
  }

  @override
  Future<MatchStart> startMatch({
    String difficulty = 'EASY',
    String game = 'ALCHIKI',
  }) async {
    startedBot = true;
    botDifficulty = difficulty;
    return MatchStart(
      matchId: 'bot-1',
      difficulty: difficulty,
      boneIds: const <String>['b1'],
      turn: 'PLAYER',
      status: 'IN_PLAY',
    );
  }
}

Future<_StubApi> _pumpMatchmaking(WidgetTester tester) async {
  final SessionStore session = SessionStore.memory();
  final _StubApi api = _StubApi(session);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(api),
      ],
      child: const NomadApp(initialLocation: '/matchmaking'),
    ),
  );
  await tester.pump();
  return api;
}

void main() {
  testWidgets('cancelSearchReturnsCatalog', (WidgetTester tester) async {
    final _StubApi api = await _pumpMatchmaking(tester);

    expect(find.text('Cancel search'), findsOneWidget);
    await tester.tap(find.text('Cancel search'));
    await tester.pumpAndSettle();

    // Back on catalog after dequeue (D-62).
    expect(find.text('Play Alchiki'), findsOneWidget);
    expect(api.dequeued, isTrue);
  });

  testWidgets('fallbackAfterEightSeconds', (WidgetTester tester) async {
    await _pumpMatchmaking(tester);

    await tester.pump(const Duration(seconds: 8));
    await tester.pump();

    // Equal CTAs after 8s (D-63, D-65). Searching chrome replaced.
    expect(find.text('Searching…'), findsNothing);
    expect(find.text('Play vs bot'), findsOneWidget);
    expect(find.text('Invite friend'), findsOneWidget);
  });

  testWidgets('backToCatalogDequeues', (WidgetTester tester) async {
    final _StubApi api = await _pumpMatchmaking(tester);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();

    // Fallback chrome exposes Back that dequeues (D-65).
    expect(find.text('Back to catalog'), findsOneWidget);
    await tester.tap(find.text('Back to catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Play Alchiki'), findsOneWidget);
    expect(api.dequeued, isTrue);
  });

  testWidgets('inviteFriendDequeuesThenLobby', (WidgetTester tester) async {
    final _StubApi api = await _pumpMatchmaking(tester);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();

    await tester.tap(find.text('Invite friend'));
    await tester.pumpAndSettle();

    expect(api.dequeued, isTrue);
    expect(api.createdRoom, isTrue);
    expect(find.text('ABCD'), findsOneWidget);
  });
}
