import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final bindPromptStoreProvider = Provider<BindPromptStore>(
  (Ref ref) => BindPromptStore(),
);

/// Local UX gate for D-92 post-bot-win bind sheet (`bind.prompt.seen`).
class BindPromptStore {
  BindPromptStore({SharedPreferencesAsync? prefs}) : _prefs = prefs;

  static const String seenKey = 'bind.prompt.seen';

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
}
