import 'dart:math';

import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/shop/shop_page.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Static felt-preview detail (D-57). Soft Buy + Equip wired (ECON-03).
class ShopDetailPage extends ConsumerStatefulWidget {
  const ShopDetailPage({
    super.key,
    required this.sku,
    required this.coins,
    required this.gems,
  });

  final ShopSku sku;
  final int coins;
  final int gems;

  static const Color _wood = SteppeOps.voidBg;
  static const Color _cream = SteppeOps.mist;
  static const Color _felt = SteppeOps.felt;
  static const Color _accent = SteppeOps.accent;
  static const Color _onAccent = SteppeOps.onAccent;
  static const Color _destructive = SteppeOps.danger;

  static const TextStyle _label = SteppeOps.label;
  static const TextStyle _body = SteppeOps.labelMuted;
  static const TextStyle _heading = SteppeOps.heading;

  @override
  ConsumerState<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends ConsumerState<ShopDetailPage> {
  late ShopSku _sku;
  late int _coins;
  late int _gems;
  String? _inFlightKey;
  bool _buying = false;
  bool _equipping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sku = widget.sku;
    _coins = widget.coins;
    _gems = widget.gems;
  }

  bool get _canAfford {
    if (_sku.free || (_sku.priceCoins == 0 && _sku.priceGems == 0)) {
      return true;
    }
    if (_sku.priceGems > 0) {
      return _gems >= _sku.priceGems;
    }
    return _coins >= _sku.priceCoins;
  }

  static String _newIdempotencyKey() {
    final Random rng = Random.secure();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < 32; i++) {
      buf.write(rng.nextInt(16).toRadixString(16));
    }
    return buf.toString();
  }

  Future<void> _buy() async {
    if (_buying || !_canAfford || _sku.owned) {
      return;
    }
    final String key = _inFlightKey ?? _newIdempotencyKey();
    setState(() {
      _buying = true;
      _inFlightKey = key;
      _error = null;
    });
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final PurchaseResult result = await ref.read(nomadApiProvider).purchaseSku(
            skuId: _sku.id,
            idempotencyKey: key,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _coins = result.coins;
        _gems = result.gems;
        _sku = ShopSku(
          id: _sku.id,
          slot: _sku.slot,
          nameKey: _sku.nameKey,
          priceCoins: _sku.priceCoins,
          priceGems: _sku.priceGems,
          owned: result.owned,
          equipped: _sku.equipped,
          free: _sku.free,
        );
        _buying = false;
        _inFlightKey = null;
        _error = null;
      });
    } on NomadApiException catch (error) {
      if (!mounted) {
        return;
      }
      final bool insufficient = error.statusCode == 409 &&
          error.message.toLowerCase().contains('insufficient_funds');
      setState(() {
        _buying = false;
        // New key after hard failure; keep same key only while in-flight (D-59).
        _inFlightKey = null;
        _error = insufficient ? l10n.errorInsufficientFunds : l10n.errorPurchase;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buying = false;
        _inFlightKey = null;
        _error = l10n.errorPurchase;
      });
    }
  }

  Future<void> _equip() async {
    if (_equipping || !_sku.owned || _sku.equipped) {
      return;
    }
    setState(() {
      _equipping = true;
      _error = null;
    });
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      await ref.read(nomadApiProvider).equipSku(slot: _sku.slot, skuId: _sku.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _sku = ShopSku(
          id: _sku.id,
          slot: _sku.slot,
          nameKey: _sku.nameKey,
          priceCoins: _sku.priceCoins,
          priceGems: _sku.priceGems,
          owned: _sku.owned,
          equipped: true,
          free: _sku.free,
        );
        _equipping = false;
        _error = null;
      });
    } on NomadApiException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _equipping = false;
        _error = l10n.errorEquip;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _equipping = false;
        _error = l10n.errorEquip;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = skuDisplayName(l10n, _sku.nameKey);
    final String price = _priceRow(l10n);
    final bool showBuy = !_sku.owned && !_sku.free;
    final bool showEquip = _sku.owned && !_sku.equipped;
    final bool showEquipped = _sku.equipped;
    final bool buyEnabled = _canAfford && !_buying;
    final bool equipEnabled = !_equipping;

    return Scaffold(
      backgroundColor: ShopDetailPage._wood,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _ChromeButton(
                    label: l10n.backToShop,
                    outlined: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      name,
                      style: ShopDetailPage._heading,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(child: _FeltPreview(sku: _sku)),
              const SizedBox(height: 24),
              Text(price, style: ShopDetailPage._label, textAlign: TextAlign.center),
              if (showBuy && !_canAfford) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.errorInsufficientFunds,
                  style: ShopDetailPage._body,
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: ShopDetailPage._body.copyWith(
                    color: ShopDetailPage._destructive,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              if (showBuy)
                _ChromeButton(
                  label: l10n.buyItem,
                  outlined: false,
                  enabled: buyEnabled,
                  onTap: _buy,
                ),
              if (showEquip) ...[
                if (showBuy) const SizedBox(height: 16),
                _ChromeButton(
                  label: l10n.equipItem,
                  outlined: false,
                  enabled: equipEnabled,
                  onTap: _equip,
                ),
              ],
              if (showEquipped) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.equipped,
                  style: ShopDetailPage._label,
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null && showEquip && !_equipping) ...[
                const SizedBox(height: 16),
                _ChromeButton(
                  label: l10n.retry,
                  outlined: true,
                  onTap: _equip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _priceRow(AppLocalizations l10n) {
    if (_sku.free || (_sku.priceCoins == 0 && _sku.priceGems == 0)) {
      return l10n.priceFree;
    }
    if (_sku.owned) {
      return l10n.alreadyOwned;
    }
    if (_sku.priceGems > 0) {
      return l10n.priceGems(_sku.priceGems);
    }
    return l10n.priceCoins(_sku.priceCoins);
  }
}

class _FeltPreview extends StatelessWidget {
  const _FeltPreview({required this.sku});

  final ShopSku sku;

  static const Color _felt = Color(0xFF1B6B3A);
  static const Color _cream = Color(0xFFF4E8C8);
  static const Color _rim = Color(0xFFE8D4A8);

  @override
  Widget build(BuildContext context) {
    final Color swatch = skuThemeSwatch(sku.id);
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: _felt,
        shape: BoxShape.circle,
        border: Border.all(color: _rim, width: 2),
      ),
      child: Center(
        child: sku.slot == 'stick_pull'
            ? CustomPaint(
                size: const Size(56, 12),
                painter: _StickPainter(color: swatch),
              )
            : sku.slot == 'trail'
                ? CustomPaint(
                    size: const Size(48, 48),
                    painter: _TrailPainter(color: swatch),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: _cream, width: 1),
                    ),
                  ),
      ),
    );
  }
}

class _StickPainter extends CustomPainter {
  _StickPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StickPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final Path path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.2,
        size.width * 0.85,
        size.height * 0.35,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.label,
    required this.outlined,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool outlined;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color fill = outlined
        ? ShopDetailPage._wood
        : ShopDetailPage._accent;
    final Color text = outlined
        ? ShopDetailPage._cream
        : ShopDetailPage._onAccent;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: SizedBox(
        height: 48,
        child: Material(
          color: fill,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: outlined
                      ? ShopDetailPage._cream
                      : ShopDetailPage._accent,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: ShopDetailPage._label.copyWith(color: text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
