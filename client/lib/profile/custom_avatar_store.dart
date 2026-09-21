import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client-only custom avatar (gallery). Server still keeps an allow-listed preset.
const String kCustomAvatarId = 'custom_local';

final customAvatarStoreProvider = Provider<CustomAvatarStore>(
  (Ref ref) => CustomAvatarStore(),
);

class CustomAvatarStore {
  static const String _activeKey = 'avatar.custom.active';
  static const String _fileName = 'custom_avatar.jpg';

  final ImagePicker _picker = ImagePicker();

  Future<bool> isActive() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_activeKey) != true) {
        return false;
      }
      final String? path = await filePath();
      return path != null && File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<String?> filePath() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String path = p.join(dir.path, _fileName);
      if (File(path).existsSync()) {
        return path;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Opens gallery, copies into app documents, marks custom as active.
  /// Returns saved absolute path, or null if cancelled / failed.
  Future<String?> pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) {
      return null;
    }
    final Directory dir = await getApplicationDocumentsDirectory();
    final String dest = p.join(dir.path, _fileName);
    await File(picked.path).copy(dest);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, true);
    return dest;
  }

  Future<void> setActive(bool active) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, active);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, false);
    final String? path = await filePath();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}
