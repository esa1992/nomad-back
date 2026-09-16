import 'package:client/input/throw_input.dart';
import 'package:client/replay/throw_resolved.dart';

/// HUD scored reader. Only server ThrowResolved may cross this boundary.
class AuthorityScore {
  /// Returns file [ThrowResolved.pocketedCount], or null so the HUD stays `scored —`.
  /// There is no parameter for a Dart / Forge2D rest-pose count (D-10).
  static int? readPocketedCount(
    ThrowResolved? resolved, {
    ThrowInput? lastInput,
  }) {
    if (resolved == null) {
      return null;
    }
    if (!ThrowResolved.allowsReplay(resolved, lastInput)) {
      return null;
    }
    return resolved.pocketedCount;
  }

  /// Match HUD scored. Keyframes / sakaOut win over preview (CR-02, D-10).
  static int? displayedScore(
    ThrowResolved? resolved, {
    ThrowInput? lastInput,
  }) {
    if (resolved == null) {
      return null;
    }
    if (!ThrowResolved.allowsReplay(resolved, lastInput)) {
      return null;
    }
    return resolved.displayedScore();
  }
}
