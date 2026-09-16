import 'package:client/games/alchiki/match_hud.dart';
import 'package:client/games/alchiki/pause_overlay.dart';
import 'package:client/games/shared/reconnect_banner.dart';
import 'package:client/games/stick_pull/stick_pull_hud.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// SESS-03 Ranked reconnect HUD copy (07-UI-SPEC: pauseBudgetGone, leaveRankedBody, 18/12 caps).

Future<void> _pumpLocalized(
  WidgetTester tester,
  Widget Function(AppLocalizations l10n) builder,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (BuildContext context) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          return Scaffold(body: builder(l10n));
        },
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('pauseBudgetGone', (WidgetTester tester) async {
    await _pumpLocalized(
      tester,
      (AppLocalizations l10n) => ReconnectBanner(
        l10n: l10n,
        pauseBudgetGone: true,
        graceCap: 18,
      ),
    );
    expect(
      find.text('No reconnect left — forfeit if you drop'),
      findsOneWidget,
    );
  });

  testWidgets('leaveRankedBody', (WidgetTester tester) async {
    await _pumpLocalized(
      tester,
      (AppLocalizations l10n) => LeaveConfirm(
        l10n: l10n,
        body: l10n.leaveRankedBody,
        onStay: () {},
        onLeaveMatch: () {},
      ),
    );
    expect(
      find.text('Leave this match? It counts as a rated loss.'),
      findsOneWidget,
    );
  });

  testWidgets('rankedReconnectHudShowsGrace', (WidgetTester tester) async {
    await _pumpLocalized(
      tester,
      (AppLocalizations l10n) => MatchHud(
        l10n: l10n,
        youScore: 0,
        botScore: 0,
        difficulty: 'NORMAL',
        preview: 0,
        scored: null,
        sakaOut: false,
        turnClockLabel: 'turn 20',
        matchClockLabel: 'match 4:00',
        isPlayerTurn: true,
        showTimeout: false,
        isPrivate: true,
        opponentLabel: 'Guest-RC01',
        reconnectSeconds: 18,
        graceCap: 18,
      ),
    );
    expect(find.textContaining('Reconnecting'), findsOneWidget);
    expect(find.text('Reconnecting… 18'), findsOneWidget);
  });

  testWidgets('rankedStickPullGraceCapTwelve', (WidgetTester tester) async {
    await _pumpLocalized(
      tester,
      (AppLocalizations l10n) => StickPullHudReconnect(
        l10n: l10n,
        secondsLeft: 12,
        isRanked: true,
      ),
    );
    expect(find.text('Opponent reconnecting… 12'), findsOneWidget);
  });
}
