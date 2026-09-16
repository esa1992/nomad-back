import 'package:client/catalog/catalog_models.dart';
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

  @override
  Future<WalletBalance> fetchWallet() async =>
      const WalletBalance(coins: 0, gems: 0);

  @override
  Future<PlayerProfile> fetchProfile() async => const PlayerProfile(
        displayName: 'Guest',
        subtitle: 'Guest-abcd',
        avatarPreset: 'avatar_01',
        level: 1,
        xp: 0,
        xpToNext: 100,
        matches: 0,
        wins: 0,
        losses: 0,
        winRate: 0,
        rating: 1000,
        bestRating: 1000,
        cosmetics: <String, String>{},
        games: <String, GameStats>{
          'alchiki': GameStats(
            matches: 0,
            wins: 0,
            losses: 0,
            draws: 0,
            noMatchesYet: true,
          ),
          'stickPull': GameStats(
            matches: 0,
            wins: 0,
            losses: 0,
            draws: 0,
            noMatchesYet: true,
          ),
        },
      );

  @override
  Future<CasualQueueStatus> enqueueCasual({String game = 'ALCHIKI'}) async =>
      const CasualQueueStatus(status: 'SEARCHING');

  @override
  Future<CasualQueueStatus> pollCasual() async =>
      const CasualQueueStatus(status: 'SEARCHING');

  @override
  Future<CasualQueueStatus> dequeueCasual() async =>
      const CasualQueueStatus(status: 'IDLE');
}

Future<void> _pumpCatalog(WidgetTester tester) async {
  final SessionStore session = SessionStore.memory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(_LocalCatalogApi(session)),
      ],
      child: const NomadApp(initialLocation: '/'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('catalog home shows Alchiki playable and Coming Soon tiles', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    expect(find.text('Play Alchiki'), findsOneWidget);
    expect(find.text('Alchiki'), findsOneWidget);
    expect(find.text('Easy'), findsWidgets);
    expect(find.text('Stick Pull'), findsOneWidget);
    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('More games'), findsOneWidget);
    expect(find.text('Create room'), findsOneWidget);
    expect(find.text('Join by code'), findsOneWidget);
  });

  testWidgets('catalog shows Create room and Join by code CTAs', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    expect(find.text('Create room'), findsOneWidget);
    expect(find.text('Join by code'), findsOneWidget);
    expect(find.text('Play Alchiki'), findsOneWidget);
  });

  testWidgets('tapping Stick Pull does not leave the catalog', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    await tester.tap(find.text('Stick Pull'));
    await tester.pumpAndSettle();

    expect(find.text('Play Alchiki'), findsOneWidget);
  });

  testWidgets('catalog has no account-name field or sign-in labels', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Register'), findsNothing);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Guest'), findsNothing);
  });

  testWidgets('Easy is the selected difficulty on first visit', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    expect(find.text('Easy'), findsNWidgets(2));
    final selectedEasy = find.ancestor(
      of: find.text('Easy'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is FilterChip && widget.selected ||
            widget is ChoiceChip && widget.selected,
      ),
    );
    expect(selectedEasy, findsNWidgets(2));
  });

  // Wave 0 RED — Quick Match primary + avatar chip (D-66, D-74); greens in 05-03 / 05-07.
  testWidgets('catalog shows Quick Match primary CTA', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    expect(find.text('Quick Match'), findsNWidgets(2));
  });

  testWidgets('catalog shows openProfileA11y avatar chip', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    expect(find.bySemanticsLabel('Open profile'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'COINS')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Open profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('wallet chip does not open profile', (WidgetTester tester) async {
    await _pumpCatalog(tester);

    await tester.tap(find.bySemanticsLabel(RegExp(r'COINS')));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsNothing);
    expect(find.text('Play Alchiki'), findsOneWidget);
  });

  // Wave 0 RED — Stick Pull playable CTAs (CAT-02, D-78, D-79); greens in 06-02.
  testWidgets('Stick Pull tile shows Quick Match Play Stick Pull and Create Stick Pull room', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    expect(find.text('Stick Pull'), findsOneWidget);
    expect(find.text('Quick Match'), findsWidgets);
    expect(find.text('Play Stick Pull'), findsOneWidget);
    expect(find.text('Create Stick Pull room'), findsOneWidget);
  });

  testWidgets('Stick Pull tile does not show Coming Soon', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester);

    // Coming Soon remains only on More games — Stick Pull is PLAYABLE (CAT-02).
    expect(find.text('Stick Pull'), findsOneWidget);
    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('More games'), findsOneWidget);
    expect(find.text('Play Stick Pull'), findsOneWidget);
  });
}
