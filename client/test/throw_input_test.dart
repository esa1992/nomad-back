import 'package:client/input/throw_input.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _json({
  int schemaVersion = 1,
  double aimAngleRad = 1.0471975512,
  int holdMs = 640,
}) {
  return {
    'schemaVersion': schemaVersion,
    'yUp': true,
    'aimAngleRad': aimAngleRad,
    'holdMs': holdMs,
    'seed': 1,
    'tableId': 'alchiki-proto-v1',
  };
}

void main() {
  test('holdMs 50 clamps to 150', () {
    expect(ThrowInput.parse(_json(holdMs: 50)).holdMs, 150);
  });

  test('holdMs 5000 clamps to 1100', () {
    expect(ThrowInput.parse(_json(holdMs: 5000)).holdMs, 1100);
  });

  test('impulseFromHoldMs is monotonic on 150..1100', () {
    final low = ThrowInput.impulseFromHoldMs(150);
    final mid = ThrowInput.impulseFromHoldMs(640);
    final high = ThrowInput.impulseFromHoldMs(1100);
    expect(low, lessThan(mid));
    expect(mid, lessThan(high));
  });

  test('non-finite aimAngleRad throws', () {
    expect(
      () => ThrowInput.parse(_json(aimAngleRad: double.nan)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ThrowInput.parse(_json(aimAngleRad: double.infinity)),
      throwsA(isA<FormatException>()),
    );
  });

  test('schemaVersion must be 1', () {
    expect(
      () => ThrowInput.parse(_json(schemaVersion: 2)),
      throwsA(isA<FormatException>()),
    );
  });
}
