import 'dart:async';
import 'dart:convert';

import 'package:client/input/throw_input.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef MatchSocketConnect = Future<MatchSocket> Function(Uri wsUrl);

/// One raw JSON WebSocket per private match (D-38). Ticket is the credential.
class MatchSocket {
  MatchSocket._(this._channel, this._incoming);

  final WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<Map<String, dynamic>> _incoming;
  final List<Map<String, dynamic>> _early = <Map<String, dynamic>>[];

  Stream<Map<String, dynamic>> get messages => _incoming.stream;

  /// Test hook so widget tests can skip a live WebSocket.
  @visibleForTesting
  static MatchSocketConnect? debugConnect;

  static Future<MatchSocket> connect(Uri wsUrl) async {
    final MatchSocketConnect? override = debugConnect;
    if (override != null) {
      return override(wsUrl);
    }
    try {
      final WebSocketChannel channel = WebSocketChannel.connect(wsUrl);
      await channel.ready;
      final MatchSocket socket = MatchSocket._(
        channel,
        StreamController<Map<String, dynamic>>.broadcast(),
      );
      socket._listen();
      return socket;
    } catch (error) {
      throw NomadApiException('WebSocket connect failed');
    }
  }

  /// In-memory socket for widget tests (no network).
  factory MatchSocket.stub({StreamController<Map<String, dynamic>>? incoming}) {
    return MatchSocket._(
      null,
      incoming ?? StreamController<Map<String, dynamic>>.broadcast(),
    );
  }

  void _emit(Map<String, dynamic> frame) {
    if (_incoming.isClosed) {
      return;
    }
    if (_incoming.hasListener) {
      _incoming.add(frame);
    } else {
      _early.add(frame);
    }
  }

  /// Call immediately after [messages.listen] so Countdown/StickState that
  /// arrived during handshake are not dropped.
  void flushBufferedFrames() {
    if (_early.isEmpty || _incoming.isClosed) {
      return;
    }
    final List<Map<String, dynamic>> pending =
        List<Map<String, dynamic>>.from(_early);
    _early.clear();
    for (final Map<String, dynamic> frame in pending) {
      _incoming.add(frame);
    }
  }

  void _listen() {
    final WebSocketChannel? channel = _channel;
    if (channel == null) {
      return;
    }
    _subscription = channel.stream.listen(
      (dynamic message) {
        try {
          final Object? decoded = message is String
              ? jsonDecode(message)
              : message;
          if (decoded is Map) {
            _emit(Map<String, dynamic>.from(decoded));
          }
        } catch (error) {
          if (!_incoming.isClosed) {
            _incoming.addError(NomadApiException('WebSocket frame failed'));
          }
        }
      },
      onError: (Object error) {
        if (!_incoming.isClosed) {
          _incoming.addError(NomadApiException('WebSocket error'));
        }
      },
      onDone: () {
        if (!_incoming.isClosed) {
          _incoming.close();
        }
      },
    );
  }

  void send(Map<String, Object?> frame) {
    _channel?.sink.add(jsonEncode(frame));
  }

  void sendThrow(ThrowInput input) {
    send(<String, Object?>{'type': 'ThrowInput', ...input.toJson()});
  }

  void ping() {
    send(<String, Object?>{
      'type': 'Ping',
      't': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    _early.clear();
    if (!_incoming.isClosed) {
      _incoming.close();
    }
    try {
      await _channel?.sink.close();
    } catch (_) {}
  }
}
