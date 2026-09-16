import 'package:client/game/alchiki_sandbox_game.dart';
import 'package:client/game/bone_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('origin is not fully outside the circle', () {
    expect(isFullyOutside(0, 0, 1.40, 0.055), isFalse);
  });

  test('(1.50, 0) is fully outside because 1.50 > 1.40 + 0.055', () {
    expect(isFullyOutside(1.50, 0, 1.40, 0.055), isTrue);
  });

  test('computeSettled is true at 1.2s even if bodies are awake', () {
    expect(computeSettled(false, 1.2), isTrue);
  });

  test('computeSettled is false at 1.19s if bodies are awake', () {
    expect(computeSettled(false, 1.19), isFalse);
  });

  test('computeSettled is true when all dynamic bodies sleep', () {
    expect(computeSettled(true, 0.1), isTrue);
  });
}
