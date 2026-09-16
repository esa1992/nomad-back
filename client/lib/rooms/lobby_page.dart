import 'dart:async';

import 'package:client/howto/howto_seen_store.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class LobbyPage extends ConsumerStatefulWidget {
  const LobbyPage({
    super.key,
    required this.roomId,
    this.code = '',
    this.hostLabel = '',
    this.game,
  });

  final String roomId;
  final String code;
  final String hostLabel;
  /// Route hint or server `STICK_PULL`; null = Alchiki private room.
  final String? game;

  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage> {
  static const Color _wood = Color(0xFF241810);
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
  static const TextStyle _code = TextStyle(
    color: _onDark,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 4,
  );

  bool _copied = false;
  bool _hostLeaveConfirm = false;
  bool _navigating = false;
  Timer? _copiedTimer;
  Timer? _poll;
  RoomLobby? _lobby;
  String? _playerId;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPlayer());
      unawaited(_refresh());
      _poll = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_refresh());
      });
    });
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadPlayer() async {
    final String? id = await ref.read(sessionStoreProvider).playerId();
    if (!mounted) {
      return;
    }
    setState(() => _playerId = id);
  }

  Future<void> _refresh() async {
    if (widget.roomId.isEmpty || _navigating) {
      return;
    }
    try {
      final RoomLobby lobby = await ref
          .read(nomadApiProvider)
          .getRoom(widget.roomId);
      if (!mounted || _navigating) {
        return;
      }
      setState(() {
        _lobby = lobby;
        _error = null;
      });
      await _maybeKickoff(lobby);
    } on NomadApiException {
      // Keep last snapshot; closed chrome comes from status when GET still works.
    }
  }

  Future<void> _maybeKickoff(RoomLobby lobby) async {
    final String? matchId = lobby.matchId;
    if (!lobby.bothReady || matchId == null || matchId.isEmpty) {
      return;
    }
    await _goPrivateMatch(matchId);
  }

  bool get _stickPull {
    final String? g = _lobby?.game ?? widget.game;
    return g == 'stickPull' || g == 'STICK_PULL';
  }

  Future<void> _goPrivateMatch(String matchId) async {
    if (_navigating || !mounted) {
      return;
    }
    _navigating = true;
    _poll?.cancel();
    final HowToSeenStore store = ref.read(howToSeenStoreProvider);
    final bool seen =
        _stickPull ? await store.isStickPullSeen() : await store.isSeen();
    if (!mounted) {
      return;
    }
    final String encoded = Uri.encodeQueryComponent(matchId);
    if (_stickPull) {
      if (seen) {
        context.go('/match?game=stickPull&mode=private&matchId=$encoded');
      } else {
        context.go(
          '/howto/stick-pull?mode=private&matchId=$encoded&difficulty=NORMAL',
        );
      }
      return;
    }
    if (seen) {
      context.go('/match?mode=private&matchId=$encoded');
    } else {
      context.go(
        '/howto/alchiki?mode=private&matchId=$encoded&difficulty=NORMAL',
      );
    }
  }

  Future<void> _ready() async {
    setState(() => _error = null);
    try {
      final RoomLobby lobby = await ref
          .read(nomadApiProvider)
          .readyRoom(widget.roomId);
      if (!mounted) {
        return;
      }
      setState(() => _lobby = lobby);
      await _maybeKickoff(lobby);
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      setState(() => _error = AppLocalizations.of(context).errorReady);
    }
  }

  Future<void> _leaveLobby() async {
    try {
      await ref.read(nomadApiProvider).leaveRoom(widget.roomId);
    } on NomadApiException {
      // Still leave the chrome so the host is not stuck in a dying lobby.
    }
    if (!mounted) {
      return;
    }
    context.go('/');
  }

  Future<void> _share(AppLocalizations l10n, String code) async {
    await SharePlus.instance.share(
      ShareParams(text: l10n.shareSheetText(code)),
    );
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String hostLabel = _lobby?.hostLabel ?? widget.hostLabel;
    final String? joinerLabel = _lobby?.joinerLabel;
    final String code = (_lobby?.code ?? widget.code).toUpperCase();
    final bool isHost = _isHost(code);
    final String status = _lobby?.status ?? 'LOBBY';
    final bool closed = status == 'CLOSED';
    final bool joinerPresent = joinerLabel != null && joinerLabel.isNotEmpty;
    final bool localReady = isHost
        ? (_lobby?.hostReady ?? false)
        : (_lobby?.joinerReady ?? false);
    final bool readyEnabled = !closed && joinerPresent && !localReady;

    return Scaffold(
      backgroundColor: _wood,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: closed
                  ? _ClosedLobby(
                      l10n: l10n,
                      hostLeft: !isHost,
                      onBack: () => context.go('/'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _stickPull ? l10n.stickPullTitle : l10n.privateRoomTitle,
                          style: _heading,
                        ),
                        if (isHost && code.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Text(code, style: _code, textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _WoodButton(
                                  label: l10n.shareCode,
                                  onTap: () => unawaited(_share(l10n, code)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _WoodButton(
                                  label: l10n.copyCode,
                                  onTap: () => unawaited(_copy(code)),
                                ),
                              ),
                            ],
                          ),
                          if (_copied) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(l10n.copied, style: _label),
                            ),
                          ],
                        ],
                        const SizedBox(height: 24),
                        _SeatRow(
                          name: hostLabel.isNotEmpty
                              ? hostLabel
                              : l10n.waitingForFriend,
                          ready: _lobby?.hostReady ?? false,
                        ),
                        const SizedBox(height: 8),
                        if (!joinerPresent)
                          Text(l10n.waitingForFriend, style: _body)
                        else
                          _SeatRow(
                            name: joinerLabel,
                            ready: _lobby?.joinerReady ?? false,
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!, style: _body),
                        ],
                        const Spacer(),
                        if (readyEnabled)
                          _WoodButton(
                            label: l10n.ready,
                            fill: _accent,
                            textColor: _onAccent,
                            outlined: false,
                            onTap: () => unawaited(_ready()),
                          )
                        else
                          Opacity(
                            opacity: joinerPresent ? 1 : 0.4,
                            child: _WoodButton(
                              label: l10n.ready,
                              onTap: null,
                            ),
                          ),
                        const SizedBox(height: 16),
                        _WoodButton(
                          label: l10n.leaveLobby,
                          onTap: isHost
                              ? () => setState(() => _hostLeaveConfirm = true)
                              : () => unawaited(_leaveLobby()),
                        ),
                      ],
                    ),
            ),
          ),
          if (_hostLeaveConfirm)
            _HostLeaveConfirm(
              l10n: l10n,
              onStay: () => setState(() => _hostLeaveConfirm = false),
              onLeave: () => unawaited(_leaveLobby()),
            ),
        ],
      ),
    );
  }

  bool _isHost(String code) {
    final RoomLobby? lobby = _lobby;
    if (lobby != null) {
      return lobby.code != null && lobby.code!.isNotEmpty;
    }
    if (_playerId != null && widget.hostLabel.isNotEmpty) {
      final String hex = _playerId!.replaceAll('-', '');
      final String suffix = hex.length >= 4
          ? hex.substring(hex.length - 4)
          : hex;
      if (widget.hostLabel.toLowerCase().endsWith(suffix.toLowerCase())) {
        return true;
      }
    }
    return code.isNotEmpty;
  }
}

