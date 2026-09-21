import 'package:client/games/shared/reconnect_banner.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/theme/steppe_ops.dart';
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

  @override
  Widget build(BuildContext context) {
    final String oppName =
        isPrivate && opponentLabel != null ? opponentLabel! : l10n.bot;
    final String turnLine = isPlayerTurn
        ? l10n.yourTurn
        : (isPrivate ? l10n.opponentsTurn : l10n.botsTurn);
    final bool showBanner =
        reconnectLabel != null || reconnectSeconds != null || pauseBudgetGone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ScoreFrame(
                label: l10n.you,
                score: youScore,
                active: isPlayerTurn,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScoreFrame(
                label: oppName,
                score: botScore,
                active: !isPlayerTurn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _HudFrame(label: '${l10n.firstToFive} · $difficulty'),
            _HudFrame(label: turnClockLabel),
            _HudFrame(label: matchClockLabel),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _HudFrame(label: turnLine, accent: isPlayerTurn),
            _HudFrame(label: l10n.previewHud(preview), muted: true),
            _HudFrame(
              label: scored == null
                  ? l10n.scoredDash
                  : l10n.scoredHud(scored!),
              muted: true,
            ),
            if (sakaOut)
              _HudFrame(label: l10n.sakaOutLine, accent: true, danger: true),
          ],
        ),
        if (showBanner) ...[
          const SizedBox(height: 8),
          if (reconnectLabel != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: SteppeOps.panel,
                border: Border.all(color: SteppeOps.accent.withValues(alpha: 0.55)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  reconnectLabel!,
                  style: SteppeOps.label.copyWith(fontSize: 13),
                  textAlign: TextAlign.center,
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
          _HudFrame(label: l10n.turnTimeout, accent: true),
        ],
      ],
    );
  }
}

class _ScoreFrame extends StatelessWidget {
  const _ScoreFrame({
    required this.label,
    required this.score,
    required this.active,
  });

  final String label;
  final int score;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color border = active
        ? SteppeOps.accent
        : SteppeOps.mist.withValues(alpha: 0.35);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SteppeOps.panel,
        border: Border.all(color: border, width: active ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SteppeOps.label.copyWith(
                fontSize: 11,
                letterSpacing: 0.8,
                color: active
                    ? SteppeOps.accent
                    : SteppeOps.mist.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$score',
              style: SteppeOps.heading.copyWith(
                fontSize: 28,
                height: 1.05,
                color: active ? SteppeOps.accent : SteppeOps.mist,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudFrame extends StatelessWidget {
  const _HudFrame({
    required this.label,
    this.accent = false,
    this.muted = false,
    this.danger = false,
  });

  final String label;
  final bool accent;
  final bool muted;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color border = danger
        ? SteppeOps.danger
        : accent
            ? SteppeOps.accent
            : SteppeOps.mist.withValues(alpha: muted ? 0.22 : 0.35);
    final Color bg = danger
        ? SteppeOps.danger
        : accent
            ? SteppeOps.accent
            : SteppeOps.panel;
    final Color fg = (accent || danger)
        ? SteppeOps.onAccent
        : (muted
            ? SteppeOps.mist.withValues(alpha: 0.75)
            : SteppeOps.mist);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: SteppeOps.label.copyWith(
            fontSize: muted && !danger ? 12 : 13,
            letterSpacing: 0.4,
            color: fg,
          ),
        ),
      ),
    );
  }
}
