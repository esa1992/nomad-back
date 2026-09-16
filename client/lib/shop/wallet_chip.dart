import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Read-only dual wallet chip (D-48 / ECON-04). Display only — never authorizes buys.
class WalletChip extends StatelessWidget {
  const WalletChip({
    super.key,
    required this.coins,
    required this.gems,
  });

  final int coins;
  final int gems;

  static const Color _wood = Color(0xFF241810);
  static const Color _cream = Color(0xFFF4E8C8);

  static const TextStyle _label = TextStyle(
    color: _cream,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String text = '${l10n.coins} $coins · ${l10n.gems} $gems';
    return Semantics(
      label: l10n.walletA11y(coins, gems),
      button: false,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _wood,
              border: Border.all(color: _cream, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(text, style: _label, maxLines: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
