import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final howToSeenStoreProvider = Provider<HowToSeenStore>(
  (Ref ref) => HowToSeenStore(),
);

class HowToSeenStore {
  HowToSeenStore({SharedPreferencesAsync? prefs}) : _prefs = prefs;

  static const String seenKey = 'howto.alchiki.seen';
  static const String stickPullSeenKey = 'howto.stickpull.seen';

  final SharedPreferencesAsync? _prefs;

  SharedPreferencesAsync get _store => _prefs ?? SharedPreferencesAsync();

  Future<bool> isSeen() async {
    try {
      return await _store.getBool(seenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      await _store.setBool(seenKey, true);
    } catch (_) {
      // Widget tests and missing plugin bindings still keep the in-memory path.
    }
  }

  Future<bool> isStickPullSeen() async {
    try {
      return await _store.getBool(stickPullSeenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markStickPullSeen() async {
    try {
      await _store.setBool(stickPullSeenKey, true);
    } catch (_) {
      // Widget tests and missing plugin bindings still keep the in-memory path.
    }
  }
}
