import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

const Color _wood = Color(0xFF241810);
const Color _onDark = Color(0xFFF4E8C8);

const TextStyle _label = TextStyle(
  color: _onDark,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  height: 1.2,
);

const TextStyle _body = TextStyle(
  color: _onDark,
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

/// Server-driven reconnect chrome (D-101…D-103). Client displays only — no local forfeit timer.
class ReconnectBanner extends StatelessWidget {
  const ReconnectBanner({
    super.key,
    required this.l10n,
    this.secondsLeft,
    this.opponentLabel,
    this.pauseBudgetGone = false,
    this.useOpponentCopy = false,
    this.graceCap = 30,
  });

  final AppLocalizations l10n;
  final int? secondsLeft;
  final String? opponentLabel;
  final bool pauseBudgetGone;
  final bool useOpponentCopy;
  /// Server grace ceiling: Casual Alchiki 30 / Stick 8; Ranked 18 / 12.
  final int graceCap;

  @override
  Widget build(BuildContext context) {
    final int? secs = secondsLeft;
    final String? reconnectingText = secs == null
        ? null
        : (useOpponentCopy
            ? l10n.opponentReconnecting(
                secs.clamp(0, graceCap).toString().padLeft(2, '0'),
              )
            : l10n.reconnecting(
                secs.clamp(0, graceCap).toString().padLeft(2, '0'),
              ));
    if (reconnectingText == null && !pauseBudgetGone) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _wood.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (opponentLabel != null &&
                opponentLabel!.isNotEmpty &&
                useOpponentCopy) ...[
              Text(opponentLabel!, style: _body, textAlign: TextAlign.center),
              const SizedBox(height: 4),
            ],
            if (reconnectingText != null)
              SizedBox(
                width: double.infinity,
                child: Text(
                  reconnectingText,
                  style: _label,
                  textAlign: TextAlign.center,
                ),
              ),
            if (pauseBudgetGone) ...[
              if (reconnectingText != null) const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  l10n.pauseBudgetGone,
                  style: _label,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
