import 'dart:async';

import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Dedicated CASUAL rematch wait after Play again (D-70…D-73). Wood route, 10s clock.
class RematchWaitingPage extends ConsumerStatefulWidget {
  const RematchWaitingPage({
    super.key,
    this.matchId = '',
    this.opponentLabel = '',
  });

  final String matchId;
  final String opponentLabel;

  @override
  ConsumerState<RematchWaitingPage> createState() => _RematchWaitingPageState();
}

class _RematchWaitingPageState extends ConsumerState<RematchWaitingPage> {
  static const Color _wood = Color(0xFF241810);
  static const Color _onDark = Color(0xFFF4E8C8);
  static const Color _destructive = Color(0xFFC43C2C);

  static const TextStyle _label = TextStyle(
    color: _onDark,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle _heading = TextStyle(
    color: _onDark,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  Timer? _poll;
  bool _navigating = false;
  bool _acceptedPosted = false;
  bool _cancelling = false;
  int _rematchSeconds = 10;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_postAccept());
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
        unawaited(_tickPoll());
      });
      unawaited(_tickPoll());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _postAccept() async {
    if (widget.matchId.isEmpty || _acceptedPosted || _navigating || _cancelling) {
      return;
    }
    _acceptedPosted = true;
    try {
      final RematchAccept result = await ref
          .read(nomadApiProvider)
          .rematch(widget.matchId, accept: true);
      if (!mounted || _navigating || _cancelling) {
        return;
      }
      setState(() {
        _rematchSeconds = result.rematchSeconds;
        _error = null;
      });
      if (result.matchId != null && result.matchId!.isNotEmpty) {
        await _enterCasualMatch(result.matchId!);
      }
    } on NomadApiException {
      if (!mounted || _navigating || _cancelling) {
        return;
      }
      setState(() {
        _error = AppLocalizations.of(context).errorRematch;
      });
    }
  }

  Future<void> _tickPoll() async {
    if (widget.matchId.isEmpty || _navigating || _cancelling) {
      return;
    }
    try {
      final RematchPoll poll = await ref
          .read(nomadApiProvider)
          .getRematch(widget.matchId);
      if (!mounted || _navigating || _cancelling) {
        return;
      }
      setState(() {
        _rematchSeconds = poll.rematchSeconds;
      });
      if (poll.matchId != null && poll.matchId!.isNotEmpty) {
        await _enterCasualMatch(poll.matchId!);
        return;
      }
      if (poll.expired) {
        await _goCatalog(clearReconnect: true);
      }
    } on NomadApiException {
      // Transient poll errors keep waiting chrome until Cancel / timeout.
    }
  }

  Future<void> _enterCasualMatch(String newId) async {
    if (_navigating || !mounted || newId.isEmpty) {
      return;
    }
    _navigating = true;
    _poll?.cancel();
    final String encoded = Uri.encodeQueryComponent(newId);
    context.go('/match?mode=casual&matchId=$encoded');
  }

  Future<void> _cancelRematch() async {
    if (_cancelling || _navigating) {
      return;
    }
    setState(() {
      _cancelling = true;
      _error = null;
    });
    _poll?.cancel();
    if (widget.matchId.isNotEmpty) {
      try {
        await ref.read(nomadApiProvider).rematch(widget.matchId, accept: false);
      } on NomadApiException {
        // Still leave so Cancel is never stuck (D-72).
      }
    }
    await _goCatalog(clearReconnect: true);
  }

  Future<void> _goCatalog({required bool clearReconnect}) async {
    if (_navigating) {
      return;
    }
    _navigating = true;
    _poll?.cancel();
    if (clearReconnect) {
      await ref.read(sessionStoreProvider).clearReconnect();
    }
    if (!mounted) {
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String opponent = widget.opponentLabel.isEmpty
        ? l10n.opponent
        : widget.opponentLabel;
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
                l10n.rematchWaitingTitle,
                style: _heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.waitingForName(opponent),
                style: _label,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.rematchClock(
                  _rematchSeconds.toString().padLeft(2, '0'),
                ),
                style: _label,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: _label.copyWith(color: _destructive),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              Center(
                child: _OutlineCta(
                  label: l10n.cancelRematch,
                  minWidth: 192,
                  onTap: _cancelling || _navigating
                      ? null
                      : () => unawaited(_cancelRematch()),
                ),
              ),
              const SizedBox(height: 32),
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
        side: const BorderSide(color: _RematchWaitingPageState._onDark),
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
              child: Text(
                label,
                style: _RematchWaitingPageState._label,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