class _ClosedLobby extends StatelessWidget {
  const _ClosedLobby({
    required this.l10n,
    required this.hostLeft,
    required this.onBack,
  });

  final AppLocalizations l10n;
  final bool hostLeft;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hostLeft ? l10n.hostLeftTitle : l10n.roomClosedTitle,
          style: _LobbyPageState._heading,
        ),
        const SizedBox(height: 16),
        Text(
          hostLeft ? l10n.hostLeftBody : l10n.roomClosedBody,
          style: _LobbyPageState._body,
        ),
        const Spacer(),
        _WoodButton(label: l10n.backToCatalog, onTap: onBack),
      ],
    );
  }
}

class _HostLeaveConfirm extends StatelessWidget {
  const _HostLeaveConfirm({
    required this.l10n,
    required this.onStay,
    required this.onLeave,
  });

  final AppLocalizations l10n;
  final VoidCallback onStay;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _LobbyPageState._wood.withValues(alpha: 0.60),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _LobbyPageState._wood.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.leaveLobbyTitle,
                    style: _LobbyPageState._heading,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.leaveLobbyBodyHost,
                    style: _LobbyPageState._body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _WoodButton(label: l10n.stay, onTap: onStay),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _WoodButton(
                          label: l10n.leaveLobby,
                          fill: _LobbyPageState._destructive,
                          textColor: _LobbyPageState._onDark,
                          outlined: false,
                          onTap: onLeave,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.name,
    required this.ready,
  });

  final String name;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: _LobbyPageState._body,
          ),
        ),
        Text(
          ready ? l10n.ready : '—',
          style: _LobbyPageState._label,
        ),
      ],
    );
  }
}

class _WoodButton extends StatelessWidget {
  const _WoodButton({
    required this.label,
    required this.onTap,
    this.fill = _LobbyPageState._wood,
    this.textColor = _LobbyPageState._onDark,
    this.outlined = true,
  });

  final String label;
  final VoidCallback? onTap;
  final Color fill;
  final Color textColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? _LobbyPageState._wood : fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: outlined
            ? const BorderSide(color: _LobbyPageState._onDark)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(
                label,
                style: _LobbyPageState._label.copyWith(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
