import 'package:client/catalog/catalog_models.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/app.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/shop/shop_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _WalletCatalogApi extends NomadApi {
  _WalletCatalogApi(
    SessionStore session, {
    this.wallet = const WalletBalance(coins: 120, gems: 3),
    this.failWallet = false,
    this.shopCatalog = const ShopCatalog(skus: <ShopSku>[
      ShopSku(
        id: 'saka_color_default',
        slot: 'saka_color',
        nameKey: 'skuSakaColorDefault',
        priceCoins: 0,
        priceGems: 0,
        owned: true,
        equipped: true,
        free: true,
      ),
      ShopSku(
        id: 'saka_color_gold',
        slot: 'saka_color',
        nameKey: 'skuSakaColorGold',
        priceCoins: 120,
        priceGems: 0,
        owned: false,
        equipped: false,
        free: false,
      ),
    ]),
    this.failShop = false,
    this.emptyShop = false,
  }) : super(sessionStore: session);

  final WalletBalance wallet;
  final bool failWallet;
  final ShopCatalog shopCatalog;
  final bool failShop;
  final bool emptyShop;
  int fetchWalletCalls = 0;
  int fetchShopCatalogCalls = 0;

  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;

  @override
  Future<WalletBalance> fetchWallet() async {
    fetchWalletCalls += 1;
    if (failWallet) {
      throw NomadApiException('Wallet failed', statusCode: 500);
    }
    return wallet;
  }

  @override
  Future<ShopCatalog> fetchShopCatalog() async {
    fetchShopCatalogCalls += 1;
    if (failShop) {
      throw NomadApiException('Shop failed', statusCode: 500);
    }
    if (emptyShop) {
      return const ShopCatalog(skus: <ShopSku>[]);
    }
    return shopCatalog;
  }
}

Future<_WalletCatalogApi> _pumpCatalog(
  WidgetTester tester, {
  bool failWallet = false,
  bool failShop = false,
  bool emptyShop = false,
}) async {
  final SessionStore session = SessionStore.memory();
  final _WalletCatalogApi api = _WalletCatalogApi(
    session,
    failWallet: failWallet,
    failShop: failShop,
    emptyShop: emptyShop,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        nomadApiProvider.overrideWithValue(api),
      ],
      child: const NomadApp(initialLocation: '/'),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('catalog shows wallet chip COINS/GEMS after fake fetchWallet', (
    WidgetTester tester,
  ) async {
    final _WalletCatalogApi api = await _pumpCatalog(tester);

    expect(api.fetchWalletCalls, greaterThan(0));
    // Chip format: COINS {n} · GEMS {m} (04-UI-SPEC / plan interfaces).
    expect(find.text('COINS 120 · GEMS 3'), findsOneWidget);
  });

  testWidgets('catalog shows Shop entry label', (WidgetTester tester) async {
    await _pumpCatalog(tester);

    expect(find.text('Shop'), findsOneWidget);
  });

  testWidgets('wallet failure shows errorWallet without blocking tiles', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester, failWallet: true);

    expect(find.text('Balances did not load. Tap Retry.'), findsOneWidget);
    expect(find.text('Play Alchiki'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
  });

  testWidgets('tap Shop opens /shop with Owned segment and category label', (
    WidgetTester tester,
  ) async {
    final _WalletCatalogApi api = await _pumpCatalog(tester);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();

    expect(api.fetchShopCatalogCalls, greaterThan(0));
    expect(find.text('Owned'), findsOneWidget);
    expect(find.text('Saka color'), findsOneWidget);
  });

  testWidgets('shop error shows Retry when fetchShopCatalog throws', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester, failShop: true);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();

    expect(find.text('Shop did not load. Tap Retry.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shop empty shows Retry when catalog has no SKUs', (
    WidgetTester tester,
  ) async {
    await _pumpCatalog(tester, emptyShop: true);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();

    expect(find.text('No items here'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('detail Equip calls equipSku then shows Equipped', (
    WidgetTester tester,
  ) async {
    final SessionStore session = SessionStore.memory();
    final _EquipApi api = _EquipApi(session);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(session),
          nomadApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ShopDetailPage(
            sku: const ShopSku(
              id: 'saka_color_gold',
              slot: 'saka_color',
              nameKey: 'skuSakaColorGold',
              priceCoins: 120,
              priceGems: 0,
              owned: true,
              equipped: false,
              free: false,
            ),
            coins: 80,
            gems: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Equip item'), findsOneWidget);
    await tester.tap(find.text('Equip item'));
    await tester.pumpAndSettle();

    expect(api.equipCalls, 1);
    expect(api.lastEquipSlot, 'saka_color');
    expect(api.lastEquipSkuId, 'saka_color_gold');
    expect(find.text('Equipped'), findsOneWidget);
    expect(find.text('Equip item'), findsNothing);
  });
}

class _EquipApi extends NomadApi {
  _EquipApi(SessionStore session) : super(sessionStore: session);

  int equipCalls = 0;
  String? lastEquipSlot;
  String? lastEquipSkuId;

  @override
  Future<void> equipSku({required String slot, required String skuId}) async {
    equipCalls += 1;
    lastEquipSlot = slot;
    lastEquipSkuId = skuId;
  }
}
