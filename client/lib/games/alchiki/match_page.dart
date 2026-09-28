import 'dart:async';

import 'package:client/games/alchiki/match_game.dart';
import 'package:client/games/alchiki/match_hud.dart';
import 'package:client/games/alchiki/pause_overlay.dart';
import 'package:client/input/throw_input.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/bind_prompt_store.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/platform/session/match_socket.dart';
import 'package:client/profile/bind_sheet.dart';
import 'package:client/replay/authority_score.dart';
import 'package:client/replay/throw_resolved.dart';
import 'package:client/schema/table_constants.dart';
import 'package:client/theme/steppe_widgets.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Seat + remapped HUD scores from snapshot vs SessionStore.playerId (D-30, D-33).
class PrivateSeatHud {
  const PrivateSeatHud({
    required this.localSeat,
    required this.youScore,
    required this.oppScore,
    required this.isPlayerTurn,
  });

  final String localSeat;
  final int youScore;
  final int oppScore;
  final bool isPlayerTurn;
}

PrivateSeatHud mapPrivateSeatHud({
  required String localPlayerId,
  required String hostId,
  required String joinerId,
  required int playerScore,
  required int botScore,
  required String turn,
}) {
  if (localPlayerId == joinerId) {
    return PrivateSeatHud(
      localSeat: 'joiner',
      youScore: botScore,
      oppScore: playerScore,
      isPlayerTurn: turn == 'JOINER',
    );
  }
  if (localPlayerId == hostId) {
    return PrivateSeatHud(
      localSeat: 'host',
      youScore: playerScore,
      oppScore: botScore,
      isPlayerTurn: turn == 'HOST',
    );
  }
  return const PrivateSeatHud(
    localSeat: '',
    youScore: 0,
    oppScore: 0,
    isPlayerTurn: false,
  );
}

/// Product match table. Flutter owns Hold Throw; Flame owns aim (D-20).
class AlchikiMatchPage extends ConsumerStatefulWidget {
  const AlchikiMatchPage({
    super.key,
    this.difficulty = 'EASY',
    this.game,
    this.mode,
    this.matchId,
  });

  final String difficulty;
  final AlchikiMatchGame? game;
  final String? mode;
  final String? matchId;

  @override
  AlchikiMatchPageState createState() => AlchikiMatchPageState();
}

