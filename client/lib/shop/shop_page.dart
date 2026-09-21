import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/shop/shop_detail_page.dart';
import 'package:client/shop/wallet_chip.dart';
import 'package:client/theme/steppe_backdrop.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:client/theme/steppe_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shop shelf: Shop|Owned segment, seven category chips, SKU grid (ECON-02).
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  static const List<String> _slotOrder = <String>[
    'saka_color',
    'saka_material',
    'saka_ornament',
    'trail',
    'table_fx',
    'victory',
    'stick_pull',
  ];

  bool _ownedSegment = false;
  String _selectedSlot = 'saka_color';
  List<ShopSku>? _skus;
  int? _coins;
  int? _gems;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final NomadApi api = ref.read(nomadApiProvider);
      final List<Object> results = await Future.wait<Object>([
        api.fetchShopCatalog(),
        api.fetchWallet(),
      ]);
      if (!mounted) {
        return;
      }
      final ShopCatalog catalog = results[0] as ShopCatalog;
      final WalletBalance wallet = results[1] as WalletBalance;
      setState(() {
        _skus = catalog.skus;
        _coins = wallet.coins;
        _gems = wallet.gems;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _skus = null;
        _loading = false;
        _error = true;
      });
    }
  }

  List<ShopSku> get _visibleSkus {
    final List<ShopSku> all = _skus ?? const <ShopSku>[];
    Iterable<ShopSku> filtered =
        all.where((ShopSku s) => s.slot == _selectedSlot);
    if (_ownedSegment) {
      filtered = filtered.where((ShopSku s) => s.owned);
    }
    return filtered.toList();
  }

  String _categoryLabel(AppLocalizations l10n, String slot) {
    return switch (slot) {
      'saka_color' => l10n.catSakaColor,
      'saka_material' => l10n.catSakaMaterial,
      'saka_ornament' => l10n.catSakaOrnament,
      'trail' => l10n.catTrail,
      'table_fx' => l10n.catTableFx,
      'victory' => l10n.catVictory,
      'stick_pull' => l10n.catStickPull,
      _ => slot,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<ShopSku> visible = _visibleSkus;
    final bool emptyCatalog = !_loading && !_error && (_skus?.isEmpty ?? true);
    final bool emptyOwned = !_loading &&
        !_error &&
        !emptyCatalog &&
        _ownedSegment &&
        visible.isEmpty;

    return Scaffold(
      backgroundColor: SteppeOps.voidBg,
      body: SteppeBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SteppeGhostButton(
                      label: l10n.backToCatalog,
                      onTap: () => context.pop(),
                      minWidth: 88,
                    ),
                    const Spacer(),
                    Text(
                      l10n.shopTitle.toUpperCase(),
                      style: SteppeOps.heading,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_coins != null && _gems != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: WalletChip(coins: _coins!, gems: _gems!),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SteppeChip(
                      label: l10n.shop,
                      selected: !_ownedSegment,
                      onSelected: () => setState(() => _ownedSegment = false),
                    ),
                    const SizedBox(width: 8),
                    SteppeChip(
                      label: l10n.owned,
                      selected: _ownedSegment,
                      onSelected: () => setState(() => _ownedSegment = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _slotOrder.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final String slot = _slotOrder[index];
                      return SteppeChip(
                        label: _categoryLabel(l10n, slot),
                        selected: _selectedSlot == slot,
                        onSelected: () =>
                            setState(() => _selectedSlot = slot),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildBody(l10n, visible, emptyCatalog, emptyOwned),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    List<ShopSku> visible,
    bool emptyCatalog,
    bool emptyOwned,
  ) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SteppeOps.accent),
      );
    }
    if (_error) {
      return SteppeBanner(
        message: l10n.errorShop,
        retryLabel: l10n.retry,
        onRetry: _load,
      );
    }
    if (emptyCatalog) {
      return SteppeBanner(
        message: '${l10n.emptyShopTitle}\n${l10n.emptyShopBody}',
        retryLabel: l10n.retry,
        onRetry: _load,
      );
    }
    if (emptyOwned) {
      return HudPanel(
        child: Text(
          '${l10n.emptyOwnedTitle}\n${l10n.emptyOwnedBody}',
          style: SteppeOps.label,
        ),
      );
    }
    if (visible.isEmpty) {
      return SteppeBanner(
        message: '${l10n.emptyShopTitle}\n${l10n.emptyShopBody}',
        retryLabel: l10n.retry,
        onRetry: _load,
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 104,
      ),
      itemCount: visible.length,
      itemBuilder: (BuildContext context, int index) {
        final ShopSku sku = visible[index];
        return _SkuTile(
          sku: sku,
          name: skuDisplayName(l10n, sku.nameKey),
          priceLabel: _priceLabel(l10n, sku),
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ShopDetailPage(
                  sku: sku,
                  coins: _coins ?? 0,
                  gems: _gems ?? 0,
                ),
              ),
            );
            if (mounted) {
              await _load();
            }
          },
        );
      },
    );
  }

  String _priceLabel(AppLocalizations l10n, ShopSku sku) {
    if (sku.equipped) {
      return l10n.equipped;
    }
    if (sku.owned) {
      return l10n.alreadyOwned;
    }
    if (sku.free || (sku.priceCoins == 0 && sku.priceGems == 0)) {
      return l10n.priceFree;
    }
    if (sku.priceGems > 0) {
      return l10n.priceGems(sku.priceGems);
    }
    return l10n.priceCoins(sku.priceCoins);
  }
}

