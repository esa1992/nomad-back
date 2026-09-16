import 'package:client/catalog/catalog_models.dart';
import 'package:client/howto/alchiki_howto_page.dart';
import 'package:client/howto/howto_seen_store.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LocalCatalogApi extends NomadApi {
  _LocalCatalogApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;
}

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
}

Future<void> _swipeToLastCard(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('first-run how-to when howto.alchiki.seen is false', () {
    testWidgets('Play Alchiki opens pager with The circle and Skip on card 1', (
      WidgetTester tester,
    ) async {
      final _MemoryHowToSeenStore store = _MemoryHowToSeenStore();
      await _pumpApp(tester, store: store);

      await tester.tap(find.text('Play Alchiki'));
      await tester.pumpAndSettle();

      expect(find.text('The circle'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byType(AlchikiHowToPage), findsOneWidget);
    });

    testWidgets('Skip writes howto.alchiki.seen and routes to /match', (
      WidgetTester tester,
    ) async {
      final _MemoryHowToSeenStore store = _MemoryHowToSeenStore();
      await _pumpApp(tester, store: store);

      await tester.tap(find.text('Play Alchiki'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(store.seen, isTrue);
      expect(find.text('First to 5 · EASY'), findsOneWidget);
      expect(find.text('The circle'), findsNothing);
    });
  });

  group('five how-to cards', () {
    testWidgets('page 1 of 5; swipe to card 5 shows First to 5 and Play Alchiki', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        store: _MemoryHowToSeenStore(),
        location: '/howto/alchiki?difficulty=EASY',
      );

      expect(find.text('The circle'), findsOneWidget);
      expect(find.text('Aim'), findsNothing);
      expect(find.text('1 / 5'), findsOneWidget);

      await _swipeToLastCard(tester);

      expect(find.text('First to 5'), findsWidgets);
      expect(find.text('Play Alchiki'), findsOneWidget);
      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('card copy does not include federation or alshy words', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        store: _MemoryHowToSeenStore(),
        location: '/howto/alchiki?difficulty=EASY',
      );

      final List<String> headings = <String>[
        'The circle',
        'Aim',
        'Hold to throw',
        'Out is one point',
        'First to 5',
      ];

      for (var i = 0; i < headings.length; i++) {
        final String joined = tester
            .widgetList<Text>(find.byType(Text))
            .map((Text text) => text.data ?? '')
            .join(' ')
            .toLowerCase();
        expect(joined, isNot(contains('federation')));
        expect(joined, isNot(contains('alshy')));
        expect(find.text(headings[i]), findsWidgets);
        if (i < headings.length - 1) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
    });
  });

  group('once per device', () {
    testWidgets('after markSeen, Play Alchiki skips the pager', (
      WidgetTester tester,
    ) async {
      final _MemoryHowToSeenStore store = _MemoryHowToSeenStore();
      await store.markSeen();
      await _pumpApp(tester, store: store);

      await tester.tap(find.text('Play Alchiki'));
      await tester.pumpAndSettle();

      expect(find.text('The circle'), findsNothing);
      expect(find.text('First to 5 · EASY'), findsOneWidget);
    });
  });
}
