import 'package:client/catalog/catalog_models.dart';
import 'package:client/games/alchiki/pause_overlay.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ranked searching chrome (07-04) + Ranked result Find Ranked match CTA (07-08 / D-99).
class _StubApi extends NomadApi {
  _StubApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;

  @override
  Future<WalletBalance> fetchWallet() async =>
      const WalletBalance(coins: 0, gems: 0);

  @override
  Future<CasualQueueStatus> pollCasual() async =>
      const CasualQueueStatus(status: 'SEARCHING');

  @override
  Future<CasualQueueStatus> dequeueCasual() async =>
      const CasualQueueStatus(status: 'IDLE');

  @override
  Future<CasualQueueStatus> pollRanked() async =>
      const CasualQueueStatus(status: 'SEARCHING');

  @override
  Future<CasualQueueStatus> dequeueRanked() async =>
      const CasualQueueStatus(status: 'IDLE');
}

Future<void> _pumpRankedSearch(WidgetTester tester) async {
  final SessionStore session = SessionStore.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(_StubApi(session)),
      ],
      child: const NomadApp(
        initialLocation: '/matchmaking?mode=ranked&game=ALCHIKI',
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('rankedSearchingBody', (WidgetTester tester) async {
    await _pumpRankedSearch(tester);
    expect(find.text('Looking for a Ranked opponent'), findsOneWidget);
    expect(find.text('Cancel search'), findsOneWidget);
  });

  testWidgets('rankedSearchHasNoBotOrInviteFallback', (WidgetTester tester) async {
    // D-98: Ranked search must never show Play vs bot / Invite friend
    await _pumpRankedSearch(tester);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();

    expect(find.text('Looking for a Ranked opponent'), findsOneWidget);
    expect(find.text('Play vs bot'), findsNothing);
    expect(find.text('Invite friend'), findsNothing);
  });

  testWidgets('findRankedMatchResultCta', (WidgetTester tester) async {
    // D-99: Ranked result shows Find Ranked match (accent primary); no Again?/Play again.
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ResultOverlay(
                l10n: l10n,
                status: 'HOST_WIN',
                localSeat: 'host',
                youScore: 5,
                botScore: 2,
                opponentLabel: 'Rival',
                isRanked: true,
                onFindRankedMatch: () {},
                onBackToCatalog: () {},
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find Ranked match'), findsOneWidget);
    expect(find.text('Back to catalog'), findsOneWidget);
    expect(find.text('Play again'), findsNothing);
    expect(find.text('Again?'), findsNothing);
  });
}
