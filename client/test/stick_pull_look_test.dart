import 'package:client/games/stick_pull/stick_pull_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stick pull lane is packed earth, not billiard felt', () {
    expect(StickPullGame.earth, isNot(const Color(0xFF1B6B3A)));
    expect(StickPullGame.defaultShaft, const Color(0xFFD4B896));
  });

  test('shaftColorForLoadout maps ice and defaults to light wood', () {
    expect(
      StickPullGame.shaftColorForLoadout(const <String, String>{}),
      StickPullGame.defaultShaft,
    );
    expect(
      StickPullGame.shaftColorForLoadout({'stick_pull': 'stick_pull_ice'}),
      StickPullGame.iceShaft,
    );
  });

  testWidgets('StickPullGame loads and accepts marker updates', (
    WidgetTester tester,
  ) async {
    final StickPullGame game = StickPullGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: GameWidget<StickPullGame>(game: game),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    game.setMarker(-0.5);
    expect(game.marker, closeTo(-0.5, 1e-6));
  });
}