class AlchikiMatchPageState extends ConsumerState<AlchikiMatchPage>
    with SingleTickerProviderStateMixin {
  static const Color _surround = Color(0xFF241810);
  static const Color _onDark = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);
  static const Color _destructive = Color(0xFFC43C2C);

  static const TextStyle _body = TextStyle(
    color: _onDark,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  late AlchikiMatchGame game;
  late final AnimationController _pulse;

  bool _charging = false;
  bool _throwing = false;
  bool _settled = false;
  bool _replaying = false;
  bool _paused = false;
  bool _leaveConfirm = false;
  bool _leaving = false;
  bool _tableAttached = false;
  bool _startError = false;
  bool _throwError = false;
  bool _turnTimeout = false;
  bool _forfeitSent = false;
  bool _botsTurn = false;
  bool _privateIsPlayerTurn = false;
  bool _awaitingOwnResolve = false;
  int _preview = 0;
  int? _scored;
  bool _sakaOut = false;
  int _youScore = 0;
  int _botScore = 0;
  int _oppScore = 0;
  String _localSeat = '';
  String? _opponentLabel;
  DateTime? _chargeStart;
  Timer? _meterTick;
  Timer? _clockTick;
  MatchStart? _match;
  ThrowInput? _lastInput;
  ThrowResolved? _resolved;
  ThrowResolved? _pendingBot;
  MatchSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  String? _activeMatchId;
  Timer? _rematchPoll;
  bool _rematchAcceptedLocal = false;
  bool _rematchError = false;
  int _rematchSeconds = 10;
  bool _enteringRematch = false;
  bool _showRejoin = false;
  bool _rejoinError = false;
  bool _retryingSocket = false;
  bool _consentedLeave = false;
  bool _graceExpiryHandled = false;
  bool _bindPromptScheduled = false;
  DateTime? _rejoinShownAt;
  DateTime? _opponentDroppedAt;
  int _opponentSecondsAtDrop = 30;
  int _rejoinSecondsAtShow = 30;
  bool _pauseBudgetGone = false;
  int? _frozenTurnRemainMs;
  int? _frozenMatchRemainMs;
  RejoinResult? _pendingRejoin;

  @override
  void initState() {
    super.initState();
    game = widget.game ??
        AlchikiMatchGame(difficulty: widget.difficulty, mode: widget.mode);
    game.onSettled = _onGameSettled;
    game.onReplayEnded = _onReplayEnded;
    _activeMatchId = widget.matchId;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pulse.addListener(() {
      if (mounted && _charging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.mode == 'private' ||
          widget.mode == 'casual' ||
          widget.mode == 'ranked') {
        unawaited(_bootPrivate());
      } else {
        unawaited(_startMatch());
      }
    });
  }

  @override
  void dispose() {
    _meterTick?.cancel();
    _clockTick?.cancel();
    _rematchPoll?.cancel();
    unawaited(_socketSub?.cancel());
    unawaited(_socket?.close());
    _pulse.dispose();
    super.dispose();
  }

  bool get _isPrivate => widget.mode == 'private';

  bool get _isCasual => widget.mode == 'casual';

  bool get _isRanked => widget.mode == 'ranked';

  /// Human PvP (private, casual QM, or Ranked) — WS/reconnect/HUD path.
  bool get _isHuman => _isPrivate || _isCasual || _isRanked;

  /// Casual/private Alchiki 30s; Ranked Alchiki 18s (D-101). Server SoT — display clamp only.
  int get _graceCap => _isRanked ? 18 : 30;

  String get _humanMode =>
      _isRanked ? 'ranked' : (_isCasual ? 'casual' : 'private');

  String get _privateMatchId => _activeMatchId ?? widget.matchId ?? '';

  bool get _isPlayerTurn {
    if (_isHuman) {
      return _privateIsPlayerTurn && !_botsTurn;
    }
    return !_botsTurn && (_match == null || _match!.turn == 'PLAYER');
  }

  bool get _isTerminal {
    final String status = _match?.status ?? 'IN_PLAY';
    return status == 'PLAYER_WIN' ||
        status == 'BOT_WIN' ||
        status == 'DRAW' ||
        status == 'HOST_WIN' ||
        status == 'JOINER_WIN';
  }

  String get _resultStatus {
    final String status = _match?.status ?? 'DRAW';
    if (!_isHuman) {
      return status;
    }
    if (status == 'HOST_WIN') {
      return _localSeat == 'host' ? 'PLAYER_WIN' : 'OPPONENT_WIN';
    }
    if (status == 'JOINER_WIN') {
      return _localSeat == 'joiner' ? 'PLAYER_WIN' : 'OPPONENT_WIN';
    }
    return status;
  }

  /// Victory SKU accent from server loadout; null keeps default cream heading.
  Color? _localVictoryAccent() {
    final Map<String, String> loadout =
        _match?.localLoadout ?? game.localLoadout;
    final String? sku = loadout['victory'];
    if (sku == null || sku.isEmpty || sku.toLowerCase().contains('default')) {
      return null;
    }
    return AlchikiMatchGame.victoryForLoadout(loadout);
  }

  int get _turnRemainMs {
    if (_frozenTurnRemainMs != null) {
      return _frozenTurnRemainMs!;
    }
    final int deadline = _match?.turnDeadlineEpochMs ?? 0;
    if (deadline <= 0) {
      return 1;
    }
    return deadline - DateTime.now().millisecondsSinceEpoch;
  }

  int get _matchRemainMs {
    if (_frozenMatchRemainMs != null) {
      return _frozenMatchRemainMs!;
    }
    final int deadline = _match?.matchDeadlineEpochMs ?? 0;
    if (deadline <= 0) {
      return 4 * 60 * 1000;
    }
    return deadline - DateTime.now().millisecondsSinceEpoch;
  }

  int get _rejoinSecondsLeft {
    final DateTime? shown = _rejoinShownAt;
    final int seed = _rejoinSecondsAtShow.clamp(0, _graceCap);
    if (shown == null) {
      return seed;
    }
    return (seed - DateTime.now().difference(shown).inSeconds).clamp(0, _graceCap);
  }

  int? get _opponentReconnectSeconds {
    final DateTime? droppedAt = _opponentDroppedAt;
    if (droppedAt == null) {
      return null;
    }
    final int left =
        (_opponentSecondsAtDrop -
                DateTime.now().difference(droppedAt).inSeconds)
            .clamp(0, _graceCap);
    return left;
  }

  bool get _inReconnectGrace =>
      _showRejoin || _opponentReconnectSeconds != null;

  bool get _turnExpired =>
      (_match?.turnDeadlineEpochMs ?? 0) > 0 && _turnRemainMs <= 0;

  bool get holdEnabled =>
      game.isLoaded &&
      !_throwing &&
      !_settled &&
      !_replaying &&
      _isPlayerTurn &&
      !      _paused &&
      !_turnExpired &&
      !_isTerminal &&
      !_inReconnectGrace;

  int get _rawHoldMs {
    final start = _chargeStart;
    if (start == null) {
      return 0;
    }
    return DateTime.now().difference(start).inMilliseconds;
  }

  /// Visual charge window is 2× the holdMs clamp so the meter is readable.
  static const int _chargeMsToMax = TableConstants.holdMsMax * 2;

  double get _chargeT {
    return (_rawHoldMs / _chargeMsToMax).clamp(0.0, 1.0);
  }

  int get _holdMsFromCharge {
    final double t = _chargeT;
    return (TableConstants.holdMsMin +
            t * (TableConstants.holdMsMax - TableConstants.holdMsMin))
        .round();
  }

  bool get _atMax => _rawHoldMs >= _chargeMsToMax;

  String _turnClockLabel(AppLocalizations l10n) {
    final int secs = (_turnRemainMs / 1000).ceil().clamp(0, 20);
    return l10n.turnClock('$secs');
  }

  String _matchClockLabel(AppLocalizations l10n) {
    final int total = (_matchRemainMs / 1000).ceil().clamp(0, 4 * 60);
    final int minutes = total ~/ 60;
    final int seconds = total % 60;
    return l10n.matchClock(minutes, seconds.toString().padLeft(2, '0'));
  }

  void _applyMatch(MatchStart next) {
    final int previousDeadline = _match?.turnDeadlineEpochMs ?? 0;
    _match = next;
    _pauseBudgetGone = next.pauseBudgetGone;
    if (!_isHuman) {
      _youScore = next.playerScore;
      _botScore = next.botScore;
    }
    if (next.turnDeadlineEpochMs != previousDeadline) {
      _forfeitSent = false;
      _turnTimeout = false;
    }
  }

  void _syncAimingMarker() {
    final bool waiting = _isHuman &&
        !_isPlayerTurn &&
        !_botsTurn &&
        !_replaying &&
        !_throwing &&
        !_isTerminal;
    game.showAimingMarker = waiting;
  }

  String _turnSeatOf(String turn) => turn == 'JOINER' ? 'joiner' : 'host';

  Future<void> _applyPrivateSnapshot(MatchStart next) async {
    final String? playerId = await ref.read(sessionStoreProvider).playerId();
    if (!mounted) {
      return;
    }
    final String? hostId = next.hostId;
    final String? joinerId = next.joinerId;
    if (playerId == null ||
        playerId.isEmpty ||
        hostId == null ||
        joinerId == null) {
      _privateIsPlayerTurn = false;
      _localSeat = '';
      _applyMatch(next);
      _syncAimingMarker();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final PrivateSeatHud seat = mapPrivateSeatHud(
      localPlayerId: playerId,
      hostId: hostId,
      joinerId: joinerId,
      playerScore: next.playerScore,
      botScore: next.botScore,
      turn: next.turn,
    );
    _localSeat = seat.localSeat;
    _privateIsPlayerTurn = seat.isPlayerTurn;
    _youScore = seat.youScore;
    _oppScore = seat.oppScore;
    _opponentLabel = seat.localSeat == 'host'
        ? (next.joinerLabel ?? '')
        : (next.hostLabel ?? '');
    _applyMatch(next);
    game.localSeat = seat.localSeat;
    game.turnSeat = _turnSeatOf(next.turn);
    _syncAimingMarker();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootPrivate() async {
    final SessionStore session = ref.read(sessionStoreProvider);
    final String? token = await session.reconnectToken();
    final String? storedMatchId = await session.reconnectMatchId();
    final String routeId = widget.matchId ?? '';
    if (token != null &&
        token.isNotEmpty &&
        storedMatchId != null &&
        storedMatchId.isNotEmpty &&
        storedMatchId == routeId) {
      final String? seat = await session.reconnectLocalSeat();
      int remaining = _graceCap;
      try {
        final MatchStart snap =
            await ref.read(nomadApiProvider).getMatch(storedMatchId);
        remaining = (snap.reconnectSecondsLeft ?? _graceCap).clamp(0, _graceCap);
        _pauseBudgetGone = snap.pauseBudgetGone;
        await _applyPrivateSnapshot(snap);
      } catch (_) {
        remaining = _graceCap;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _showRejoin = true;
        _rejoinError = false;
        _graceExpiryHandled = false;
        _rejoinShownAt = DateTime.now();
        _rejoinSecondsAtShow = remaining;
        _localSeat = seat ?? _localSeat;
        _activeMatchId = storedMatchId;
      });
      _ensureClockTick();
      return;
    }
    await _startPrivateMatch();
  }

  void _ensureClockTick() {
    _clockTick ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) {
        return;
      }
      if (_showRejoin && _rejoinSecondsLeft <= 0 && !_graceExpiryHandled) {
        _graceExpiryHandled = true;
        unawaited(_onGraceExpiredDropped());
      }
      setState(() {});
      if (!_isHuman) {
        _maybeAutoForfeit();
      }
    });
  }

  Future<void> _persistTicketReconnect(WsTicket ticket, String matchId) async {
    final String? token = ticket.reconnectToken;
    if (token == null || token.isEmpty || matchId.isEmpty) {
      return;
    }
    await ref.read(sessionStoreProvider).persistReconnect(
          token: token,
          matchId: matchId,
          localSeat: _localSeat,
          game: 'ALCHIKI',
          mode: widget.mode,
        );
  }

  void _listenSocket(MatchSocket socket) {
    _socketSub = socket.messages.listen(
      _onSocketFrame,
      onError: (_) {
        unawaited(_onSocketLost());
      },
      onDone: () {
        unawaited(_onSocketLost());
      },
    );
  }

  Future<void> _onSocketLost() async {
    if (!mounted ||
        _consentedLeave ||
        _enteringRematch ||
        _isTerminal ||
        _showRejoin ||
        _retryingSocket) {
      return;
    }
    _retryingSocket = true;
    try {
      await _reconnectPrivateSocket();
    } finally {
      _retryingSocket = false;
    }
  }

  Future<void> _reconnectPrivateSocket() async {
    for (int attempt = 0; attempt < 8; attempt++) {
      if (!mounted ||
          _consentedLeave ||
          _enteringRematch ||
          _isTerminal ||
          _showRejoin) {
        return;
      }
      final MatchSocket? lost = _socket;
      await _rejoinMatch();
      if (!mounted) {
        return;
      }
      if (_socket != null && !identical(_socket, lost) && !_rejoinError) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<void> _startPrivateMatch() async {
    final String matchId = _privateMatchId;
    if (matchId.isEmpty) {
      setState(() {
        _startError = true;
      });
      return;
    }
    setState(() {
      _startError = false;
    });
    try {
      final NomadApi api = ref.read(nomadApiProvider);
      final MatchStart snapshot = await api.getMatch(matchId);
      await _applyPrivateSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      if (widget.game == null) {
        game = AlchikiMatchGame(
          difficulty: snapshot.difficulty,
          mode: _humanMode,
          localSeat: _localSeat.isEmpty ? null : _localSeat,
          turnSeat: _turnSeatOf(snapshot.turn),
          localLoadout: snapshot.localLoadout,
          hostLoadout: snapshot.hostLoadout,
          joinerLoadout: snapshot.joinerLoadout,
        );
        game.onSettled = _onGameSettled;
        game.onReplayEnded = _onReplayEnded;
      } else {
        game.localSeat = _localSeat.isEmpty ? null : _localSeat;
        game.turnSeat = _turnSeatOf(snapshot.turn);
      }
      final WsTicket ticket = await api.wsTicket(matchId);
      await _persistTicketReconnect(ticket, matchId);
      final MatchSocket socket = await MatchSocket.connect(
        api.wsUrlForMatch(matchId: matchId, ticket: ticket.ticket),
      );
      if (!mounted) {
        await socket.close();
        return;
      }
      await _socketSub?.cancel();
      await _socket?.close();
      _socket = socket;
      _listenSocket(socket);
      _ensureClockTick();
      if (mounted) {
        setState(() {
          _tableAttached = true;
          _showRejoin = false;
          _syncAimingMarker();
        });
        _ensureRematchWatch();
        _applyPendingRejoinToGame();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startError = true;
      });
    }
  }

  Future<void> _rejoinMatch() async {
    setState(() {
      _rejoinError = false;
    });
    final SessionStore session = ref.read(sessionStoreProvider);
    final String matchId = await session.reconnectMatchId() ?? _privateMatchId;
    try {
      final String? token = await session.reconnectToken();
      final String seat = await session.reconnectLocalSeat() ?? _localSeat;
      if (token == null || token.isEmpty || matchId.isEmpty) {
        if (mounted) {
          setState(() {
            _rejoinError = true;
          });
        }
        return;
      }
      final NomadApi api = ref.read(nomadApiProvider);
      final RejoinResult result = await api.rejoin(matchId, token);
      if (result.reconnectToken.isNotEmpty) {
        await session.persistReconnect(
          token: result.reconnectToken,
          matchId: matchId,
          localSeat: seat,
          game: 'ALCHIKI',
          mode: widget.mode,
        );
      }
      _pendingRejoin = result;
      _activeMatchId = matchId;
      _localSeat = seat;
      await _applyPrivateSnapshot(result.match);
      if (!mounted) {
        return;
      }
      if (widget.game == null) {
        game = AlchikiMatchGame(
          difficulty: result.match.difficulty,
          mode: _humanMode,
          localSeat: _localSeat.isEmpty ? null : _localSeat,
          turnSeat: _turnSeatOf(result.match.turn),
          localLoadout: result.match.localLoadout,
          hostLoadout: result.match.hostLoadout,
          joinerLoadout: result.match.joinerLoadout,
        );
        game.onSettled = _onGameSettled;
        game.onReplayEnded = _onReplayEnded;
      } else {
        game.localSeat = _localSeat.isEmpty ? null : _localSeat;
        game.turnSeat = _turnSeatOf(result.match.turn);
      }
      await _attachPrivateSocket(api, matchId);
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyPendingRejoinToGame();
      });
    } on NomadApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.statusCode == 410) {
        await _onGraceExpiredDropped();
        return;
      }
      if (error.statusCode == 409) {
        await _resumeAfterRejoinConflict(matchId);
        return;
      }
      setState(() {
        _rejoinError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rejoinError = true;
      });
    }
  }

  Future<void> _resumeAfterRejoinConflict(String matchId) async {
    try {
      final NomadApi api = ref.read(nomadApiProvider);
      final MatchStart snap = await api.getMatch(matchId);
      if (!mounted) {
        return;
      }
      if (snap.status == 'HOST_WIN' ||
          snap.status == 'JOINER_WIN' ||
          snap.status == 'PLAYER_WIN' ||
          snap.status == 'BOT_WIN' ||
          snap.status == 'DRAW') {
        await _applyPrivateSnapshot(snap);
        return;
      }
      if (snap.status != 'IN_PLAY') {
        setState(() {
          _rejoinError = true;
        });
        return;
      }
      await _attachPrivateSocket(api, matchId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rejoinError = true;
      });
    }
  }

  Future<void> _attachPrivateSocket(NomadApi api, String matchId) async {
    final WsTicket ticket = await api.wsTicket(matchId);
    await _persistTicketReconnect(ticket, matchId);
    final MatchSocket socket = await MatchSocket.connect(
      api.wsUrlForMatch(matchId: matchId, ticket: ticket.ticket),
    );
    if (!mounted) {
      await socket.close();
      return;
    }
    await _socketSub?.cancel();
    await _socket?.close();
    _socket = socket;
    _listenSocket(socket);
    _ensureClockTick();
    setState(() {
      _showRejoin = false;
      _rejoinError = false;
      _tableAttached = true;
      _opponentDroppedAt = null;
      _frozenTurnRemainMs = null;
      _frozenMatchRemainMs = null;
    });
  }

  void _applyPendingRejoinToGame() {
    final RejoinResult? pending = _pendingRejoin;
    if (pending == null || !game.isLoaded) {
      return;
    }
    if (pending.playerThrow != null) {
      game.applyPlayerThrow(pending.playerThrow!);
    }
    for (final SakaPose pose in pending.sakaPoses) {
      game.applySakaPose(
        id: pose.id,
        x: pose.x,
        y: pose.y,
        angle: pose.angle,
      );
    }
    _pendingRejoin = null;
  }

  Future<void> _onGraceExpiredDropped() async {
    final SessionStore session = ref.read(sessionStoreProvider);
    await session.clearReconnect();
    if (!mounted) {
      return;
    }
    try {
      final MatchStart snap =
          await ref.read(nomadApiProvider).getMatch(_privateMatchId);
      await _applyPrivateSnapshot(snap);
    } catch (_) {
      if (!mounted) {
        return;
      }
      final String status = _localSeat == 'host' ? 'JOINER_WIN' : 'HOST_WIN';
      setState(() {
        _match = MatchStart(
          matchId: _privateMatchId,
          difficulty: 'NORMAL',
          boneIds: const <String>[],
          turn: 'HOST',
          status: status,
          mode: 'PRIVATE',
        );
      });
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _showRejoin = false;
      _rejoinError = false;
      _opponentDroppedAt = null;
      _frozenTurnRemainMs = null;
      _frozenMatchRemainMs = null;
    });
  }

  void _onSocketFrame(Map<String, dynamic> frame) {
    final String type = frame['type'] as String? ?? '';
    if (type == 'OpponentDropped') {
      final int seconds = (frame['secondsLeft'] as num?)?.toInt() ?? _graceCap;
      if (!mounted) {
        return;
      }
      setState(() {
        _opponentDroppedAt = DateTime.now();
        _opponentSecondsAtDrop = seconds.clamp(0, _graceCap);
        _frozenTurnRemainMs = _turnRemainMs;
        _frozenMatchRemainMs = _matchRemainMs;
      });
      return;
    }
    if (type == 'OpponentRejoined') {
      if (!mounted) {
        return;
      }
      setState(() {
        _opponentDroppedAt = null;
        _frozenTurnRemainMs = null;
        _frozenMatchRemainMs = null;
      });
      return;
    }
    if (type == 'ThrowResolved') {
      unawaited(_onThrowResolvedFrame(frame));
      return;
    }
    if (type == 'RematchReady') {
      final String? newId = frame['matchId']?.toString();
      if (newId != null && newId.isNotEmpty) {
        unawaited(_enterNewPrivateMatch(newId));
      }
      return;
    }
    if (type == 'MatchSettled' && frame['match'] is Map) {
      unawaited(() async {
        final NomadApi api = ref.read(nomadApiProvider);
        MatchStart settled = api.snapshotFromMap(_privateMatchId, frame['match']);
        final String? playerId = await ref.read(sessionStoreProvider).playerId();
        settled = api.applyGrantsMap(settled, frame['grants'], playerId);
        await _applyPrivateSnapshot(settled);
        if (!mounted) {
          return;
        }
        setState(() {
          _opponentDroppedAt = null;
          _frozenTurnRemainMs = null;
          _frozenMatchRemainMs = null;
          _showRejoin = false;
        });
        _ensureRematchWatch();
      }());
    }
  }

  Future<void> _onThrowResolvedFrame(Map<String, dynamic> frame) async {
    final NomadApi api = ref.read(nomadApiProvider);
    final String matchId = _privateMatchId;
    MatchStart? next;
    if (frame['match'] is Map) {
      next = api.snapshotFromMap(matchId, frame['match']);
      await _applyPrivateSnapshot(next);
    }
    if (!mounted) {
      return;
    }
    final Map<String, dynamic> throwMap = frame['playerThrow'] is Map
        ? Map<String, dynamic>.from(frame['playerThrow'] as Map)
        : <String, dynamic>{};
    if (frame['input'] is Map && throwMap['input'] is! Map) {
      throwMap['input'] = frame['input'];
    }
    throwMap.putIfAbsent('schemaVersion', () => 1);
    throwMap.putIfAbsent('yUp', () => true);
    ThrowResolved? resolved;
    try {
      resolved = ThrowResolved.parseMap(Map<String, Object?>.from(throwMap));
    } catch (_) {
      resolved = null;
    }
    if (resolved == null) {
      return;
    }
    final ThrowResolved parsed = resolved;
    final bool ownThrow = _awaitingOwnResolve;
    _awaitingOwnResolve = false;
    setState(() {
      _resolved = parsed;
      _scored = AuthorityScore.displayedScore(
        parsed,
        lastInput: ownThrow ? _lastInput : parsed.input,
      );
      _sakaOut = parsed.sakaOut;
      _throwError = false;
      if (ownThrow) {
        _replaying = parsed.keyframes.isNotEmpty;
        _throwing = false;
      }
    });
    if (ownThrow) {
      if (parsed.keyframes.isNotEmpty) {
        game.startReplay(parsed);
      }
      _syncAimingMarker();
      return;
    }
    game.showAimingMarker = false;
    unawaited(playBotTurn(parsed.input, parsed));
  }

  Future<void> _startMatch() async {
    setState(() {
      _startError = false;
    });
    try {
      final MatchStart started = await ref
          .read(nomadApiProvider)
          .startMatch(difficulty: widget.difficulty);
      if (!mounted) {
        return;
      }
      game = AlchikiMatchGame(
        difficulty: started.difficulty,
        mode: widget.mode,
        localLoadout: started.localLoadout,
      );
      game.onSettled = _onGameSettled;
      game.onReplayEnded = _onReplayEnded;
      setState(() {
        _applyMatch(started);
        _startError = false;
      });
      _ensureClockTick();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _tableAttached = true;
          });
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startError = true;
      });
    }
  }

  void _onGameSettled() {
    if (!mounted) {
      return;
    }
    setState(() {
      _throwing = false;
      _settled = true;
      _preview = game.previewCount;
      _sakaOut = game.sakaOut;
    });
  }

  void _onReplayEnded() {
    if (!mounted) {
      return;
    }
    final ThrowResolved? bot = _pendingBot;
    if (bot != null) {
      _pendingBot = null;
      unawaited(playBotTurn(bot.input, bot));
      return;
    }
    if (_botsTurn) {
      game.startTurn();
      game.resetSakaToRim();
    }
    setState(() {
      _botsTurn = false;
      _replaying = false;
      _throwing = false;
      _settled = false;
      _charging = false;
      _sakaOut = _resolved?.sakaOut ?? false;
      _syncAimingMarker();
    });
  }

  /// Visible bot/opponent turn: aim + hold from server input, then keyframes (D-21, D-34).
  Future<void> playBotTurn(ThrowInput input, ThrowResolved resolved) async {
    if (!mounted) {
      return;
    }
    game.showAimingMarker = false;
    setState(() {
      _botsTurn = true;
      _charging = true;
      _chargeStart = DateTime.now().subtract(
        Duration(milliseconds: input.holdMs),
      );
      _replaying = false;
      _throwing = false;
      _resolved = resolved;
    });
    game.aim.aimAngleRad = input.aimAngleRad;
    game.aimLocked = true;
    _meterTick?.cancel();
    final int holdMs = input.holdMs.clamp(80, 400);
    _meterTick = Timer(Duration(milliseconds: holdMs), () {
      if (!mounted) {
        return;
      }
      _beginBotReplay(resolved);
    });
  }

  void _beginBotReplay(ThrowResolved resolved) {
    setState(() {
      _charging = false;
      _chargeStart = null;
      _replaying = resolved.keyframes.isNotEmpty;
    });
    if (game.isLoaded && resolved.keyframes.isNotEmpty) {
      game.startReplay(resolved);
      return;
    }
    if (game.isLoaded) {
      game.startTurn();
      game.resetSakaToRim();
    }
    if (resolved.keyframes.isEmpty && mounted) {
      setState(() {
        _botsTurn = false;
        _replaying = false;
      });
    }
  }

  void _startCharge() {
    if (!holdEnabled) {
      return;
    }
    _meterTick?.cancel();
    setState(() {
      _charging = true;
      _chargeStart = DateTime.now();
    });
    game.aimLocked = true;
    _pulse.repeat(reverse: true);
    _meterTick = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted && _charging) {
        setState(() {});
      }
    });
  }

  Future<void> _releaseCharge() async {
    if (!_charging) {
      return;
    }
    _meterTick?.cancel();
    _pulse
      ..stop()
      ..value = 0;
    final holdMs = _holdMsFromCharge;
    final input = ThrowInput(
      schemaVersion: 1,
      yUp: true,
      aimAngleRad: game.aim.aimAngleRad,
      holdMs: holdMs,
      seed: 1,
      tableId: TableConstants.matchTableId,
    );
    setState(() {
      _charging = false;
      _throwing = true;
      _settled = false;
      _throwError = false;
      _chargeStart = null;
      _lastInput = input;
      _scored = null;
    });
    if (_isHuman) {
      game.throwSaka(input);
      await _sendPrivateThrow(input);
    } else {
      // Bot matches: skip local physics — server keyframes are the only flight.
      // Local throwSaka + startReplay caused a double toss (wild then normal).
      game.aimLocked = true;
      await _submitThrow(input);
    }
  }

  Future<void> _sendPrivateThrow(ThrowInput input) async {
    final MatchSocket? socket = _socket;
    if (socket == null) {
      setState(() {
        _throwError = true;
        _throwing = false;
      });
      return;
    }
    try {
      _awaitingOwnResolve = true;
      socket.sendThrow(input);
    } catch (_) {
      _awaitingOwnResolve = false;
      if (!mounted) {
        return;
      }
      setState(() {
        _throwError = true;
        _throwing = false;
      });
    }
  }

  void _maybeAutoForfeit() {
    if (_isHuman ||
        _forfeitSent ||
        _paused ||
        _throwing ||
        _isTerminal ||
        !_isPlayerTurn ||
        !_turnExpired) {
      return;
    }
    _forfeitSent = true;
    unawaited(_submitThrow(null, forfeit: true));
  }

  MatchStart _matchFromThrow(MatchStart current, ThrowSubmitResult result) {
    return MatchStart(
      matchId: current.matchId,
      difficulty: current.difficulty,
      boneIds: result.bonesLeft,
      turn: result.turn,
      playerScore: result.playerScore,
      botScore: result.botScore,
      status: result.status,
      playerTurns: result.playerTurns,
      botTurns: current.botTurns,
      turnDeadlineEpochMs: result.turnDeadlineEpochMs,
      matchDeadlineEpochMs: result.matchDeadlineEpochMs,
      hardCapEpochMs: result.hardCapEpochMs,
      mode: current.mode,
      hostId: current.hostId,
      joinerId: current.joinerId,
      hostLabel: current.hostLabel,
      joinerLabel: current.joinerLabel,
      reconnectSecondsLeft: current.reconnectSecondsLeft,
      pauseBudgetGone: current.pauseBudgetGone,
      coinsGranted: current.coinsGranted,
      gemsGranted: current.gemsGranted,
      localLoadout: current.localLoadout,
      hostLoadout: current.hostLoadout,
      joinerLoadout: current.joinerLoadout,
    );
  }

  Future<void> _submitThrow(ThrowInput? input, {bool forfeit = false}) async {
    final MatchStart? match = _match;
    if (match == null) {
      return;
    }
    try {
      final ThrowSubmitResult result = await ref
          .read(nomadApiProvider)
          .submitThrow(match.matchId, input);
      if (!mounted) {
        return;
      }
      final ThrowResolved resolved = result.playerThrow;
      final ThrowResolved? botThrow = result.botThrow;
      setState(() {
        _resolved = resolved;
        _pendingBot = botThrow;
        _applyMatch(_matchFromThrow(match, result));
        _youScore = result.playerScore;
        _botScore = result.botScore;
        _scored = AuthorityScore.displayedScore(resolved, lastInput: input);
        _sakaOut = resolved.sakaOut;
        _throwError = false;
        if (forfeit || resolved.keyframes.isEmpty) {
          _turnTimeout = true;
          _throwing = false;
          _replaying = false;
        } else {
          _replaying = true;
        }
      });
      if (!forfeit && resolved.keyframes.isNotEmpty) {
        game.startReplay(resolved);
      } else if (botThrow != null) {
        _pendingBot = null;
        unawaited(playBotTurn(botThrow.input, botThrow));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _throwError = true;
        _throwing = false;
        if (forfeit) {
          _forfeitSent = false;
        }
      });
    }
  }

  Future<void> _retryThrow() async {
    final ThrowInput? input = _lastInput;
    if (input == null) {
      return;
    }
    setState(() {
      _throwError = false;
      _throwing = true;
    });
    if (_isHuman) {
      game.throwSaka(input);
      await _sendPrivateThrow(input);
      return;
    }
    await _submitThrow(input);
  }

  Future<void> _leaveMatch() async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    _consentedLeave = true;
    // Leave UI immediately — do not wait on Render/API (user priority).
    unawaited(ref.read(sessionStoreProvider).clearReconnect());
    final MatchStart? match = _match;
    final String? matchId = match?.matchId;
    if (mounted) {
      setState(() {
        _leaveConfirm = false;
        _paused = false;
      });
    }
    _goCatalog();
    if (matchId == null || matchId.isEmpty) {
      return;
    }
    try {
      await ref.read(nomadApiProvider).leaveMatch(matchId);
    } catch (_) {
      // Best-effort; player already left the table UI.
    }
  }

  void _ensureRematchWatch() {
    if (!_isPrivate || !_isTerminal || _rematchPoll != null || _enteringRematch) {
      return;
    }
    _rematchSeconds = 10;
    _rematchPoll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_tickRematchPoll());
    });
    unawaited(_tickRematchPoll());
  }

  Future<void> _tickRematchPoll() async {
    if (!_isPrivate || !_isTerminal || _enteringRematch) {
      return;
    }
    try {
      final RematchPoll poll = await ref
          .read(nomadApiProvider)
          .getRematch(_privateMatchId);
      if (!mounted) {
        return;
      }
      if (poll.matchId != null && poll.matchId!.isNotEmpty) {
        await _enterNewPrivateMatch(poll.matchId!);
        return;
      }
      setState(() {
        _rematchSeconds = poll.rematchSeconds;
      });
      if (poll.expired) {
        _rematchPoll?.cancel();
        _rematchPoll = null;
        _goCatalog();
      }
    } catch (_) {
      // Transient poll errors stay on the overlay until Retry / Back.
    }
  }

  Future<void> _playAgain() async {
    _rematchPoll?.cancel();
    _rematchPoll = null;
    setState(() {
      _tableAttached = false;
      _match = null;
      _youScore = 0;
      _botScore = 0;
      _preview = 0;
      _scored = null;
      _sakaOut = false;
      _paused = false;
      _rematchError = false;
    });
    if (!mounted) {
      return;
    }
    game = AlchikiMatchGame(difficulty: widget.difficulty);
    game.onSettled = _onGameSettled;
    game.onReplayEnded = _onReplayEnded;
    await _startMatch();
  }

  /// Ranked result primary: enqueue a fresh Ranked search (D-99 — no rematch).
  Future<void> _findRankedMatch() async {
    try {
      await ref.read(nomadApiProvider).enqueueRanked(game: 'ALCHIKI');
      if (!mounted) {
        return;
      }
      context.go('/matchmaking?mode=ranked');
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      context.go('/matchmaking?mode=ranked');
    }
  }

  /// Casual Play again leaves the result overlay for /match/rematch-wait (D-73).
  /// Waiting page POSTs rematch accept and polls until dual-accept or timeout.
  Future<void> _openCasualRematchWait() async {
    final String matchId = _privateMatchId;
    if (matchId.isEmpty) {
      return;
    }
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final String encodedMatch = Uri.encodeQueryComponent(matchId);
    final String encodedOpponent = Uri.encodeQueryComponent(
      _opponentLabel ?? '',
    );
    router.go(
      '/match/rematch-wait?matchId=$encodedMatch&opponent=$encodedOpponent',
    );
  }

  Future<void> _acceptRematch() async {
    setState(() {
      _rematchAcceptedLocal = true;
      _rematchError = false;
    });
    try {
      final RematchAccept result = await ref
          .read(nomadApiProvider)
          .rematch(_privateMatchId, accept: true);
      if (!mounted) {
        return;
      }
      if (result.matchId != null && result.matchId!.isNotEmpty) {
        await _enterNewPrivateMatch(result.matchId!);
        return;
      }
      setState(() {
        _rematchSeconds = result.rematchSeconds;
      });
      _ensureRematchWatch();
      await _tickRematchPoll();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rematchError = true;
        _rematchAcceptedLocal = false;
      });
    }
  }

  Future<void> _rejectRematchAndCatalog() async {
    _rematchPoll?.cancel();
    _rematchPoll = null;
    await ref.read(sessionStoreProvider).clearReconnect();
    if (_isPrivate && _isTerminal) {
      try {
        await ref.read(nomadApiProvider).rematch(_privateMatchId, accept: false);
      } catch (_) {}
    }
    _goCatalog();
  }

  Future<void> _goShopFromResult() async {
    if (_isPrivate && _isTerminal) {
      _rematchPoll?.cancel();
      _rematchPoll = null;
      await ref.read(sessionStoreProvider).clearReconnect();
      try {
        await ref.read(nomadApiProvider).rematch(_privateMatchId, accept: false);
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    // UI-SPEC: pop to catalog then push /shop (ends rematch window). Catalog remount fetches wallet (D-48).
    router.go('/');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.push('/shop');
    });
  }

  Future<void> _enterNewPrivateMatch(String newId) async {
    if (_enteringRematch || newId.isEmpty) {
      return;
    }
    _enteringRematch = true;
    _rematchPoll?.cancel();
    _rematchPoll = null;
    final StreamSubscription<Map<String, dynamic>>? previousSub = _socketSub;
    _socketSub = null;
    final MatchSocket? previous = _socket;
    _socket = null;
    unawaited(previousSub?.cancel());
    unawaited(previous?.close());
    _activeMatchId = newId;
    setState(() {
      _match = null;
      _youScore = 0;
      _botScore = 0;
      _oppScore = 0;
      _preview = 0;
      _scored = null;
      _sakaOut = false;
      _paused = false;
      _rematchAcceptedLocal = false;
      _rematchError = false;
      _rematchSeconds = 10;
      _startError = false;
    });
    if (!mounted) {
      _enteringRematch = false;
      return;
    }
    game = AlchikiMatchGame(
      difficulty: 'NORMAL',
      mode: 'private',
    );
    game.onSettled = _onGameSettled;
    game.onReplayEnded = _onReplayEnded;
    try {
      await _startPrivateMatch();
    } finally {
      _enteringRematch = false;
    }
  }

  void _goCatalog() {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/');
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _openHowToFromPause() {
    final String difficulty = widget.difficulty;
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/howto/alchiki?difficulty=$difficulty&fromPause=1');
    }
  }

  /// D-92: after first Alchiki bot win, offer dismissible bind sheet once.
  void _scheduleBindPromptIfNeeded() {
    if (_bindPromptScheduled || _showRejoin || !_isTerminal || _isHuman) {
      return;
    }
    if ((_match?.status ?? '') != 'PLAYER_WIN') {
      return;
    }
    _bindPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_offerBindPrompt());
    });
  }

  Future<void> _offerBindPrompt() async {
    if (!mounted) {
      return;
    }
    final SessionStore session = ref.read(sessionStoreProvider);
    final BindPromptStore store = ref.read(bindPromptStoreProvider);
    final bool guest = await session.isGuest();
    final bool seen = await store.isSeen();
    if (!shouldOfferBindAfterBotWin(
      isBotMode: !_isHuman,
      isPlayerWin: (_match?.status ?? '') == 'PLAYER_WIN',
      isGuest: guest,
      promptSeen: seen,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    await showBindSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final pulseOpacity = _charging && _atMax ? 0.8 + 0.2 * _pulse.value : 1.0;
    final holdOpacity = !holdEnabled ? 0.4 : pulseOpacity;
    final String difficulty = widget.difficulty;
    _scheduleBindPromptIfNeeded();

    return Scaffold(
      backgroundColor: _surround,
      body: Stack(
        children: [
          if (_tableAttached)
            IgnorePointer(
              ignoring: _isTerminal || _paused,
              child: GameWidget.controlled(
                key: ValueKey<String>(_privateMatchId),
                gameFactory: () => game,
              ),
            ),
          if (!_tableAttached && !_startError && !_showRejoin)
            SteppeLoading(label: l10n.startingMatch),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PauseChip(
                    label: l10n.pause,
                    enabled: !_charging && !_leaving,
                    onTap: () {
                      setState(() {
                        _paused = true;
                        _leaveConfirm = false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MatchHud(
                      l10n: l10n,
                      youScore: _youScore,
                      botScore: _isHuman ? _oppScore : _botScore,
                      difficulty: _isHuman ? 'NORMAL' : difficulty,
                      preview: _preview,
                      scored: _scored,
                      sakaOut: _sakaOut,
                      turnClockLabel: _turnClockLabel(l10n),
                      matchClockLabel: _matchClockLabel(l10n),
                      isPlayerTurn: _isPlayerTurn,
                      showTimeout: _turnTimeout,
                      isPrivate: _isHuman,
                      opponentLabel: _opponentLabel,
                      reconnectSeconds: _opponentReconnectSeconds,
                      pauseBudgetGone: _pauseBudgetGone,
                      graceCap: _graceCap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_startError && !_showRejoin)
            SafeArea(
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ErrorBanner(
                    message: l10n.errorMatchStart,
                    retryLabel: l10n.retry,
                    onRetry: () => unawaited(
                      _isHuman ? _startPrivateMatch() : _startMatch(),
                    ),
                    secondaryLabel: l10n.backToCatalog,
                    onSecondary: _goCatalog,
                  ),
                ),
              ),
            ),
          if (_throwError)
            SafeArea(
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ErrorBanner(
                    message: l10n.errorThrow,
                    retryLabel: l10n.retry,
                    onRetry: () => unawaited(_retryThrow()),
                  ),
                ),
              ),
            ),
          if (_showRejoin)
            RejoinOverlay(
              l10n: l10n,
              secondsLeft: _rejoinSecondsLeft,
              onRejoin: () => unawaited(_rejoinMatch()),
              error: _rejoinError,
            ),
          if (_isTerminal && !_showRejoin)
            ResultOverlay(
              l10n: l10n,
              status: _match?.status ?? _resultStatus,
              localSeat: _localSeat.isEmpty ? null : _localSeat,
              youScore: _youScore,
              botScore: _isHuman ? _oppScore : _botScore,
              opponentLabel: _isHuman ? _opponentLabel : null,
              isPrivate: _isPrivate,
              isRanked: _isRanked,
              rematchSeconds: _isPrivate ? _rematchSeconds : null,
              rematchAcceptedLocal: _rematchAcceptedLocal,
              rematchError: _rematchError,
              coinsGranted: _match?.coinsGranted ?? 0,
              gemsGranted: _match?.gemsGranted ?? 0,
              victoryAccent: _localVictoryAccent(),
              // Bot: one-tap Play again. Casual: Play again → rematch-wait (D-70, D-73).
              // Private: Again? dual-accept. Ranked: Find Ranked match only (D-99).
              onPlayAgain: _isRanked || _isPrivate
                  ? null
                  : _isCasual
                      ? () => unawaited(_openCasualRematchWait())
                      : () => unawaited(_playAgain()),
              onFindRankedMatch:
                  _isRanked ? () => unawaited(_findRankedMatch()) : null,
              onRematchAccept: _isPrivate ? () => unawaited(_acceptRematch()) : null,
              onRematchRetry: _isPrivate ? () => unawaited(_acceptRematch()) : null,
              onBackToCatalog: _isPrivate
                  ? () => unawaited(_rejectRematchAndCatalog())
                  : _goCatalog,
              onShop: () => unawaited(_goShopFromResult()),
            ),
          if (_paused && !_leaveConfirm && !_isTerminal && !_showRejoin)
            PauseOverlay(
              l10n: l10n,
              onResume: () {
                setState(() {
                  _paused = false;
                });
              },
              onHowToPlay: _openHowToFromPause,
              onLeave: () {
                setState(() {
                  _leaveConfirm = true;
                });
              },
            ),
          if (_leaveConfirm && !_isTerminal)
            LeaveConfirm(
              l10n: l10n,
              body: _isRanked
                  ? l10n.leaveRankedBody
                  : (_isHuman ? l10n.leaveBodyPrivate : null),
              busy: _leaving,
              onStay: _leaving
                  ? null
                  : () {
                      setState(() {
                        _leaveConfirm = false;
                      });
                    },
              onLeaveMatch: _leaving ? null : () => unawaited(_leaveMatch()),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_charging) ...[
                      _PowerMeter(fill: _chargeT),
                      const SizedBox(height: 24),
                    ],
                    if (_isPlayerTurn && !_isTerminal && !_inReconnectGrace)
                      Opacity(
                        opacity: holdOpacity,
                        child: Listener(
                          onPointerDown: (_) => _startCharge(),
                          onPointerUp: (_) => unawaited(_releaseCharge()),
                          onPointerCancel: (_) => unawaited(_releaseCharge()),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 192,
                              minHeight: 48,
                            ),
                            child: Material(
                              color: _accent,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                child: SizedBox(
                                  height: 24,
                                  child: Center(
                                    child: Text(
                                      l10n.holdThrow,
                                      style: const TextStyle(
                                        color: _onAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseChip extends StatelessWidget {
  const _PauseChip({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: AlchikiMatchPageState._surround.withValues(alpha: 0.88),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: AlchikiMatchPageState._onDark.withValues(alpha: 0.45),
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Tooltip(
              message: label,
              child: Icon(
                Icons.pause,
                color: AlchikiMatchPageState._onDark,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableButton extends StatelessWidget {
  const _TableButton({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AlchikiMatchPageState._surround.withValues(alpha: 0.88),
        border: Border.all(color: AlchikiMatchPageState._destructive),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AlchikiMatchPageState._body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _TableButton(
              label: retryLabel,
              fill: AlchikiMatchPageState._accent,
              textColor: AlchikiMatchPageState._onAccent,
              enabled: true,
              onTap: onRetry,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 16),
              _TableButton(
                label: secondaryLabel!,
                fill: AlchikiMatchPageState._surround,
                textColor: AlchikiMatchPageState._onDark,
                enabled: true,
                onTap: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PowerMeter extends StatelessWidget {
  const _PowerMeter({required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) {
    final double t = fill.clamp(0.0, 1.0);
    final int pct = (t * 100).round();
    final Color tip = Color.lerp(
      const Color(0xFFF0B429),
      const Color(0xFFE85D04),
      t,
    )!;
    final List<Color> fillColors = t > 0.72
        ? <Color>[const Color(0xFFF5D76E), tip, const Color(0xFFD00000)]
        : <Color>[const Color(0xFFF5D76E), tip];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$pct%',
              style: TextStyle(
                color: tip,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: const [
                  Shadow(color: Color(0xCC000000), blurRadius: 6),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1A120C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF5A4030), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: t <= 0 ? 0.001 : t,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: fillColors),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final double _ in const [0.25, 0.5, 0.75])
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                width: 1.5,
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                          ),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
