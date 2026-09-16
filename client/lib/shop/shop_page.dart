import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/shop/shop_detail_page.dart';
import 'package:client/shop/wallet_chip.dart';
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
  static const Color _wood = Color(0xFF241810);
  static const Color _cream = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);
  static const Color _destructive = Color(0xFFC43C2C);

  static const TextStyle _label = TextStyle(
    color: _cream,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle _body = TextStyle(
    color: _cream,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle _heading = TextStyle(
    color: _cream,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

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
    Iterable<ShopSku> filtered = all.where((ShopSku s) => s.slot == _selectedSlot);
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
    final bool emptyOwned =
        !_loading &&
        !_error &&
        !emptyCatalog &&
        _ownedSegment &&
        visible.isEmpty;

    return Scaffold(
      backgroundColor: _wood,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _OutlineButton(
                    label: l10n.backToCatalog,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  Text(l10n.shopTitle, style: _heading),
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
                  _SegmentChip(
                    label: l10n.shop,
                    selected: !_ownedSegment,
                    onTap: () => setState(() => _ownedSegment = false),
                  ),
                  const SizedBox(width: 8),
                  _SegmentChip(
                    label: l10n.owned,
                    selected: _ownedSegment,
                    onTap: () => setState(() => _ownedSegment = true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _slotOrder.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final String slot = _slotOrder[index];
                    return _SegmentChip(
                      label: _categoryLabel(l10n, slot),
                      selected: _selectedSlot == slot,
                      onTap: () => setState(() => _selectedSlot = slot),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildBody(l10n, visible, emptyCatalog, emptyOwned)),
            ],
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
      return const SizedBox.shrink();
    }
    if (_error) {
      return _MessagePanel(
        title: l10n.errorShop,
        body: null,
        retryLabel: l10n.retry,
        onRetry: _load,
      );
    }
    if (emptyCatalog) {
      return _MessagePanel(
        title: l10n.emptyShopTitle,
        body: l10n.emptyShopBody,
        retryLabel: l10n.retry,
        onRetry: _load,
      );
    }
    if (emptyOwned) {
      return _MessagePanel(
        title: l10n.emptyOwnedTitle,
        body: l10n.emptyOwnedBody,
        retryLabel: null,
        onRetry: null,
      );
    }
    if (visible.isEmpty) {
      return _MessagePanel(
        title: l10n.emptyShopTitle,
        body: l10n.emptyShopBody,
        retryLabel: l10n.retry,
        onRetry: _load,
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 96,
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
    return const Color(0xFFF0B429);
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
  return const Color(0xFFFFF6D6);
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: selected
            ? _ShopPageState._accent
            : _ShopPageState._wood,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? _ShopPageState._accent
                    : _ShopPageState._cream,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  label,
                  style: _ShopPageState._label.copyWith(
                    color: selected
                        ? _ShopPageState._onAccent
                        : _ShopPageState._cream,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: _ShopPageState._wood,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _ShopPageState._cream, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(label, style: _ShopPageState._label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String? body;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _ShopPageState._destructive, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _ShopPageState._body),
                if (body != null) ...[
                  const SizedBox(height: 8),
                  Text(body!, style: _ShopPageState._body),
                ],
              ],
            ),
          ),
        ),
        if (retryLabel != null && onRetry != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _OutlineButton(label: retryLabel!, onTap: onRetry!),
          ),
        ],
      ],
    );
  }
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
      color: _ShopPageState._wood,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _ShopPageState._cream, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: _ShopPageState._cream, width: 1),
                  ),
                ),
                const Spacer(),
                Text(
                  name,
                  style: _ShopPageState._label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  priceLabel,
                  style: _ShopPageState._label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
