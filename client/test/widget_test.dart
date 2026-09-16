import 'package:client/catalog/catalog_models.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LocalCatalogApi extends NomadApi {
  _LocalCatalogApi(SessionStore session) : super(sessionStore: session);

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;
}

void main() {
  testWidgets('NomadApp catalog is home', (WidgetTester tester) async {
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

    expect(find.text('Nomad Games'), findsOneWidget);
    expect(find.text('Play Alchiki'), findsOneWidget);
  });
}
