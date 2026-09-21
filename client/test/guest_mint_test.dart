import 'package:client/catalog/catalog_models.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/platform/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingMintApi extends NomadApi {
  _FailingMintApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<GuestSession> mintGuest() {
    return Future<GuestSession>.error(NomadApiException('mint failed'));
  }
}

class _SucceedingMintApi extends NomadApi {
  _SucceedingMintApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<GuestSession> mintGuest() async {
    await sessionStore.persist(
      playerId: '11111111-1111-1111-1111-111111111111',
      refreshToken: 'refresh-token',
    );
    accessToken = 'access-token';
    return const GuestSession(
      playerId: '11111111-1111-1111-1111-111111111111',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      guest: true,
    );
  }

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;
}

Future<void> _pumpSplash(
  WidgetTester tester, {
  required NomadApi api,
  required SessionStore session,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(api),
      ],
      child: const NomadApp(initialLocation: '/splash'),
    ),
  );
}

void main() {
  testWidgets('splash mint failure shows errorGuestMint and retry', (
    WidgetTester tester,
  ) async {
    final SessionStore session = SessionStore.memory();
    await _pumpSplash(
      tester,
      api: _FailingMintApi(session),
      session: session,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final BuildContext context = tester.element(find.byType(SplashPage));
    final AppLocalizations l10n = AppLocalizations.of(context);
    expect(find.text(l10n.errorGuestMint), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('splash mint success has no account-name field', (
    WidgetTester tester,
  ) async {
    final SessionStore session = SessionStore.memory();
    await _pumpSplash(
      tester,
      api: _SucceedingMintApi(session),
      session: session,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Sign in'), findsNothing);
  });
}
