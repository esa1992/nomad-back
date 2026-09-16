import 'package:client/games/shared/reconnect_banner.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Stick Pull reconnect / pause-budget HUD chrome (SESS-03 / D-101…D-103).
class StickPullHudReconnect extends StatelessWidget {
  const StickPullHudReconnect({
    super.key,
    required this.l10n,
    this.secondsLeft,
    this.opponentLabel,
    this.pauseBudgetGone = false,
    this.isRanked = false,
  });

  final AppLocalizations l10n;
  final int? secondsLeft;
  final String? opponentLabel;
  final bool pauseBudgetGone;
  final bool isRanked;

  /// Casual Stick Pull 8s; Ranked Stick Pull 12s (D-101).
  int get graceCap => isRanked ? 12 : 8;

  @override
  Widget build(BuildContext context) {
    return ReconnectBanner(
      l10n: l10n,
      secondsLeft: secondsLeft,
      opponentLabel: opponentLabel,
      pauseBudgetGone: pauseBudgetGone,
      useOpponentCopy: true,
      graceCap: graceCap,
    );
  }
}
