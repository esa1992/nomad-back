import 'package:client/game/physics_stepper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('33 ms and 16 ms frames produce world steps of 1 / 60 only', () {
    final steps33 = <double>[];
    PhysicsStepper().tick(0.033, steps33.add);

    final steps16 = <double>[];
    final stepper16 = PhysicsStepper();
    stepper16.tick(0.016, steps16.add);
    stepper16.tick(0.016, steps16.add);

    expect(steps33, isNotEmpty);
    expect(steps16, isNotEmpty);
    expect(steps33, everyElement(equals(1 / 60)));
    expect(steps16, everyElement(equals(1 / 60)));
  });

  test('catch-up cap is 4', () {
    final steps = <double>[];
    PhysicsStepper().tick(1.0, steps.add);
    expect(steps.length, lessThanOrEqualTo(4));
    expect(steps, everyElement(equals(1 / 60)));
  });
}
