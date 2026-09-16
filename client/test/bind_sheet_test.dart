import 'package:client/catalog/catalog_models.dart';
import 'package:client/catalog/soft_lock_sheet.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/bind_prompt_store.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/profile/bind_sheet.dart';
import 'package:client/profile/sign_in_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// AUTH-02/03/04 bind + sign-in/out + D-96 soft-lock (07-09 / 07-10).

class _StubApi extends NomadApi {
  _StubApi(SessionStore session) : super(sessionStore: session);

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
}

class _MemoryBindPromptStore extends BindPromptStore {
  _MemoryBindPromptStore({this.seen = false});

  bool seen;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async {
    seen = true;
  }
}

Future<void> _pumpBindSheet(
  WidgetTester tester, {
  bool usernameTaken = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return BindSheet(
              usernameTaken: usernameTaken,
              onBind: (_, __) async {},
              onNotNow: () {},
              onSignInInstead: () {},
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _pumpSignInSheet(
  WidgetTester tester, {
  bool forceReplaceGuest = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return SignInSheet(
              forceReplaceGuest: forceReplaceGuest,
              onLogin: ({
                required String username,
                required String password,
                required String adopt,
                required bool persist,
              }) async {
                return GuestSession(
                  playerId: 'bound-1',
                  accessToken: 'a',
                  refreshToken: 'r',
                  guest: false,
                  adoptHint: forceReplaceGuest ? 'DROP_REQUIRED' : null,
                );
              },
              onDismiss: () {},
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _pumpSoftLock(
  WidgetTester tester, {
  SoftLockKind kind = SoftLockKind.ranked,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SoftLockSheet(
          kind: kind,
          onBindNow: () {},
          onNotNow: () {},
        ),
      ),
    ),
  );
}

Future<void> _pumpProfile(WidgetTester tester, {bool guest = true}) async {
  final SessionStore session = SessionStore.memory();
  await session.persist(playerId: 'p1', refreshToken: 'r1');
  await session.persistGuest(guest);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(_StubApi(session)),
      ],
      child: const NomadApp(initialLocation: '/profile'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bind sheet shows bindSheetTitle bindAccount notNow from ARB', (
    WidgetTester tester,
  ) async {
    await _pumpBindSheet(tester);
    expect(find.text('Keep your progress'), findsOneWidget);
    expect(find.text('Bind account'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('username taken UI exposes Sign in instead path', (
    WidgetTester tester,
  ) async {
    await _pumpBindSheet(tester, usernameTaken: true);
    expect(find.text('Username taken'), findsOneWidget);
    expect(find.text('Sign in instead'), findsOneWidget);
  });

  test('bind_prompt_store defaults unseen then marks seen', () async {
    final _MemoryBindPromptStore store = _MemoryBindPromptStore();
    expect(await store.isSeen(), isFalse);
    await store.markSeen();
    expect(await store.isSeen(), isTrue);
    expect(BindPromptStore.seenKey, 'bind.prompt.seen');
  });

  testWidgets('Profile always exposes Bind account for guests', (
    WidgetTester tester,
  ) async {
    await _pumpProfile(tester);
    expect(find.text('Bind account'), findsOneWidget);
    expect(
      find.text('Guest — bind to unlock Ranked and Boards'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Profile bound shows Log out', (WidgetTester tester) async {
    await _pumpProfile(tester, guest: false);
    expect(find.text('Bound'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Bind account'), findsNothing);
  });

  testWidgets('sign-in sheet shows signInTitle and Sign in CTA', (
    WidgetTester tester,
  ) async {
    await _pumpSignInSheet(tester);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Use your bound username and password.'), findsOneWidget);
  });

  testWidgets('replaceGuest confirm uses replaceGuestTitle', (
    WidgetTester tester,
  ) async {
    await _pumpSignInSheet(tester, forceReplaceGuest: true);
    expect(find.text('Replace guest progress?'), findsOneWidget);
    expect(find.text('Sign in anyway'), findsOneWidget);
  });

  testWidgets('soft-lock Ranked uses rankedLockTitle and bindNow', (
    WidgetTester tester,
  ) async {
    await _pumpSoftLock(tester, kind: SoftLockKind.ranked);
    expect(find.text('Ranked needs an account'), findsOneWidget);
    expect(find.text('Bind now'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('soft-lock Boards uses boardsLockTitle', (
    WidgetTester tester,
  ) async {
    await _pumpSoftLock(tester, kind: SoftLockKind.boards);
    expect(find.text('Boards need an account'), findsOneWidget);
    expect(find.text('Bind now'), findsOneWidget);
  });

  test('D-92 funnel gate offers once for guest bot win when unseen', () {
    expect(
      shouldOfferBindAfterBotWin(
        isBotMode: true,
        isPlayerWin: true,
        isGuest: true,
        promptSeen: false,
      ),
      isTrue,
    );
    expect(
      shouldOfferBindAfterBotWin(
        isBotMode: true,
        isPlayerWin: true,
        isGuest: true,
        promptSeen: true,
      ),
      isFalse,
    );
    expect(
      shouldOfferBindAfterBotWin(
        isBotMode: false,
        isPlayerWin: true,
        isGuest: true,
        promptSeen: false,
      ),
      isFalse,
    );
    expect(
      shouldOfferBindAfterBotWin(
        isBotMode: true,
        isPlayerWin: false,
        isGuest: true,
        promptSeen: false,
      ),
      isFalse,
    );
    expect(
      shouldOfferBindAfterBotWin(
        isBotMode: true,
        isPlayerWin: true,
        isGuest: false,
        promptSeen: false,
      ),
      isFalse,
    );
  });
}
