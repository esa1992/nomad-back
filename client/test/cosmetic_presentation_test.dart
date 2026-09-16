import 'package:client/games/alchiki/match_game.dart';
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
  group('SKU→Color loadout helpers (trail / table_fx / victory)', () {
    test('trailForLoadout maps trail_gold to PRES-02 gold', () {
      expect(
        AlchikiMatchGame.trailForLoadout({'trail': 'trail_gold'}),
        const Color(0xFFF0B429),
      );
    });

    test('trailForLoadout default trail returns cream fallback', () {
      expect(
        AlchikiMatchGame.trailForLoadout({'trail': 'trail_default'}),
        const Color(0xFFF4E8C8),
      );
      expect(
        AlchikiMatchGame.trailForLoadout(const <String, String>{}),
        const Color(0xFFF4E8C8),
      );
    });

    test('tableFxForLoadout maps table_fx_neon to neon', () {
      expect(
        AlchikiMatchGame.tableFxForLoadout({'table_fx': 'table_fx_neon'}),
        const Color(0xFF7CFF6B),
      );
    });

    test('tableFxForLoadout default returns null', () {
      expect(
        AlchikiMatchGame.tableFxForLoadout({'table_fx': 'table_fx_default'}),
        isNull,
      );
      expect(
        AlchikiMatchGame.tableFxForLoadout(const <String, String>{}),
        isNull,
      );
    });

    test('victoryForLoadout maps victory_fire to fire', () {
      expect(
        AlchikiMatchGame.victoryForLoadout({'victory': 'victory_fire'}),
        const Color(0xFFE85D04),
      );
    });
  });

  testWidgets(
    'ResultOverlay local win applies victoryAccent to heading TextStyle',
    (WidgetTester tester) async {
      const Color fire = Color(0xFFE85D04);
      await _pump(
        tester,
        (AppLocalizations l10n) => ResultOverlay(
          l10n: l10n,
          status: 'PLAYER_WIN',
          youScore: 5,
          botScore: 2,
          victoryAccent: fire,
          onBackToCatalog: () {},
          onPlayAgain: () {},
          onShop: () {},
        ),
      );

      final Text heading = tester.widget<Text>(find.text('You win'));
      expect(heading.style?.color, fire);
      expect(find.text('Play again'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Shop'), findsOneWidget);
    },
  );

  testWidgets(
    'ResultOverlay without victoryAccent keeps cream heading',
    (WidgetTester tester) async {
      await _pump(
        tester,
        (AppLocalizations l10n) => ResultOverlay(
          l10n: l10n,
          status: 'PLAYER_WIN',
          youScore: 5,
          botScore: 2,
          onBackToCatalog: () {},
          onPlayAgain: () {},
          onShop: () {},
        ),
      );

      final Text heading = tester.widget<Text>(find.text('You win'));
      expect(heading.style?.color, const Color(0xFFF4E8C8));
    },
  );
}
