import 'package:client/catalog/catalog_models.dart';
import 'package:client/howto/howto_seen_store.dart';
import 'package:client/howto/stick_pull_howto_page.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// STICK-05 Stick Pull how-to (D-84, D-85).
/// EN copy from 06-UI-SPEC (`howtoStickSitTitle` … `howtoStickWinTitle`).
/// Seen key: `howto.stickpull.seen`.

class _LocalCatalogApi extends NomadApi {
  _LocalCatalogApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;

  @override
  Future<WalletBalance> fetchWallet() async =>
      const WalletBalance(coins: 0, gems: 0);
}

class _MemoryStickHowToSeenStore extends HowToSeenStore {
  _MemoryStickHowToSeenStore({this.stickSeen = false});

  bool stickSeen;

  @override
  Future<bool> isStickPullSeen() async => stickSeen;

  @override
  Future<void> markStickPullSeen() async {
    stickSeen = true;
  }

  @override
  Future<bool> isSeen() async => false;

  @override
  Future<void> markSeen() async {}
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required HowToSeenStore store,
  String location = '/',
}) async {
  final SessionStore session = SessionStore.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(_LocalCatalogApi(session)),
        howToSeenStoreProvider.overrideWithValue(store),
      ],
      child: NomadApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
  expect(HowToSeenStore.stickPullSeenKey, 'howto.stickpull.seen');
}

void main() {
  testWidgets('Play Stick Pull opens pager with Sit opposite and Skip on card 1', (
    WidgetTester tester,
  ) async {
    final _MemoryStickHowToSeenStore store = _MemoryStickHowToSeenStore();
    await _pumpApp(tester, store: store);

    final Finder playCta = find.text('Play Stick Pull');
    await tester.ensureVisible(playCta);
    await tester.tap(playCta);
    await tester.pumpAndSettle();

    expect(find.text('Sit opposite'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.byType(StickPullHowToPage), findsOneWidget);
  });

  testWidgets('Skip writes howto.stickpull.seen and continues to match', (
    WidgetTester tester,
  ) async {
    final _MemoryStickHowToSeenStore store = _MemoryStickHowToSeenStore();
    await _pumpApp(
      tester,
      store: store,
      location: '/howto/stick-pull?difficulty=EASY',
    );

    expect(find.text('Sit opposite'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(store.stickSeen, isTrue);
    expect(HowToSeenStore.stickPullSeenKey, 'howto.stickpull.seen');
    expect(find.text('Sit opposite'), findsNothing);
  });

  testWidgets('five Stick Pull how-to cards end with Play Stick Pull', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      store: _MemoryStickHowToSeenStore(),
      location: '/howto/stick-pull?difficulty=EASY',
    );

    final List<String> headings = <String>[
      'Sit opposite',
      'Wait for GO',
      'Tap in rhythm',
      'Watch stamina',
      'Pull it over',
    ];

    for (var i = 0; i < headings.length; i++) {
      expect(find.text(headings[i]), findsWidgets);
      expect(find.text('${i + 1} / 5'), findsOneWidget);
      if (i < headings.length - 1) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('Play Stick Pull'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });
}
