import 'dart:async';

import 'package:client/catalog/catalog_models.dart';
import 'package:client/howto/howto_seen_store.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Empty-queue choice after 8s alone (D-62…D-65). Ticket stays SEARCHING until exit.
class FallbackPage extends ConsumerStatefulWidget {
  const FallbackPage({super.key, this.game});

  /// null = Alchiki; `stickPull` = Stick Pull Quick Match fallback (D-79).
  final String? game;

  @override
  ConsumerState<FallbackPage> createState() => _FallbackPageState();
}

class _FallbackPageState extends ConsumerState<FallbackPage> {
  static const Color _wood = Color(0xFF241810);
  static const Color _onDark = Color(0xFFF4E8C8);

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

  Timer? _poll;
  bool _navigating = false;
  bool _busy = false;
  String? _error;

  bool get _stickPull => widget.game == 'stickPull';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_refresh());
      });
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_navigating || _busy) {
      return;
    }
    try {
      final CasualQueueStatus status = await ref
          .read(nomadApiProvider)
          .pollCasual();
      if (!mounted || _navigating || _busy) {
        return;
      }
      if (status.isMatched) {
        await _goCasualMatch(status.matchId!);
      }
    } on NomadApiException {
      // Keep fallback chrome; exits surface dequeue/create errors.
    }
  }

  Future<void> _goCasualMatch(String matchId) async {
    if (_navigating || !mounted) {
      return;
    }
    _navigating = true;
    _poll?.cancel();
    final HowToSeenStore store = ref.read(howToSeenStoreProvider);
    final bool seen = _stickPull ? await store.isStickPullSeen() : await store.isSeen();
    if (!mounted) {
      return;
    }
    final String encoded = Uri.encodeQueryComponent(matchId);
    if (_stickPull) {
      if (seen) {
        context.go('/match?game=stickPull&mode=casual&matchId=$encoded');
      } else {
        context.go(
          '/howto/stick-pull?mode=casual&matchId=$encoded&difficulty=NORMAL',
        );
      }
      return;
    }
    if (seen) {
      context.go('/match?mode=casual&matchId=$encoded');
    } else {
      context.go(
        '/howto/alchiki?mode=casual&matchId=$encoded&difficulty=NORMAL',
      );
    }
  }

  Future<bool> _dequeueOrSurface() async {
    try {
      await ref.read(nomadApiProvider).dequeueCasual();
      return true;
    } on NomadApiException {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).errorQueueLeft;
          _busy = false;
        });
      }
      return false;
    }
  }

  Future<void> _playVsBot() async {
    if (_busy || _navigating) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _poll?.cancel();
    if (!await _dequeueOrSurface()) {
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_refresh());
      });
      return;
    }
    if (!mounted) {
      return;
    }
    _navigating = true;
    final HowToSeenStore store = ref.read(howToSeenStoreProvider);
    if (_stickPull) {
      final String difficulty = ref.read(lastStickPullBotDifficultyProvider);
      final bool seen = await store.isStickPullSeen();
      if (!mounted) {
        return;
      }
      if (seen) {
        context.go('/match?game=stickPull&difficulty=$difficulty');
      } else {
        context.go('/howto/stick-pull?difficulty=$difficulty');
      }
      return;
    }
    final String difficulty = ref.read(lastBotDifficultyProvider);
    final bool seen = await store.isSeen();
    if (!mounted) {
      return;
    }
    if (seen) {
      context.go('/match?difficulty=$difficulty');
    } else {
      context.go('/howto/alchiki?difficulty=$difficulty');
    }
  }

  Future<void> _inviteFriend() async {
    if (_busy || _navigating) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _poll?.cancel();
    if (!await _dequeueOrSurface()) {
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_refresh());
      });
      return;
    }
    try {
      final RoomCreated room = await ref.read(nomadApiProvider).createRoom(
            game: _stickPull ? 'STICK_PULL' : 'ALCHIKI',
          );
      if (!mounted) {
        return;
      }
      _navigating = true;
      final String gameQuery = _stickPull ? '&game=stickPull' : '';
      context.go(
        '/lobby?roomId=${Uri.encodeQueryComponent(room.roomId)}'
        '&code=${Uri.encodeQueryComponent(room.code)}'
        '&hostLabel=${Uri.encodeQueryComponent(room.hostLabel)}'
        '$gameQuery',
      );
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).errorRoomCreate;
      });
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_refresh());
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).errorRoomCreate;
      });
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_refresh());
      });
    }
  }

  Future<void> _backToCatalog() async {
    if (_busy || _navigating) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _poll?.cancel();
    try {
      await ref.read(nomadApiProvider).dequeueCasual();
    } on NomadApiException {
      // Still leave so Back is never stuck (D-65).
    }
    if (!mounted) {
      return;
    }
    _navigating = true;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _wood,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                l10n.fallbackTitle,
                style: _heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.fallbackBody,
                style: _body,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: _body,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _OutlineCta(
                      label: l10n.playVsBot,
                      onTap: _busy || _navigating
                          ? null
                          : () => unawaited(_playVsBot()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _OutlineCta(
                      label: l10n.inviteFriend,
                      onTap: _busy || _navigating
                          ? null
                          : () => unawaited(_inviteFriend()),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: _OutlineCta(
                  label: l10n.backToCatalog,
                  minWidth: 192,
                  onTap: _busy || _navigating
                      ? null
                      : () => unawaited(_backToCatalog()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineCta extends StatelessWidget {
  const _OutlineCta({
    required this.label,
    required this.onTap,
    this.minWidth,
  });

  final String label;
  final VoidCallback? onTap;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: _FallbackPageState._onDark),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth ?? 0,
            minHeight: 48,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(label, style: _FallbackPageState._label),
            ),
          ),
        ),
      ),
    );
  }
}
