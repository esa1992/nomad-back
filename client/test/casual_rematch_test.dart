import 'package:client/catalog/catalog_models.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wave 0 RED stubs for MODE-05 casual rematch-wait UX (greens in 05-05).
/// EN copy from 05-UI-SPEC (`rematchWaitingTitle`).

class _StubApi extends NomadApi {
  _StubApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;

  @override
  Future<WalletBalance> fetchWallet() async =>
      const WalletBalance(coins: 0, gems: 0);
}

Future<void> _pumpRematchWait(WidgetTester tester) async {
  final SessionStore session = SessionStore.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(_StubApi(session)),
      ],
      child: const NomadApp(initialLocation: '/match/rematch-wait'),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('playAgainOpensRematchWait', (WidgetTester tester) async {
    await _pumpRematchWait(tester);

    // Casual Play again lands on rematch-wait (D-70…D-73), not private Again?.
    expect(find.text('Waiting for rematch'), findsOneWidget);
  });

  testWidgets('cancelRematchReturnsCatalog', (WidgetTester tester) async {
    await _pumpRematchWait(tester);

    expect(find.text('Cancel rematch'), findsOneWidget);
    await tester.tap(find.text('Cancel rematch'));
    await tester.pumpAndSettle();

    expect(find.text('Play Alchiki'), findsOneWidget);
  });
}
