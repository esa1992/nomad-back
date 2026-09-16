/// Fixed 1/60 accumulator. Never forwards the raw frame delta (D-11).
class PhysicsStepper {
  static const double step = 1 / 60;
  static const int maxCatchUp = 4;

  double acc = 0;

  void tick(double frameDt, void Function(double dt) stepWorld) {
    acc += frameDt;
    var n = 0;
    while (acc >= step && n < maxCatchUp) {
      stepWorld(step);
      acc -= step;
      n++;
    }
    if (n == maxCatchUp) {
      acc = 0;
    }
  }
}
