/// Stick Pull WS frame helpers (TapInput / StickState / Countdown / TapResolved).
class StickPullWs {
  StickPullWs._();

  static Map<String, Object?> tapInput({required int clientSeq}) {
    return <String, Object?>{
      'type': 'TapInput',
      'schemaVersion': 1,
      'clientSeq': clientSeq,
    };
  }

  static Map<String, Object?> pause() => <String, Object?>{'type': 'Pause'};

  static Map<String, Object?> resume() => <String, Object?>{'type': 'Resume'};

  static String? typeOf(Map<String, dynamic> frame) {
    final Object? type = frame['type'];
    return type is String ? type : null;
  }

  static String? countdownValue(Map<String, dynamic> frame) {
    final Object? value = frame['value'] ?? frame['label'];
    return value?.toString();
  }

  static double? markerOf(Map<String, dynamic> frame) {
    final Object? marker = frame['marker'] ?? frame['position'];
    if (marker is num) {
      return marker.toDouble();
    }
    return null;
  }

  static double staminaHost(Map<String, dynamic> frame) {
    final Object? v = frame['staminaHost'];
    return v is num ? v.toDouble().clamp(0.0, 1.0) : 1.0;
  }

  static double staminaJoiner(Map<String, dynamic> frame) {
    final Object? v = frame['staminaJoiner'];
    return v is num ? v.toDouble().clamp(0.0, 1.0) : 1.0;
  }

  static int clockSecondsLeft(Map<String, dynamic> frame) {
    final Object? v = frame['clockSecondsLeft'];
    return v is num ? v.toInt() : 0;
  }

  static bool accepted(Map<String, dynamic> frame) {
    return frame['accepted'] == true;
  }

  static String? phaseOf(Map<String, dynamic> frame) {
    final Object? phase = frame['phase'];
    return phase is String ? phase : null;
  }

  static Map<String, dynamic>? matchOf(Map<String, dynamic> frame) {
    final Object? match = frame['match'];
    if (match is Map) {
      return Map<String, dynamic>.from(match);
    }
    return null;
  }
}
