import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

const Color _wood = Color(0xFF241810);
const Color _onDark = Color(0xFFF4E8C8);
const Color _accent = Color(0xFFF0B429);
const Color _onAccent = Color(0xFF241810);
const Color _destructive = Color(0xFFC43C2C);

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
const TextStyle _heading = TextStyle(
  color: _onDark,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  height: 1.2,
);
const TextStyle _display = TextStyle(
  color: _onDark,
  fontSize: 28,
  fontWeight: FontWeight.w600,
  height: 1.2,
);

/// Pause panel: Resume, How to play, Leave match (D-14).
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.l10n,
    required this.onResume,
    required this.onHowToPlay,
    required this.onLeave,
  });

  final AppLocalizations l10n;
  final VoidCallback onResume;
  final VoidCallback onHowToPlay;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return _ScrimPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pause, style: _heading, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _PanelButton(
            label: l10n.resume,
            fill: _accent,
            textColor: _onAccent,
            onTap: onResume,
          ),
          const SizedBox(height: 24),
          _PanelButton(
            label: l10n.howToPlay,
            fill: _wood,
            textColor: _onDark,
            outlined: true,
            onTap: onHowToPlay,
          ),
          const SizedBox(height: 24),
          _PanelButton(
            label: l10n.leaveMatch,
            fill: _wood,
            textColor: _onDark,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

/// Destructive leave confirm. Stay dismisses; Leave match POSTs /leave.
/// Optional [body] defaults to [AppLocalizations.leaveBody]; private matches
/// pass [AppLocalizations.leaveBodyPrivate]; Ranked uses [AppLocalizations.leaveRankedBody].
class LeaveConfirm extends StatelessWidget {
  const LeaveConfirm({
    super.key,
    required this.l10n,
    required this.onStay,
    required this.onLeaveMatch,
    this.body,
  });

  final AppLocalizations l10n;
  final VoidCallback onStay;
  final VoidCallback onLeaveMatch;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return _ScrimPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.leaveTitle, style: _heading, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(body ?? l10n.leaveBody, style: _body, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _PanelButton(
                  label: l10n.stay,
                  fill: _wood,
                  textColor: _onDark,
                  outlined: true,
                  onTap: onStay,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PanelButton(
                  label: l10n.leaveMatch,
                  fill: _destructive,
                  textColor: _onDark,
                  onTap: onLeaveMatch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Terminal result. Bot Play again is one-tap; casual Play again opens rematch-wait;
/// private Again? is a 10s dual accept on this overlay (D-43, D-70).
/// Ranked: Find Ranked match only — no rematch dual-accept (D-99).
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.l10n,
    required this.status,
    required this.youScore,
    required this.botScore,
    required this.onBackToCatalog,
    this.opponentLabel,
    this.localSeat,
    this.onPlayAgain,
    this.onRematchAccept,
    this.onFindRankedMatch,
    this.isPrivate = false,
    this.isRanked = false,
    this.rematchSeconds,
    this.rematchAcceptedLocal = false,
    this.rematchError = false,
    this.onRematchRetry,
    this.coinsGranted = 0,
    this.gemsGranted = 0,
    this.onShop,
    this.victoryAccent,
  });

  final AppLocalizations l10n;
  final String status;
  final int youScore;
  final int botScore;
  final VoidCallback onBackToCatalog;
  final String? opponentLabel;
  final String? localSeat;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onRematchAccept;
  final VoidCallback? onFindRankedMatch;
  final bool isPrivate;
  final bool isRanked;
  final int? rematchSeconds;
  final bool rematchAcceptedLocal;
  final bool rematchError;
  final VoidCallback? onRematchRetry;
  final int coinsGranted;
  final int gemsGranted;
  final VoidCallback? onShop;

  /// Equipped victory SKU tint; applied only on local win (D-46, D-54).
  final Color? victoryAccent;

  @override
  Widget build(BuildContext context) {
    final bool localWin = switch (status) {
      'PLAYER_WIN' => true,
      'HOST_WIN' => localSeat == 'host',
      'JOINER_WIN' => localSeat == 'joiner',
      _ => false,
    };
    final String heading = switch (status) {
      'PLAYER_WIN' => l10n.youWin,
      'BOT_WIN' => l10n.botWins,
      'OPPONENT_WIN' => l10n.opponentWins,
      'HOST_WIN' => localSeat == 'host' ? l10n.youWin : l10n.opponentWins,
      'JOINER_WIN' => localSeat == 'joiner' ? l10n.youWin : l10n.opponentWins,
      _ => l10n.draw,
    };
    final String pair = opponentLabel == null
        ? '${l10n.you} $youScore — ${l10n.bot} $botScore'
        : '${l10n.you} $youScore — $opponentLabel $botScore';
    final TextStyle rewardStyle =
        (coinsGranted > 0 && gemsGranted > 0) ? _body : _label;
    final TextStyle headingStyle = (localWin && victoryAccent != null)
        ? _heading.copyWith(color: victoryAccent)
        : _heading;
    return _ScrimPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(heading, style: headingStyle, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            pair,
            style: _display,
            textAlign: TextAlign.center,
          ),
          if (coinsGranted > 0) ...[
            const SizedBox(height: 8),
            Text(
              l10n.rewardCoins(coinsGranted),
              style: rewardStyle,
              textAlign: TextAlign.center,
            ),
          ],
          if (gemsGranted > 0) ...[
            const SizedBox(height: 8),
            Text(
              l10n.rewardGems(gemsGranted),
              style: rewardStyle,
              textAlign: TextAlign.center,
            ),
          ],
          if (rematchError) ...[
            const SizedBox(height: 16),
            Text(l10n.errorRematch, style: _body, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _PanelButton(
              label: l10n.retry,
              fill: _accent,
              textColor: _onAccent,
              onTap: onRematchRetry ?? onPlayAgain ?? onRematchAccept,
            ),
          ] else ...[
            if (isPrivate && !isRanked && rematchSeconds != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.rematchClock(rematchSeconds!.toString().padLeft(2, '0')),
                style: _label,
                textAlign: TextAlign.center,
              ),
            ],
            if (isPrivate && !isRanked && rematchAcceptedLocal) ...[
              const SizedBox(height: 16),
              Text(
                l10n.waitingForName(opponentLabel ?? ''),
                style: _label,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            if (isRanked && onFindRankedMatch != null)
              _PanelButton(
                label: l10n.findRankedMatch,
                fill: _accent,
                textColor: _onAccent,
                onTap: onFindRankedMatch,
              )
            else if (!isPrivate && onPlayAgain != null)
              _PanelButton(
                label: l10n.playAgain,
                fill: _accent,
                textColor: _onAccent,
                onTap: onPlayAgain,
              ),
            if (isPrivate && !isRanked)
              _PanelButton(
                label: l10n.rematchAgain,
                fill: rematchAcceptedLocal ? _wood : _accent,
                textColor: rematchAcceptedLocal ? _onDark : _onAccent,
                outlined: rematchAcceptedLocal,
                onTap: rematchAcceptedLocal ? null : onRematchAccept,
              ),
          ],
          const SizedBox(height: 24),
          _PanelButton(
            label: l10n.backToCatalog,
            fill: _wood,
            textColor: _onDark,
            outlined: true,
            onTap: onBackToCatalog,
          ),
          if (onShop != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onShop,
              style: TextButton.styleFrom(
                foregroundColor: _onDark,
                minimumSize: const Size(48, 48),
              ),
              child: Text(l10n.shop, style: _label),
            ),
          ],
        ],
      ),
    );
  }
}

