import 'package:client/games/shared/reconnect_banner.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Score pair, first-to-5, preview/scored, and server-clock HUD (D-19).
class MatchHud extends StatelessWidget {
  const MatchHud({
    super.key,
    required this.l10n,
    required this.youScore,
    required this.botScore,
    required this.difficulty,
    required this.preview,
    required this.scored,
    required this.sakaOut,
    required this.turnClockLabel,
    required this.matchClockLabel,
    required this.isPlayerTurn,
    required this.showTimeout,
    this.isPrivate = false,
    this.opponentLabel,
    this.reconnectLabel,
    this.reconnectSeconds,
    this.pauseBudgetGone = false,
    this.graceCap = 30,
  });

  final AppLocalizations l10n;
  final int youScore;
  final int botScore;
  final String difficulty;
  final int preview;
  final int? scored;
  final bool sakaOut;
  final String turnClockLabel;
  final String matchClockLabel;
  final bool isPlayerTurn;
  final bool showTimeout;
  final bool isPrivate;
  final String? opponentLabel;
  final String? reconnectLabel;
  final int? reconnectSeconds;
  final bool pauseBudgetGone;
  /// Casual Alchiki 30; Ranked Alchiki 18 (D-101).
  final int graceCap;

  static const Color _onDark = Color(0xFFF4E8C8);

  static const TextStyle _label = TextStyle(
    color: _onDark,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle _body = TextStyle(
    color: _onDark,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle _heading = TextStyle(
    color: _onDark,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    final String pair = isPrivate && opponentLabel != null
        ? '${l10n.you} $youScore — $opponentLabel $botScore'
        : '${l10n.you} $youScore — ${l10n.bot} $botScore';
    final String turnLine = isPlayerTurn
        ? l10n.yourTurn
        : (isPrivate ? l10n.opponentsTurn : l10n.botsTurn);
    final bool showBanner =
        reconnectLabel != null || reconnectSeconds != null || pauseBudgetGone;
    return Column(
      children: [
        Text(pair, style: _heading),
        const SizedBox(height: 8),
        Text('${l10n.firstToFive} · $difficulty', style: _label),
        const SizedBox(height: 8),
        Text(l10n.previewHud(preview), style: _label),
        const SizedBox(height: 8),
        Text(scored == null ? l10n.scoredDash : l10n.scoredHud(scored!), style: _label),
        if (sakaOut) ...[
          const SizedBox(height: 8),
          Text(l10n.sakaOutLine, style: _body),
        ],
        const SizedBox(height: 8),
        Text(turnClockLabel, style: _label),
        const SizedBox(height: 8),
        Text(matchClockLabel, style: _label),
        const SizedBox(height: 8),
        Text(turnLine, style: _label),
        if (showBanner) ...[
          const SizedBox(height: 8),
          if (reconnectLabel != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF241810).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    reconnectLabel!,
                    style: _label,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            ReconnectBanner(
              l10n: l10n,
              secondsLeft: reconnectSeconds,
              pauseBudgetGone: pauseBudgetGone,
              graceCap: graceCap,
            ),
        ],
        if (showTimeout) ...[
          const SizedBox(height: 8),
          Text(l10n.turnTimeout, style: _body),
        ],
      ],
    );
  }
}
