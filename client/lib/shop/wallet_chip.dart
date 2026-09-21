import 'package:client/l10n/app_localizations.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:flutter/material.dart';

/// Read-only dual wallet chip (D-48 / ECON-04). Display only — never authorizes buys.
class WalletChip extends StatelessWidget {
  const WalletChip({
    super.key,
    required this.coins,
    required this.gems,
    this.compact = false,
  });

  final int coins;
  final int gems;

  /// Lobby top bar: numbers only (full words stay in semantics / tap hint).
  final bool compact;

  void _showHint(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SteppeOps.panelSolid,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(
          l10n.walletHint(coins, gems),
          style: SteppeOps.label.copyWith(fontSize: 13, height: 1.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.walletA11y(coins, gems),
      button: true,
      onTap: () => _showHint(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHint(context),
          child: SizedBox(
            height: compact ? 36 : 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SteppeOps.panel,
                border: Border.all(
                  color: SteppeOps.mist.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                child: Center(
                  child: compact
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _Dot(color: SteppeOps.accent),
                            const SizedBox(width: 4),
                            Text(
                              '$coins',
                              style: SteppeOps.label.copyWith(fontSize: 12),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '·',
                                style: SteppeOps.labelMuted
                                    .copyWith(fontSize: 12),
                              ),
                            ),
                            const _Dot(color: Color(0xFF7EB6D9)),
                            const SizedBox(width: 4),
                            Text(
                              '$gems',
                              style: SteppeOps.label.copyWith(fontSize: 12),
                            ),
                          ],
                        )
                      : Text(
                          '${l10n.coins} $coins · ${l10n.gems} $gems',
                          style: SteppeOps.label.copyWith(fontSize: 12),
                          maxLines: 1,
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

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