/// Process-death grace: Rejoin match only — no Back to catalog (D-41, UI-SPEC).
class RejoinOverlay extends StatelessWidget {
  const RejoinOverlay({
    super.key,
    required this.l10n,
    required this.secondsLeft,
    required this.onRejoin,
    this.error = false,
  });

  final AppLocalizations l10n;
  final int secondsLeft;
  final VoidCallback onRejoin;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final String ss = secondsLeft.clamp(0, 30).toString().padLeft(2, '0');
    return _ScrimPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reconnecting(ss),
            style: _heading,
            textAlign: TextAlign.center,
          ),
          if (error) ...[
            const SizedBox(height: 16),
            Text(l10n.errorRejoin, style: _body, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          _PanelButton(
            label: l10n.rejoinMatch,
            fill: _accent,
            textColor: _onAccent,
            onTap: onRejoin,
          ),
        ],
      ),
    );
  }
}

class _ScrimPanel extends StatelessWidget {
  const _ScrimPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _wood.withValues(alpha: 0.60),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _wood.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.fill,
    required this.textColor,
    this.onTap,
    this.outlined = false,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.transparent : fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: outlined ? const BorderSide(color: _onDark) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(label, style: _label.copyWith(color: textColor)),
            ),
          ),
        ),
      ),
    );
  }
}
