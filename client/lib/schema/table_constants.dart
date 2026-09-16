/// Shared table / physics constants. Meters, Y-up. Must match Java (D-09).
class TableConstants {
  TableConstants._();

  static const double circleRadiusM = 1.40;
  static const double sakaRadiusM = 0.07;
  static const double boneRadiusM = 0.055;
  static const double sakaMassKg = 0.12;
  static const double boneMassKg = 0.055;
  static const double friction = 0.30;
  static const double restitution = 0.38;
  static const double linearDamping = 1.15;
  static const double angularDamping = 0.85;
  static const double impulseMinNs = 0.06;
  static const double impulseMaxNs = 0.38;
  static const int physicsHz = 60;
  static const int keyframeHz = 20;
  static const double settleTimeoutS = 1.2;
  static const int boneCount = 6;

  static const int holdMsMin = 150;
  static const int holdMsMax = 1100;
  static const String tableId = 'alchiki-proto-v1';
  static const String matchTableId = 'alchiki-match-v1';
}
