import 'dart:async';

import 'package:client/howto/howto_seen_store.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/matchmaking/ranked_api.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full-screen Casual / Ranked search. Ranked never bot-falls back (D-98).
class SearchingPage extends ConsumerStatefulWidget {
  const SearchingPage({super.key, this.game, this.mode});

  /// null = Alchiki; `stickPull` = Stick Pull.
  final String? game;

  /// null/`casual` = Casual QM; `ranked` = Ranked (no fallback).
  final String? mode;

  @override
  ConsumerState<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends ConsumerState<SearchingPage> {
  static const Color _wood = Color(0xFF241810);
  static const Color _onDark = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);

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

  static const Duration _fallbackAfter = Duration(seconds: 8);

  Timer? _poll;
  Timer? _fallbackClock;
  bool _navigating = false;
  bool _cancelling = false;

  bool get _stickPull => widget.game == 'stickPull';

  bool get _ranked => widget.mode == 'ranked';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_refresh());
      });
      // Casual only — Ranked waits indefinitely with Cancel (D-98).
      if (!_ranked) {
        _fallbackClock = Timer(_fallbackAfter, _openFallback);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _fallbackClock?.cancel();
    super.dispose();
  }

  void _openFallback() {
    if (_navigating || _cancelling || !mounted || _ranked) {
      return;
    }
    _navigating = true;
    _poll?.cancel();
    _fallbackClock?.cancel();
    if (_stickPull) {
      context.go('/matchmaking/fallback?game=stickPull');
    } else {
      context.go('/matchmaking/fallback');
    }
  }

  Future<void> _refresh() async {
    if (_navigating || _cancelling) {
      return;
    }
    try {
      final CasualQueueStatus status = _ranked
          ? await ref.read(rankedApiProvider).poll()
          : await ref.read(nomadApiProvider).pollCasual();
      if (!mounted || _navigating || _cancelling) {
        return;
      }
      if (status.isMatched) {
        await _goMatch(status.matchId!);
      }
    } on NomadApiException {
      // Keep searching chrome; catalog surfaces enqueue errors.
    }
  }

  Future<void> _goMatch(String matchId) async {
    if (_navigating || !mounted) {
      return;
    }
    _navigating = true;
    _poll?.cancel();
    _fallbackClock?.cancel();
    final HowToSeenStore store = ref.read(howToSeenStoreProvider);
    final bool seen =
        _stickPull ? await store.isStickPullSeen() : await store.isSeen();
    if (!mounted) {
      return;
    }
    final String encoded = Uri.encodeQueryComponent(matchId);
    final String modeQ = _ranked ? 'ranked' : 'casual';
    if (_stickPull) {
      if (seen) {
        context.go('/match?game=stickPull&mode=$modeQ&matchId=$encoded');
      } else {
        context.go(
          '/howto/stick-pull?mode=$modeQ&matchId=$encoded&difficulty=NORMAL',
        );
      }
      return;
    }
    if (seen) {
      context.go('/match?mode=$modeQ&matchId=$encoded');
    } else {
      context.go(
        '/howto/alchiki?mode=$modeQ&matchId=$encoded&difficulty=NORMAL',
      );
    }
  }

  Future<void> _cancelSearch() async {
    if (_cancelling || _navigating) {
      return;
    }
    _cancelling = true;
    _poll?.cancel();
    _fallbackClock?.cancel();
    try {
      if (_ranked) {
        await ref.read(rankedApiProvider).dequeue();
      } else {
        await ref.read(nomadApiProvider).dequeueCasual();
      }
    } on NomadApiException {
      // Still leave so Cancel is never stuck (D-65).
    }
    if (!mounted) {
      return;
    }
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
              const Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.searchingTitle,
                style: _heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _ranked ? l10n.rankedSearchingBody : l10n.searchingBody,
                style: _body,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Center(
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: _onDark),
                  ),
                  child: InkWell(
                    onTap: _cancelling
                        ? null
                        : () => unawaited(_cancelSearch()),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 192,
                        minHeight: 48,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        child: Center(
                          child: Text(l10n.cancelSearch, style: _label),
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
    );
  }
}