String skuDisplayName(AppLocalizations l10n, String nameKey) {
  return switch (nameKey) {
    'skuSakaColorDefault' => l10n.skuSakaColorDefault,
    'skuSakaColorGold' => l10n.skuSakaColorGold,
    'skuSakaColorNeon' => l10n.skuSakaColorNeon,
    'skuSakaMaterialDefault' => l10n.skuSakaMaterialDefault,
    'skuSakaMaterialIce' => l10n.skuSakaMaterialIce,
    'skuSakaMaterialFire' => l10n.skuSakaMaterialFire,
    'skuSakaOrnamentDefault' => l10n.skuSakaOrnamentDefault,
    'skuSakaOrnamentSpace' => l10n.skuSakaOrnamentSpace,
    'skuSakaOrnamentKnot' => l10n.skuSakaOrnamentKnot,
    'skuTrailDefault' => l10n.skuTrailDefault,
    'skuTrailGold' => l10n.skuTrailGold,
    'skuTableFxDefault' => l10n.skuTableFxDefault,
    'skuTableFxNeon' => l10n.skuTableFxNeon,
    'skuVictoryDefault' => l10n.skuVictoryDefault,
    'skuVictoryFire' => l10n.skuVictoryFire,
    'skuStickPullDefault' => l10n.skuStickPullDefault,
    'skuStickPullIce' => l10n.skuStickPullIce,
    _ => nameKey,
  };
}

Color skuThemeSwatch(String idOrKey) {
  final String key = idOrKey.toLowerCase();
  if (key.contains('gold')) {
    return SteppeOps.accent;
  }
  if (key.contains('neon')) {
    return const Color(0xFF7CFF6B);
  }
  if (key.contains('ice')) {
    return const Color(0xFF7EB6D9);
  }
  if (key.contains('fire')) {
    return const Color(0xFFE85D04);
  }
  if (key.contains('space')) {
    return const Color(0xFF3D2B8E);
  }
  if (key.contains('knot')) {
    return const Color(0xFF8B4513);
  }
  return SteppeOps.mist;
}

class _SkuTile extends StatelessWidget {
  const _SkuTile({
    required this.sku,
    required this.name,
    required this.priceLabel,
    required this.onTap,
  });

  final ShopSku sku;
  final String name;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color swatch = skuThemeSwatch(sku.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: HudPanel(
          padding: const EdgeInsets.all(10),
          accentEdge: sku.equipped,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: SteppeOps.mist.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                name,
                style: SteppeOps.label.copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                priceLabel,
                style: SteppeOps.labelMuted.copyWith(
                  color: sku.equipped ? SteppeOps.accent : SteppeOps.mistMuted,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
