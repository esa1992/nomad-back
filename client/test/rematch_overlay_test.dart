import 'package:client/games/alchiki/pause_overlay.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget Function(AppLocalizations l10n) builder,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(body: builder(AppLocalizations.of(context)));
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
    'private LeaveConfirm shows leaveBodyPrivate and not Bot',
    (WidgetTester tester) async {
      await _pump(
        tester,
        (AppLocalizations l10n) => LeaveConfirm(
          l10n: l10n,
          body: l10n.leaveBodyPrivate,
          onStay: () {},
          onLeaveMatch: () {},
        ),
      );

      expect(find.textContaining('Your opponent will win'), findsOneWidget);
      expect(find.textContaining('Bot'), findsNothing);
    },
  );

  testWidgets(
    'private ResultOverlay HOST_WIN for joiner is opponentWins, never Bot wins',
    (WidgetTester tester) async {
      await _pump(
        tester,
        (AppLocalizations l10n) => ResultOverlay(
          l10n: l10n,
          status: 'HOST_WIN',
          localSeat: 'joiner',
          youScore: 1,
          botScore: 3,
          opponentLabel: 'Guest-A1B2',
          onBackToCatalog: () {},
        ),
      );

      expect(find.text('Opponent wins'), findsOneWidget);
      expect(find.text('Bot wins'), findsNothing);
    },
  );

  testWidgets('bot ResultOverlay finds Play again and Bot', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      (AppLocalizations l10n) => ResultOverlay(
        l10n: l10n,
        status: 'PLAYER_WIN',
        youScore: 5,
        botScore: 2,
        onBackToCatalog: () {},
        onPlayAgain: () {},
      ),
    );

    expect(find.text('Play again'), findsOneWidget);
    expect(find.textContaining('Bot'), findsOneWidget);
  });

  testWidgets(
    'private ResultOverlay finds Again? and Opponent wins and does not find Bot wins',
    (WidgetTester tester) async {
      await _pump(
        tester,
        (AppLocalizations l10n) => ResultOverlay(
          l10n: l10n,
          status: 'HOST_WIN',
          localSeat: 'joiner',
          youScore: 1,
          botScore: 5,
          opponentLabel: 'Guest-A1B2',
          isPrivate: true,
          rematchSeconds: 10,
          onBackToCatalog: () {},
          onRematchAccept: () {},
        ),
      );

      expect(find.text('Again?'), findsOneWidget);
      expect(find.text('Opponent wins'), findsOneWidget);
      expect(find.text('Bot wins'), findsNothing);
    },
  );
}
