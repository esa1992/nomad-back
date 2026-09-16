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
  testWidgets('ResultOverlay shows rewardCoins and secondary Shop', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      (AppLocalizations l10n) => ResultOverlay(
        l10n: l10n,
        status: 'PLAYER_WIN',
        youScore: 5,
        botScore: 2,
        coinsGranted: 24,
        gemsGranted: 0,
        onBackToCatalog: () {},
        onPlayAgain: () {},
        onShop: () {},
      ),
    );

    expect(find.text('+24 COINS'), findsOneWidget);
    expect(find.textContaining('GEMS'), findsNothing);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Back to catalog'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Shop'), findsOneWidget);
  });

  testWidgets('ResultOverlay shows rewardGems when gemsGranted > 0', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      (AppLocalizations l10n) => ResultOverlay(
        l10n: l10n,
        status: 'PLAYER_WIN',
        youScore: 5,
        botScore: 1,
        coinsGranted: 24,
        gemsGranted: 1,
        onBackToCatalog: () {},
        onPlayAgain: () {},
        onShop: () {},
      ),
    );

    expect(find.text('+24 COINS'), findsOneWidget);
    expect(find.text('+1 GEMS'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
  });

  testWidgets(
    'ResultOverlay victory accent tints local-win heading only',
    (WidgetTester tester) async {
      const Color fire = Color(0xFFE85D04);
      await _pump(
        tester,
        (AppLocalizations l10n) => ResultOverlay(
          l10n: l10n,
          status: 'PLAYER_WIN',
          youScore: 3,
          botScore: 1,
          victoryAccent: fire,
          coinsGranted: 24,
          onBackToCatalog: () {},
          onPlayAgain: () {},
          onShop: () {},
        ),
      );

      final Text heading = tester.widget<Text>(find.text('You win'));
      expect(heading.style?.color, fire);
      expect(find.text('+24 COINS'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Shop'), findsOneWidget);
    },
  );
}
