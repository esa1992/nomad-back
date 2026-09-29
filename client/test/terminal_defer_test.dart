import 'package:client/games/alchiki/match_page.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isAlchikiTerminalStatus covers win and draw seats', () {
    expect(isAlchikiTerminalStatus('PLAYER_WIN'), isTrue);
    expect(isAlchikiTerminalStatus('BOT_WIN'), isTrue);
    expect(isAlchikiTerminalStatus('DRAW'), isTrue);
    expect(isAlchikiTerminalStatus('HOST_WIN'), isTrue);
    expect(isAlchikiTerminalStatus('JOINER_WIN'), isTrue);
    expect(isAlchikiTerminalStatus('IN_PLAY'), isFalse);
    expect(isAlchikiTerminalStatus(null), isFalse);
  });

  test('matchStartAsInPlay keeps scores but clears terminal status', () {
    const MatchStart terminal = MatchStart(
      matchId: 'm1',
      difficulty: 'EASY',
      boneIds: <String>[],
      turn: 'PLAYER',
      playerScore: 4,
      botScore: 2,
      status: 'PLAYER_WIN',
      coinsGranted: 10,
    );
    final MatchStart held = matchStartAsInPlay(terminal);
    expect(held.status, 'IN_PLAY');
    expect(held.playerScore, 4);
    expect(held.botScore, 2);
    expect(held.boneIds, isEmpty);
    expect(held.coinsGranted, 10);
    expect(held.matchId, 'm1');
  });
}
