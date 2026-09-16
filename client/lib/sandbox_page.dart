import 'dart:async';
import 'dart:io';

import 'package:client/game/alchiki_sandbox_game.dart';
import 'package:client/input/throw_input.dart';
import 'package:client/replay/authority_score.dart';
import 'package:client/replay/throw_resolved.dart';
import 'package:client/schema/table_constants.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single-screen parlor sandbox. Flame owns the table; Flutter owns Hold / Reset (D-04).
class SandboxPage extends StatefulWidget {
  const SandboxPage({super.key});

  @override
  State<SandboxPage> createState() => _SandboxPageState();
}

class _SandboxPageState extends State<SandboxPage>
    with SingleTickerProviderStateMixin {
  static const Color _surround = Color(0xFF241810);
  static const Color _onDark = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);
  static const Color _destructive = Color(0xFFC43C2C);

  static const TextStyle _label = TextStyle(
    color: _onDark,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle _body = TextStyle(
    color: _onDark,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle _heading = TextStyle(
    color: _onDark,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  late final AlchikiSandboxGame game;
  late final AnimationController _pulse;

  bool _charging = false;
  bool _throwing = false;
  bool _settled = false;
  bool _hasSettledOnce = false;
  bool _sakaOut = false;
  bool _replaying = false;
  int _preview = 0;
  int? _scored;
  double _emptyOpacity = 1;
  DateTime? _chargeStart;
  Timer? _meterTick;
  Timer? _emptyTimer;
  Timer? _hudTick;
  int? _lastHoldMs;
  ThrowInput? _lastInput;
  ThrowResolved? _resolved;
  _ReplayError? _replayError;
  DateTime? _importedMtime;
  int _debugFps = 0;
  int _debugBodies = 0;
  bool _debugSettled = true;

  @override
  void initState() {
    super.initState();
    game = AlchikiSandboxGame();
    game.onSettled = _onGameSettled;
    game.onReplayEnded = _onReplayEnded;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pulse.addListener(() {
      if (mounted && _charging) {
        setState(() {});
      }
    });
    _startEmptyCopy();
    unawaited(_loadGolden());
    _hudTick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) {
        return;
      }
      _pollImportedResolved();
      setState(() {
        _debugFps = game.debugFps;
        _debugBodies = game.debugBodyCount;
        _debugSettled = game.tableSettled;
      });
    });
  }

  @override
  void dispose() {
    _meterTick?.cancel();
    _emptyTimer?.cancel();
    _hudTick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  int get _rawHoldMs {
    final start = _chargeStart;
    if (start == null) {
      return TableConstants.holdMsMin;
    }
    return DateTime.now().difference(start).inMilliseconds;
  }

  double get _chargeT {
    final clamped = _rawHoldMs.clamp(
      TableConstants.holdMsMin,
      TableConstants.holdMsMax,
    );
    return (clamped - TableConstants.holdMsMin) /
        (TableConstants.holdMsMax - TableConstants.holdMsMin);
  }

  bool get _atMax => _rawHoldMs >= TableConstants.holdMsMax;

  bool get _holdEnabled => !_throwing && !_settled && !_replaying;

  bool get _replayReady =>
      _resolved != null &&
      ThrowResolved.allowsReplay(_resolved!, _lastInput) &&
      _replayError != _ReplayError.invalid;

  bool get _replayEnabled =>
      _hasSettledOnce &&
      !_replaying &&
      !_throwing &&
      !_charging &&
      _replayReady;

  void _startEmptyCopy() {
    _emptyTimer?.cancel();
    setState(() {
      _emptyOpacity = 1;
    });
    _emptyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _emptyOpacity = 0;
        });
      }
    });
  }

  void _onGameSettled() {
    if (!mounted) {
      return;
    }
    setState(() {
      _throwing = false;
      _settled = true;
      _hasSettledOnce = true;
      _preview = game.previewCount;
      _sakaOut = game.sakaOut;
      _debugSettled = true;
    });
  }

  void _startCharge() {
    if (!_holdEnabled) {
      return;
    }
    _meterTick?.cancel();
    _emptyTimer?.cancel();
    setState(() {
      _charging = true;
      _chargeStart = DateTime.now();
      _emptyOpacity = 0;
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
    final holdMs = _rawHoldMs.clamp(
      TableConstants.holdMsMin,
      TableConstants.holdMsMax,
    );
    final input = ThrowInput(
      schemaVersion: 1,
      yUp: true,
      aimAngleRad: game.aim.aimAngleRad,
      holdMs: holdMs,
      seed: 1,
      tableId: TableConstants.tableId,
    );
    setState(() {
      _charging = false;
      _throwing = true;
      _settled = false;
      _chargeStart = null;
      _lastHoldMs = input.holdMs;
      _lastInput = input;
    });
    await _persistThrowInput(input);
    game.throwSaka(input);
  }

  void _resetTable() {
    if (!_settled || _replaying) {
      return;
    }
    game.resetTable();
    setState(() {
      _charging = false;
      _throwing = false;
      _settled = false;
      _replaying = false;
      _preview = 0;
      _scored = null;
      _sakaOut = false;
      _debugSettled = true;
    });
    _refreshReplayError();
    _startEmptyCopy();
  }

  Future<void> _loadGolden() async {
    try {
      final source = await rootBundle.loadString(
        'assets/replays/golden_throw.json',
      );
      _applyResolved(ThrowResolved.parse(source));
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _replayError = _ReplayError.invalid;
      });
    }
  }

  void _pollImportedResolved() {
    try {
      final file = File(
        '${_documentsDir().path}${Platform.pathSeparator}throw_resolved.json',
      );
      if (!file.existsSync()) {
        return;
      }
      final mtime = file.lastModifiedSync();
      if (_importedMtime != null && mtime == _importedMtime) {
        return;
      }
      _importedMtime = mtime;
      _applyResolved(ThrowResolved.parse(file.readAsStringSync()));
    } on FormatException {
      if (!mounted) {
        return;
      }
      setState(() {
        _replayError = _ReplayError.invalid;
      });
    } on Object {
      // Missing documents dir or a transient IO error — keep last good buffer.
    }
  }

  void _applyResolved(ThrowResolved resolved) {
    if (!mounted) {
      return;
    }
    setState(() {
      _resolved = resolved;
      _replayError = ThrowResolved.allowsReplay(resolved, _lastInput)
          ? null
          : _ReplayError.mismatch;
    });
  }

  void _refreshReplayError({bool notify = true}) {
    _ReplayError? next;
    if (_replayError == _ReplayError.invalid && _resolved == null) {
      next = _ReplayError.invalid;
    } else if (_resolved == null) {
      next = _ReplayError.missing;
    } else if (!ThrowResolved.allowsReplay(_resolved!, _lastInput)) {
      next = _ReplayError.mismatch;
    }
    if (notify) {
      setState(() {
        _replayError = next;
      });
    } else {
      _replayError = next;
    }
  }

  void _startReplay() {
    final resolved = _resolved;
    if (!_replayEnabled || resolved == null) {
      return;
    }
    final scored = AuthorityScore.readPocketedCount(
      resolved,
      lastInput: _lastInput,
    );
    setState(() {
      _replaying = true;
      _scored = scored;
      _replayError = null;
    });
    game.startReplay(resolved);
  }

  void _onReplayEnded() {
    if (!mounted) {
      return;
    }
    setState(() {
      _replaying = false;
    });
  }

  Future<void> _persistThrowInput(ThrowInput input) async {
    try {
      final dir = _documentsDir();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('${dir.path}${Platform.pathSeparator}throw_input.json');
      await file.writeAsString(input.toJsonString());
      debugPrint('Wrote ${file.path}');
    } on Object catch (e) {
      debugPrint('throw_input.json write failed: $e');
    }
  }

  Directory _documentsDir() {
    if (Platform.isAndroid) {
      return Directory('/data/data/com.nomadgames.client/app_flutter');
    }
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return Directory(
      '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}nomad-game-proto',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pulseOpacity = _charging && _atMax
        ? 0.8 + 0.2 * _pulse.value
        : 1.0;
    final holdOpacity = !_holdEnabled
        ? 0.4
        : pulseOpacity;

    return Scaffold(
      backgroundColor: _surround,
      body: Stack(
        children: [
          GameWidget.controlled(gameFactory: () => game),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DebugHud(
                    fps: _debugFps,
                    bodies: _debugBodies,
                    settled: _debugSettled,
                    holdMs: _lastHoldMs,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Text('preview $_preview', style: _label),
                        const SizedBox(height: 8),
                        Text(
                          _scored == null ? 'scored —' : 'scored $_scored',
                          style: _label,
                        ),
                        if (_sakaOut) ...[
                          const SizedBox(height: 8),
                          const Text('saka out · 0', style: _body),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 88, 16, 0),
                child: AnimatedOpacity(
                  opacity: _emptyOpacity,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    child: Column(
                      children: const [
                        Text('Table reset', style: _heading),
                        SizedBox(height: 8),
                        Text(
                          'Drag around the saka to aim, then press Hold Throw.',
                          style: _body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasSettledOnce) ...[
                      if (_replayError != null && !_replayReady) ...[
                        _ReplayErrorBanner(error: _replayError!),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TableButton(
                            label: 'Reset Table',
                            fill: _surround,
                            textColor: _onDark,
                            enabled: _settled && !_replaying,
                            onTap: _resetTable,
                          ),
                          const SizedBox(width: 16),
                          _TableButton(
                            label: 'Replay Throw',
                            fill: _accent,
                            textColor: _onAccent,
                            enabled: _replayEnabled,
                            outlined: !_replayEnabled,
                            onTap: _startReplay,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_charging) ...[
                      _PowerMeter(fill: _chargeT),
                      const SizedBox(height: 24),
                    ],
                    Opacity(
                      opacity: holdOpacity,
                      child: Listener(
                        onPointerDown: (_) => _startCharge(),
                        onPointerUp: (_) => _releaseCharge(),
                        onPointerCancel: (_) => _releaseCharge(),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 192,
                            minHeight: 48,
                          ),
                          child: Material(
                            color: _accent,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              child: SizedBox(
                                height: 24,
                                child: Center(
                                  child: Text(
                                    'Hold Throw',
                                    style: TextStyle(
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

class _DebugHud extends StatelessWidget {
  const _DebugHud({
    required this.fps,
    required this.bodies,
    required this.settled,
    this.holdMs,
  });

  final int fps;
  final int bodies;
  final bool settled;
  final int? holdMs;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF241810).withValues(alpha: 0.88),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('fps $fps', style: _SandboxPageState._label),
            const SizedBox(height: 8),
            Text('bodies $bodies', style: _SandboxPageState._label),
            const SizedBox(height: 8),
            Text(
              settled ? 'settled yes' : 'settled no',
              style: _SandboxPageState._label,
            ),
            if (holdMs != null) ...[
              const SizedBox(height: 8),
              Text('holdMs $holdMs', style: _SandboxPageState._label),
            ],
          ],
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
    this.outlined = false,
    this.onTap,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final bool enabled;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color surface = outlined ? Colors.transparent : fill;
    final Color labelColor = outlined
        ? _SandboxPageState._onDark
        : textColor;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: outlined
              ? const BorderSide(color: Color(0xFF241810))
              : BorderSide.none,
        ),
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
                    color: labelColor,
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

enum _ReplayError { missing, mismatch, invalid }

class _ReplayErrorBanner extends StatelessWidget {
  const _ReplayErrorBanner({required this.error});

  final _ReplayError error;

  @override
  Widget build(BuildContext context) {
    final (:heading, :body) = switch (error) {
      _ReplayError.missing => (
        heading: 'Replay is not ready.',
        body:
            'Import a JVM ThrowResolved that matches this throw, or open the golden replay.',
      ),
      _ReplayError.mismatch => (
        heading: 'This replay does not match the last throw.',
        body: 'Load a matching ThrowResolved or throw again.',
      ),
      _ReplayError.invalid => (
        heading: 'Replay file is unreadable.',
        body: 'Use a harness ThrowResolved with schemaVersion 1.',
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: _SandboxPageState._destructive),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(heading, style: _SandboxPageState._heading),
            const SizedBox(height: 8),
            Text(
              body,
              style: _SandboxPageState._body,
              textAlign: TextAlign.center,
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 8,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF241810)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fill.clamp(0.0, 1.0),
              child: const ColoredBox(color: Color(0xFFF0B429)),
            ),
          ),
        ),
      ),
    );
  }
}
