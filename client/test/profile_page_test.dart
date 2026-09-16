import 'package:client/catalog/catalog_models.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PROF-02 Stick Pull empty + PROF-03 avatar save (D-76, D-77, Q2 LOCKED).

class _StubApi extends NomadApi {
  _StubApi(SessionStore session) : super(sessionStore: session);

  bool putAvatarCalled = false;
  String? lastAvatarPreset;

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;

  @override
  Future<WalletBalance> fetchWallet() async =>
      const WalletBalance(coins: 0, gems: 0);

  @override
  Future<PlayerProfile> fetchProfile() async => const PlayerProfile(
        displayName: 'Guest',
        subtitle: 'Guest-a1b2',
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
        cosmetics: <String, String>{
          'saka_color': 'saka_color_default',
        },
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
  Future<PlayerProfile> putAvatar(String avatarPreset) async {
    putAvatarCalled = true;
    lastAvatarPreset = avatarPreset;
    return PlayerProfile(
      displayName: 'Guest',
      subtitle: 'Guest-a1b2',
      avatarPreset: avatarPreset,
      level: 1,
      xp: 0,
      xpToNext: 100,
      matches: 0,
      wins: 0,
      losses: 0,
      winRate: 0,
      rating: 1000,
      bestRating: 1000,
      cosmetics: const <String, String>{
        'saka_color': 'saka_color_default',
      },
      games: const <String, GameStats>{
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
  }
}

Future<void> _pumpProfile(WidgetTester tester, {_StubApi? api}) async {
  final SessionStore session = SessionStore.memory();
  final _StubApi stub = api ?? _StubApi(session);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(stub),
      ],
      child: const NomadApp(initialLocation: '/profile'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('stickPullSectionShowsNoMatchesYet', (WidgetTester tester) async {
    await _pumpProfile(tester);

    expect(find.text('Guest'), findsWidgets);
    expect(find.text('Guest-a1b2'), findsOneWidget);
    expect(find.text('Stick Pull'), findsOneWidget);
    expect(find.text('No matches yet'), findsOneWidget);
  });

  testWidgets('saveAvatarCallsPut', (WidgetTester tester) async {
    final SessionStore session = SessionStore.memory();
    final _StubApi api = _StubApi(session);
    await _pumpProfile(tester, api: api);

    expect(find.text('Save avatar'), findsOneWidget);

    // Select allow-listed preset different from current avatar_01.
    final Finder preset = find.byKey(const Key('avatar_preset_avatar_03'));
    await tester.ensureVisible(preset);
    await tester.pumpAndSettle();
    await tester.tap(preset);
    await tester.pump();

    await tester.ensureVisible(find.text('Save avatar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save avatar'));
    await tester.pumpAndSettle();

    expect(
      api.putAvatarCalled,
      isTrue,
      reason: 'Save avatar must PUT /v1/profile/avatar (PROF-03 / 05-07)',
    );
    expect(api.lastAvatarPreset, 'avatar_03');
  });
}
