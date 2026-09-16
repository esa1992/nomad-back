import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _memory = null;

  SessionStore.memory() : _storage = null, _memory = <String, String>{};

  static const playerIdKey = 'playerId';
  static const refreshTokenKey = 'refreshToken';
  static const guestKey = 'guest';
  static const reconnectTokenKey = 'reconnectToken';
  static const reconnectMatchIdKey = 'reconnectMatchId';
  static const reconnectLocalSeatKey = 'reconnectLocalSeat';
  static const reconnectGameKey = 'reconnectGame';
  static const reconnectModeKey = 'reconnectMode';

  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;

  Future<String?> playerId() => _read(playerIdKey);

  Future<String?> refreshToken() => _read(refreshTokenKey);

  /// Defaults to guest when unset (mint-before-bind path).
  Future<bool> isGuest() async {
    final String? raw = await _read(guestKey);
    if (raw == null || raw.isEmpty) {
      return true;
    }
    return raw != 'false';
  }

  Future<void> persistGuest(bool guest) async {
    await _write(guestKey, guest ? 'true' : 'false');
  }

  Future<String?> reconnectToken() => _read(reconnectTokenKey);

  Future<String?> reconnectMatchId() => _read(reconnectMatchIdKey);

  Future<String?> reconnectLocalSeat() => _read(reconnectLocalSeatKey);

  Future<String?> reconnectGame() => _read(reconnectGameKey);

  Future<String?> reconnectMode() => _read(reconnectModeKey);

  Future<void> persist({
    required String playerId,
    required String refreshToken,
  }) async {
    await _write(playerIdKey, playerId);
    await _write(refreshTokenKey, refreshToken);
  }

  Future<void> persistReconnect({
    required String token,
    required String matchId,
    required String localSeat,
    String? game,
    String? mode,
  }) async {
    await _write(reconnectTokenKey, token);
    await _write(reconnectMatchIdKey, matchId);
    await _write(reconnectLocalSeatKey, localSeat);
    if (game != null && game.isNotEmpty) {
      await _write(reconnectGameKey, game);
    } else {
      await _delete(reconnectGameKey);
    }
    if (mode != null && mode.isNotEmpty) {
      await _write(reconnectModeKey, mode);
    } else {
      await _delete(reconnectModeKey);
    }
  }

  Future<void> clearReconnect() async {
    await _delete(reconnectTokenKey);
    await _delete(reconnectMatchIdKey);
    await _delete(reconnectLocalSeatKey);
    await _delete(reconnectGameKey);
    await _delete(reconnectModeKey);
  }

  Future<void> clear() async {
    if (_memory != null) {
      _memory.clear();
      return;
    }
    try {
      await _storage!.delete(key: playerIdKey);
      await _storage.delete(key: refreshTokenKey);
      await _storage.delete(key: guestKey);
      await _storage.delete(key: reconnectTokenKey);
      await _storage.delete(key: reconnectMatchIdKey);
      await _storage.delete(key: reconnectLocalSeatKey);
      await _storage.delete(key: reconnectGameKey);
      await _storage.delete(key: reconnectModeKey);
    } catch (_) {
      // Missing plugin binding in tests; in-memory path already handled.
    }
  }

  Future<String?> _read(String key) async {
    if (_memory != null) {
      return _memory[key];
    }
    try {
      return await _storage!.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    if (_memory != null) {
      _memory[key] = value;
      return;
    }
    try {
      await _storage!.write(key: key, value: value);
    } catch (_) {
      // Persist is best-effort so splash mint errors stay user-visible, not fatal.
    }
  }

  Future<void> _delete(String key) async {
    if (_memory != null) {
      _memory.remove(key);
      return;
    }
    try {
      await _storage!.delete(key: key);
    } catch (_) {
      // Best-effort; identity clear already swallows missing plugin binding.
    }
  }
}
