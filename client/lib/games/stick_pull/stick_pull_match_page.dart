import 'dart:async';

import 'package:client/catalog/catalog_models.dart';
import 'package:client/games/alchiki/pause_overlay.dart';
import 'package:client/games/stick_pull/stick_pull_game.dart';
import 'package:client/games/stick_pull/stick_pull_hud.dart';
import 'package:client/games/stick_pull/stick_pull_ws.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/platform/session/match_socket.dart';
import 'package:client/theme/steppe_backdrop.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:client/theme/steppe_widgets.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Stick Pull match — bot or human (private/casual) with 8s reconnect (SESS-04).
class StickPullMatchPage extends ConsumerStatefulWidget {
  const StickPullMatchPage({
    super.key,
    this.difficulty = 'EASY',
    this.matchId,
    this.mode,
  });

  final String difficulty;
  final String? matchId;
  final String? mode;

  @override
  ConsumerState<StickPullMatchPage> createState() => _StickPullMatchPageState();
}

class _StickPullMatchPageState extends ConsumerState<StickPullMatchPage> {
  static const Color _wood = SteppeOps.voidBg;
  static const Color _earth = Color(0xFF5C3C22);
  static const Color _onDark = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);
  static const Color _staminaTrack = Color(0xFF3A2A1C);

  late StickPullGame _game;
  MatchSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _sub;
  MatchStart? _match;
  String? _activeMatchId;
  String _localSeat = '';
  String _opponentLabel = '';

  String _phase = 'COUNTDOWN';
  String? _countdown;
  double _staminaYou = 1;
  double _staminaOpp = 1;
  double _prevLocalStamina = 1;
  int _clockSeconds = 60;
  int _clientSeq = 0;
  bool _startError = false;
  bool _paused = false;
  bool _leaveConfirm = false;
  bool _leaving = false;
  bool _falseStart = false;
  Timer? _falseStartTimer;
  Timer? _uiTick;
  Timer? _countdownClearTimer;
  Timer? _countdownWatch;
  Timer? _countdownFallback;
  String? _fallbackDigit;
  bool _countdownFinished = false;
  bool _countdownReconnectAttempted = false;
  bool _botReconnectInFlight = false;
  int _botReconnects = 0;
  bool _goHapticDone = false;
  bool _thresholdHapticDone = false;

  DateTime? _opponentDroppedAt;
  int _opponentSecondsAtDrop = 0;
  bool _showRejoin = false;
  bool _rejoinError = false;
  DateTime? _rejoinShownAt;
  int _rejoinSecondsAtShow = 0;
  bool _graceExpiryHandled = false;
  bool _opponentDisconnected = false;
  bool _consentedLeave = false;
  bool _pauseBudgetGone = false;

  bool get _isPrivate => widget.mode == 'private';
  bool get _isCasual => widget.mode == 'casual';
  bool get _isRanked => widget.mode == 'ranked';
  bool get _isHuman => _isPrivate || _isCasual || _isRanked;
  /// Casual Stick Pull 8s; Ranked Stick Pull 12s (D-101).
  int get _graceCap => _isRanked ? 12 : 8;

  bool get _isTerminal {
    final String status = _match?.status ?? 'IN_PLAY';
    return status == 'PLAYER_WIN' ||
        status == 'BOT_WIN' ||
        status == 'DRAW' ||
        status == 'HOST_WIN' ||
        status == 'JOINER_WIN';
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
    return (_opponentSecondsAtDrop -
            DateTime.now().difference(droppedAt).inSeconds)
        .clamp(0, _graceCap);
  }

  bool get _tapDisabled =>
      _paused ||
      _isTerminal ||
      _phase == 'SETTLED' ||
      _socket == null ||
      _showRejoin ||
      _opponentReconnectSeconds != null;

  /// Taps are false-starts until the server phase is LIVE.
  /// SETTLED is the result wait, not a pre-GO window.
  bool get _waitingForGo =>
      !_isTerminal && _phase != 'LIVE' && _phase != 'SETTLED';

  bool get _canPull => !_tapDisabled && !_waitingForGo;

  String _tapLabel(AppLocalizations l10n) {
    if (_isTerminal || _phase == 'SETTLED') {
      return l10n.stickSettlingResult;
    }
    if (_phase == 'LIVE') {
      return l10n.stickPullNow;
    }
    if (_countdown != null) {
      return l10n.stickWaitGo;
    }
    return l10n.startingMatch;
  }

  @override
  void initState() {
    super.initState();
    _game = StickPullGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _falseStartTimer?.cancel();
    _countdownClearTimer?.cancel();
    _countdownWatch?.cancel();
    _countdownFallback?.cancel();
    _uiTick?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_socket?.close());
    super.dispose();
  }

  void _ensureUiTick() {
    _uiTick ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) {
        return;
      }
      if (_showRejoin && _rejoinSecondsLeft <= 0 && !_graceExpiryHandled) {
        _graceExpiryHandled = true;
        unawaited(_onGraceExpired());
      }
      setState(() {});
    });
  }

  Future<void> _bootstrap() async {
    if (_isHuman) {
      await _bootHuman();
      return;
    }
    final String? existing = widget.matchId;
    if (existing != null && existing.isNotEmpty) {
      await _attachMatch(existing);
      return;
    }
    await _startMatch();
  }

  Future<void> _bootHuman() async {
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
        await _applyHumanSnapshot(snap);
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
      _ensureUiTick();
      return;
    }
    final String? existing = widget.matchId;
    if (existing == null || existing.isEmpty) {
      setState(() => _startError = true);
      return;
    }
    await _attachMatch(existing);
  }

  StickPullGame _gameForLoadout(Map<String, String> loadout) {
    return StickPullGame(
      shaftColor: StickPullGame.shaftColorForLoadout(loadout),
    );
  }

  Future<void> _startMatch() async {
    setState(() {
      _startError = false;
      _match = null;
      _phase = 'COUNTDOWN';
      _countdown = null;
      _countdownFinished = false;
      _fallbackDigit = null;
      _goHapticDone = false;
      _thresholdHapticDone = false;
      _countdownReconnectAttempted = false;
      _staminaYou = 1;
      _staminaOpp = 1;
      _prevLocalStamina = 1;
      _opponentDisconnected = false;
      _game = StickPullGame();
    });
    try {
      final MatchStart created = await ref.read(nomadApiProvider).startMatch(
            difficulty: widget.difficulty,
            game: 'STICK_PULL',
          );
      ref
          .read(lastStickPullBotDifficultyProvider.notifier)
          .setDifficulty(widget.difficulty);
      if (!mounted) {
        return;
      }
      _game = _gameForLoadout(created.localLoadout);
      await _attachCreated(created);
    } on NomadApiException {
      if (mounted) {
        setState(() => _startError = true);
      }
    }
  }

  Future<void> _attachCreated(MatchStart created) async {
    _activeMatchId = created.matchId;
    _match = created;
    await _connectWs(created.matchId);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _attachMatch(String matchId) async {
    try {
      final MatchStart snap =
          await ref.read(nomadApiProvider).getMatch(matchId);
      if (!mounted) {
        return;
      }
      if (_isHuman) {
        await _applyHumanSnapshot(snap);
      } else {
        _activeMatchId = matchId;
        _match = snap;
        _game = _gameForLoadout(snap.localLoadout);
      }
      await _connectWs(matchId);
      if (mounted) {
        setState(() {});
      }
    } on NomadApiException {
      if (mounted) {
        setState(() => _startError = true);
      }
    }
  }

  Future<void> _applyHumanSnapshot(MatchStart snap) async {
    final String? playerId = await ref.read(sessionStoreProvider).playerId();
    _activeMatchId = snap.matchId.isNotEmpty ? snap.matchId : _activeMatchId;
    _match = snap;
    _pauseBudgetGone = snap.pauseBudgetGone;
    if (playerId != null && playerId == snap.hostId) {
      _localSeat = 'host';
      _opponentLabel = snap.joinerLabel ?? '';
    } else if (playerId != null && playerId == snap.joinerId) {
      _localSeat = 'joiner';
      _opponentLabel = snap.hostLabel ?? '';
    }
    _game = _gameForLoadout(snap.localLoadout);
  }

  Future<void> _connectWs(String matchId) async {
    await _sub?.cancel();
    await _socket?.close();
    _countdownWatch?.cancel();
    _countdownFallback?.cancel();
    final NomadApi api = ref.read(nomadApiProvider);
    final WsTicket ticket = await api.wsTicket(matchId);
    if (_isHuman) {
      await _persistTicketReconnect(ticket, matchId);
    }
    final MatchSocket socket = await MatchSocket.connect(
      api.wsUrlForMatch(matchId: matchId, ticket: ticket.ticket),
    );
    _socket = socket;
    // Attach BEFORE any await so buffered Countdown/StickState flush immediately.
    _sub = socket.messages.listen(_onFrame, onError: (_) {}, onDone: () {
      if (!mounted || _consentedLeave || _isTerminal) {
        return;
      }
      if (_isHuman) {
        unawaited(_onSocketLost());
        return;
      }
      unawaited(_reconnectBotSocket());
    });
    socket.flushBufferedFrames();
    _armCountdownWatch();
  }

  void _armCountdownWatch() {
    _countdownWatch?.cancel();
    _countdownWatch = Timer(const Duration(seconds: 3), () {
      if (!mounted ||
          _isTerminal ||
          _countdown != null ||
          _phase == 'LIVE' ||
          _countdownReconnectAttempted) {
        return;
      }
      _countdownReconnectAttempted = true;
      final String? id = _activeMatchId;
      if (id == null || id.isEmpty) {
        return;
      }
      unawaited(_connectWs(id));
    });
  }

  /// Bot matches used to ignore a closed socket, so the overlay stayed on 3.
  Future<void> _reconnectBotSocket() async {
    if (_botReconnectInFlight || _botReconnects >= 3 || _phase == 'LIVE') {
      return;
    }
    final String? id = _activeMatchId;
    if (id == null || id.isEmpty) {
      return;
    }
    _botReconnectInFlight = true;
    _botReconnects += 1;
    try {
      await _connectWs(id);
    } catch (_) {
      // Next close can try again until the cap.
    } finally {
      _botReconnectInFlight = false;
    }
  }

  /// Server digits are 1s apart. If the next one is late, keep the overlay moving.
  /// A repeat of the same digit must not postpone GO.
  void _armCountdownFallback() {
    if (_countdownFinished || _phase == 'LIVE' || _isTerminal) {
      _countdownFallback?.cancel();
      return;
    }
    final String? current = _countdown;
    if (current == null || current == 'GO') {
      _countdownFallback?.cancel();
      return;
    }
    if (_countdownFallback?.isActive == true && _fallbackDigit == current) {
      return;
    }
    _countdownFallback?.cancel();
    _fallbackDigit = current;
    const List<String> steps = <String>['3', '2', '1', 'GO'];
    final int index = steps.indexOf(current);
    if (index < 0 || index + 1 >= steps.length) {
      return;
    }
    final String next = steps[index + 1];
    _countdownFallback = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted || _countdown != current || _countdownFinished || _isTerminal) {
        return;
      }
      setState(() => _countdown = next);
      if (next == 'GO') {
        _finishCountdown();
        return;
      }
      _armCountdownFallback();
    });
  }

  /// GO — from the server or from the local step — leaves the blocking overlay
  /// and opens the pull button. A later "1" must not rewind this.
  void _finishCountdown() {
    _countdownWatch?.cancel();
    _countdownFallback?.cancel();
    if (_countdownFinished) {
      if (_phase != 'LIVE' && mounted) {
        setState(() => _phase = 'LIVE');
      }
      return;
    }
    _countdownFinished = true;
    if (!_goHapticDone) {
      _goHapticDone = true;
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _phase = 'LIVE');
    }
    _countdownClearTimer?.cancel();
    _countdownClearTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _countdown = null);
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
          game: 'STICK_PULL',
          mode: widget.mode,
        );
  }

  Future<void> _onSocketLost() async {
    if (!mounted ||
        _consentedLeave ||
        _isTerminal ||
        _showRejoin ||
        !_isHuman) {
      return;
    }
    // Isolate-alive: try rejoin; process-death uses Rejoin overlay via cold boot.
    await _rejoinMatch();
  }

  Future<void> _rejoinMatch() async {
    final SessionStore session = ref.read(sessionStoreProvider);
    final String matchId =
        await session.reconnectMatchId() ?? _activeMatchId ?? '';
    if (matchId.isEmpty) {
      return;
    }
    try {
      final String? token = await session.reconnectToken();
      if (token == null || token.isEmpty) {
        return;
      }
      final RejoinResult result =
          await ref.read(nomadApiProvider).rejoin(matchId, token);
      if (result.reconnectToken.isNotEmpty) {
        await session.persistReconnect(
          token: result.reconnectToken,
          matchId: matchId,
          localSeat: _localSeat,
          game: 'STICK_PULL',
          mode: widget.mode,
        );
      }
      if (!mounted) {
        return;
      }
      await _applyHumanSnapshot(result.match);
      setState(() {
        _showRejoin = false;
        _rejoinError = false;
        _opponentDroppedAt = null;
      });
      await _connectWs(matchId);
    } on NomadApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.statusCode == 410) {
        await _onGraceExpired();
        return;
      }
      setState(() => _rejoinError = true);
    }
  }

  Future<void> _onGraceExpired() async {
    final String? id = _activeMatchId;
    if (id != null) {
      try {
        final MatchStart snap = await ref.read(nomadApiProvider).getMatch(id);
        if (mounted) {
          setState(() {
            _match = snap;
            _showRejoin = false;
            _opponentDroppedAt = null;
            _opponentDisconnected = true;
          });
        }
      } on NomadApiException {
        if (mounted) {
          setState(() {
            _showRejoin = false;
            _opponentDisconnected = true;
          });
        }
      }
    }
    await ref.read(sessionStoreProvider).clearReconnect();
  }

  void _onFrame(Map<String, dynamic> frame) {
    final String? type = StickPullWs.typeOf(frame);
    if (type == null || !mounted) {
      return;
    }
    if (type == 'OpponentDropped') {
      final int seconds =
          ((frame['secondsLeft'] as num?)?.toInt() ?? _graceCap).clamp(0, _graceCap);
      setState(() {
        _opponentDroppedAt = DateTime.now();
        _opponentSecondsAtDrop = seconds;
      });
      _ensureUiTick();
      return;
    }
    if (type == 'OpponentRejoined') {
      setState(() {
        _opponentDroppedAt = null;
        _opponentSecondsAtDrop = 0;
      });
      return;
    }
    switch (type) {
      case 'Countdown':
        final String? value = StickPullWs.countdownValue(frame);
        _countdownWatch?.cancel();
        if (_countdownFinished && value != 'GO') {
          break;
        }
        final String? phase = StickPullWs.phaseOf(frame);
        if (value == 'GO' || phase == 'LIVE') {
          setState(() => _countdown = value ?? 'GO');
          _finishCountdown();
          break;
        }
        _countdownClearTimer?.cancel();
        setState(() {
          _countdown = value;
          if (!_countdownFinished) {
            _phase = 'COUNTDOWN';
          }
        });
        _armCountdownFallback();
        break;
      case 'StickState':
      case 'TapResolved':
        final double? marker = StickPullWs.markerOf(frame);
        if (marker != null) {
          _game.setMarker(marker);
          if (!_thresholdHapticDone && marker.abs() >= 0.85) {
            _thresholdHapticDone = true;
            _game.flashThreshold();
            HapticFeedback.heavyImpact();
          }
        }
        var falseStart = false;
        var enteredLive = false;
        setState(() {
          final double host = StickPullWs.staminaHost(frame);
          final double joiner = StickPullWs.staminaJoiner(frame);
          final bool localIsHost = !_isHuman || _localSeat != 'joiner';
          final double local = localIsHost ? host : joiner;
          final double opp = localIsHost ? joiner : host;
          if (_prevLocalStamina > 0 && local <= 0) {
            _game.flashExhaust();
            HapticFeedback.lightImpact();
          }
          _prevLocalStamina = local;
          _staminaYou = local;
          _staminaOpp = opp;
          _clockSeconds = StickPullWs.clockSecondsLeft(frame);
          final String? phase = StickPullWs.phaseOf(frame);
          if (phase != null) {
            final String resolved =
                _countdownFinished && phase == 'COUNTDOWN' ? 'LIVE' : phase;
            enteredLive = resolved == 'LIVE' && _phase != 'LIVE';
            _phase = resolved;
            if (resolved == 'LIVE') {
              _countdownFallback?.cancel();
              if (_countdown != 'GO') {
                _countdown = null;
              }
            }
            if (phase == 'SETTLED') {
              _falseStart = false;
              _falseStartTimer?.cancel();
            }
          }
          falseStart = type == 'TapResolved' &&
              !StickPullWs.accepted(frame) &&
              _phase != 'SETTLED' &&
              _phase != 'LIVE';
        });
        if (falseStart) {
          _showFalseStart();
        }
        if (enteredLive) {
          _finishCountdown();
        }
        break;
      case 'MatchSettled':
        final Map<String, dynamic>? match = StickPullWs.matchOf(frame);
        if (match != null) {
          final String status = match['status'] as String? ?? 'DRAW';
          _falseStartTimer?.cancel();
          _countdownFallback?.cancel();
          setState(() {
            _match = MatchStart(
              matchId: _activeMatchId ?? '',
              difficulty: widget.difficulty,
              boneIds: const <String>[],
              turn: 'LIVE',
              status: status,
              playerScore: (match['playerScore'] as num?)?.toInt() ?? 0,
              botScore: (match['botScore'] as num?)?.toInt() ?? 0,
              coinsGranted: (match['coinsGranted'] as num?)?.toInt() ?? 0,
              gemsGranted: (match['gemsGranted'] as num?)?.toInt() ?? 0,
              mode: _match?.mode,
              hostId: _match?.hostId,
              joinerId: _match?.joinerId,
              hostLabel: _match?.hostLabel,
              joinerLabel: _match?.joinerLabel,
              localLoadout: _match?.localLoadout ?? const <String, String>{},
            );
            _phase = 'SETTLED';
            _countdown = null;
            _falseStart = false;
            _opponentDroppedAt = null;
            _showRejoin = false;
            if (status == 'HOST_WIN' || status == 'JOINER_WIN') {
              _opponentDisconnected = _opponentDisconnected ||
                  (_opponentSecondsAtDrop > 0);
            }
          });
          unawaited(ref.read(sessionStoreProvider).clearReconnect());
        }
        break;
      default:
        break;
    }
  }

  void _showFalseStart() {
    _falseStartTimer?.cancel();
    setState(() => _falseStart = true);
    _falseStartTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _falseStart = false);
      }
    });
  }

  void _onTapZone() {
    if (_tapDisabled) {
      return;
    }
    if (_phase != 'LIVE') {
      _showFalseStart();
      _clientSeq += 1;
      _socket!.send(StickPullWs.tapInput(clientSeq: _clientSeq));
      return;
    }
    _clientSeq += 1;
    _socket!.send(StickPullWs.tapInput(clientSeq: _clientSeq));
  }

  Future<void> _playAgain() async {
    if (_isHuman) {
      // Rematch for human modes is Phase 5/6 rematch routes — catalog for now.
      if (mounted) {
        context.go('/');
      }
      return;
    }
    await _sub?.cancel();
    await _socket?.close();
    _socket = null;
    _sub = null;
    if (!mounted) {
      return;
    }
    // Reset in place (like Alchiki). Do NOT context.go — that remounts a second
    // match while this state also starts one (orphan MATCH_STARTED + stuck CTA).
    setState(() {
      _startError = false;
      _match = null;
      _activeMatchId = null;
      _phase = 'COUNTDOWN';
      _countdown = null;
      _countdownFinished = false;
      _fallbackDigit = null;
      _goHapticDone = false;
      _thresholdHapticDone = false;
      _countdownReconnectAttempted = false;
      _staminaYou = 1;
      _staminaOpp = 1;
      _prevLocalStamina = 1;
      _clockSeconds = 60;
      _clientSeq = 0;
      _paused = false;
      _leaveConfirm = false;
      _falseStart = false;
      _opponentDroppedAt = null;
      _opponentDisconnected = false;
      _showRejoin = false;
      _game = StickPullGame();
    });
    await _startMatch();
  }

  /// Ranked result primary: enqueue a fresh Ranked Stick Pull search (D-99).
  Future<void> _findRankedMatch() async {
    try {
      await ref.read(nomadApiProvider).enqueueRanked(game: 'STICK_PULL');
      if (!mounted) {
        return;
      }
      context.go('/matchmaking?mode=ranked&game=stickPull');
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      context.go('/matchmaking?mode=ranked&game=stickPull');
    }
  }

  Future<void> _leave() async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    _consentedLeave = true;
    // Leave UI immediately — do not wait on Render/API.
    unawaited(ref.read(sessionStoreProvider).clearReconnect());
    final String? id = _activeMatchId;
    if (mounted) {
      setState(() {
        _leaveConfirm = false;
        _paused = false;
      });
      context.go('/');
    }
    if (id == null || id.isEmpty) {
      return;
    }
    try {
      await ref.read(nomadApiProvider).leaveMatch(id);
    } catch (_) {
      // Best-effort; player already left the table UI.
    }
  }

  void _openHowToFromPause() {
    final String modeQ =
        widget.mode != null ? '&mode=${widget.mode}' : '';
    final String matchQ = widget.matchId != null && widget.matchId!.isNotEmpty
        ? '&matchId=${Uri.encodeComponent(widget.matchId!)}'
        : '';
    context.push(
      '/howto/stick-pull?fromPause=1&difficulty=${widget.difficulty}$modeQ$matchQ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? oppReconnect = _opponentReconnectSeconds;
    return Scaffold(
      backgroundColor: _wood,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SteppeBackdrop(),
          SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
            if (_match == null && !_startError && !_showRejoin)
              SteppeLoading(label: l10n.startingMatch),
            if (_match != null && !_startError && !_showRejoin)
              GameWidget<StickPullGame>(game: _game),
            if (_match != null && !_startError && !_showRejoin) _buildHud(l10n),
            if (_match != null && !_startError && !_showRejoin && !_isTerminal)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: _PullCta(
                    label: _tapLabel(l10n),
                    enabled: !_tapDisabled,
                    active: _canPull,
                    onTap: _onTapZone,
                  ),
                ),
              ),
            if ((oppReconnect != null || _pauseBudgetGone) &&
                !_isTerminal &&
                !_showRejoin)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: StickPullHudReconnect(
                    l10n: l10n,
                    secondsLeft: oppReconnect,
                    opponentLabel: _opponentLabel.isEmpty
                        ? null
                        : l10n.waitingForName(_opponentLabel),
                    pauseBudgetGone: _pauseBudgetGone,
                    isRanked: _isRanked,
                  ),
                ),
              ),
            if (_countdown != null && !_isTerminal && !_showRejoin)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _phase == 'LIVE',
                  child: ColoredBox(
                    color: _wood.withValues(alpha: 0.55),
                    child: Center(
                      child: Text(
                        _countdown!,
                        style: TextStyle(
                          color: _countdown == 'GO' ? _accent : _onDark,
                          fontSize: _countdown == 'GO' ? 56 : 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_falseStart)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 72),
                  child: Material(
                    color: _wood.withValues(alpha: 0.88),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.falseStartToast,
                        style: const TextStyle(
                          color: _onDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_startError && !_showRejoin)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.errorStickPullStart,
                        style: const TextStyle(
                          color: _onDark,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: _onAccent,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => unawaited(
                          _isHuman
                              ? _attachMatch(widget.matchId ?? '')
                              : _startMatch(),
                        ),
                        child: Text(l10n.retry),
                      ),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: Text(
                          l10n.backToCatalog,
                          style: const TextStyle(color: _onDark),
                        ),
                      ),
                    ],
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
            if (_isTerminal && !_showRejoin) ...[
              if (_opponentDisconnected)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Text(
                      l10n.opponentDisconnected,
                      style: const TextStyle(
                        color: _onDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ResultOverlay(
                l10n: l10n,
                status: _match?.status ?? 'DRAW',
                localSeat: _localSeat.isEmpty ? null : _localSeat,
                opponentLabel: _isHuman ? _opponentLabel : null,
                youScore: 0,
                botScore: 0,
                showScore: false,
                isRanked: _isRanked,
                coinsGranted: _match?.coinsGranted ?? 0,
                gemsGranted: _match?.gemsGranted ?? 0,
                onPlayAgain: (_isHuman || _isRanked)
                    ? null
                    : () => unawaited(_playAgain()),
                onFindRankedMatch:
                    _isRanked ? () => unawaited(_findRankedMatch()) : null,
                onBackToCatalog: () => context.go('/'),
                onShop: () {
                  context.go('/');
                  context.push('/shop');
                },
              ),
            ],
            if (_paused && !_leaveConfirm && !_isTerminal && !_showRejoin)
              PauseOverlay(
                l10n: l10n,
                onResume: () {
                  setState(() => _paused = false);
                  if (!_isHuman) {
                    _socket?.send(StickPullWs.resume());
                  }
                },
                onHowToPlay: _openHowToFromPause,
                onLeave: () => setState(() => _leaveConfirm = true),
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
                          _paused = false;
                        });
                        if (!_isHuman) {
                          _socket?.send(StickPullWs.resume());
                        }
                      },
                onLeaveMatch: _leaving ? null : () => unawaited(_leave()),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHud(AppLocalizations l10n) {
    final String oppLabel =
        _isHuman ? (_opponentLabel.isEmpty ? l10n.opponent : _opponentLabel) : l10n.bot;
    return Positioned(
      top: 8,
      left: 8,
      right: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PauseChip(
            label: l10n.pause,
            enabled: !_leaving,
            onTap: () {
              setState(() {
                _paused = true;
                _leaveConfirm = false;
              });
              if (!_isHuman) {
                _socket?.send(StickPullWs.pause());
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _avatarColumn(l10n.you, _staminaYou, true, l10n),
                    ),
                    Text(
                      l10n.stickClock('$_clockSeconds'),
                      style: const TextStyle(
                        color: _onDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: _avatarColumn(oppLabel, _staminaOpp, false, l10n),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarColumn(
    String label,
    double stamina,
    bool local,
    AppLocalizations l10n,
  ) {
    final int pct = (stamina.clamp(0.0, 1.0) * 100).round();
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _earth,
            border: Border.all(
              color: local ? const Color(0xFFFFF6D6) : const Color(0xFF7EB6D9),
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: _onDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          label: l10n.staminaA11y(pct),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: stamina.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: _staminaTrack,
              color: _prevLocalStamina <= 0 && local && stamina <= 0
                  ? _accent
                  : _onDark,
            ),
          ),
        ),
      ],
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
        color: _StickPullMatchPageState._wood.withValues(alpha: 0.88),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: _StickPullMatchPageState._onDark.withValues(alpha: 0.45),
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Tooltip(
              message: label,
              child: const Icon(
                Icons.pause,
                color: _StickPullMatchPageState._onDark,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PullCta extends StatelessWidget {
  const _PullCta({
    required this.label,
    required this.enabled,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill = active
        ? _StickPullMatchPageState._accent
        : _StickPullMatchPageState._wood.withValues(alpha: 0.92);
    final Color text = active
        ? _StickPullMatchPageState._onAccent
        : _StickPullMatchPageState._onDark.withValues(alpha: enabled ? 0.85 : 0.4);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SizedBox(
        width: 260,
        height: 56,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(4),
          elevation: active ? 4 : 0,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text,
                  fontSize: active ? 18 : 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: active ? 1.4 : 0.6,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
