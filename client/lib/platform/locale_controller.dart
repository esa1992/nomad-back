import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeOverrideProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  static const prefKey = 'locale.override';

  @override
  Locale? build() {
    Future<void>.microtask(_hydrate);
    return null;
  }

  Future<void> _hydrate() async {
    try {
      final String? stored = await SharedPreferencesAsync().getString(prefKey);
      if (stored == 'en' || stored == 'ru') {
        state = Locale(stored as String);
      }
    } catch (_) {
      // Widget tests and missing plugin bindings stay on device locale.
    }
  }

  Future<void> setOverride(String languageCode) async {
    state = Locale(languageCode);
    try {
      await SharedPreferencesAsync().setString(prefKey, languageCode);
    } catch (_) {
      // Persist is best-effort; in-memory override still rebuilds copy.
    }
  }
}
