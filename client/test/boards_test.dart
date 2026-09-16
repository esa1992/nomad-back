import 'package:client/boards/boards_api.dart';
import 'package:client/catalog/catalog_models.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// LEAD boards UI (07-UI-SPEC boardsTitle / boardsSeason / boardsAllTime + game filters).

class _StubApi extends NomadApi {
  _StubApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;

  @override
  Future<WalletBalance> fetchWallet() async =>
      const WalletBalance(coins: 0, gems: 0);

  @override
  Future<BoardsSnapshot> fetchBoards({
    required String game,
    required String scope,
  }) async {
    return BoardsSnapshot(
      game: game,
      scope: scope,
      entries: const <BoardEntry>[],
    );
  }
}

Future<void> _pumpBoards(WidgetTester tester) async {
  final SessionStore session = SessionStore.memory();
  await session.persist(
    playerId: 'local-player',
    refreshToken: 'refresh',
  );
  await session.persistGuest(false);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(_StubApi(session)),
        boardsApiProvider.overrideWithValue(BoardsApi(_StubApi(session))),
      ],
      child: const NomadApp(initialLocation: '/boards'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('boardsTitle', (WidgetTester tester) async {
    await _pumpBoards(tester);
    expect(find.text('Boards'), findsWidgets);
  });

  testWidgets('seasonAndAllTimeSegments', (WidgetTester tester) async {
    await _pumpBoards(tester);
    expect(find.text('Season'), findsOneWidget);
    expect(find.text('All-time'), findsOneWidget);
  });

  testWidgets('gameFilters', (WidgetTester tester) async {
    await _pumpBoards(tester);
    expect(find.text('Alchiki'), findsOneWidget);
    expect(find.text('Stick Pull'), findsOneWidget);
  });
}
