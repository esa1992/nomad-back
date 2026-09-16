import 'dart:async';

import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  static const Color _surround = Color(0xFF241810);
  static const Color _felt = Color(0xFF1B6B3A);
  static const Color _onDark = Color(0xFFF4E8C8);
  static const Color _destructive = Color(0xFFC43C2C);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);

  bool _inFlight = false;
  bool _mintFailed = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_startMint());
      }
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _startMint() async {
    _timeout?.cancel();
    setState(() {
      _inFlight = true;
      _mintFailed = false;
    });
    _timeout = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _inFlight) {
        setState(() {
          _inFlight = false;
          _mintFailed = true;
        });
      }
    });
    try {
      final SessionStore session = ref.read(sessionStoreProvider);
      final NomadApi api = ref.read(nomadApiProvider);
      final String? existing = await session.playerId();
      if (existing == null || existing.isEmpty) {
        await api.mintGuest();
      }
      if (!mounted) {
        return;
      }
      _timeout?.cancel();
      _inFlight = false;
      final String? token = await session.reconnectToken();
      final String? matchId = await session.reconnectMatchId();
      if (!mounted) {
        return;
      }
      if (token != null &&
          token.isNotEmpty &&
          matchId != null &&
          matchId.isNotEmpty) {
        final String? game = await session.reconnectGame();
        final String? mode = await session.reconnectMode();
        final String gameQ = game == 'STICK_PULL' ? '&game=stickPull' : '';
        final String modeQ = '&mode=${mode ?? 'private'}';
        context.go(
          '/match?matchId=${Uri.encodeQueryComponent(matchId)}$modeQ$gameQ',
        );
      } else {
        context.go('/');
      }
    } catch (_) {
      _timeout?.cancel();
      if (!mounted) {
        return;
      }
      setState(() {
        _inFlight = false;
        _mintFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _surround,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: _felt,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.appTitle,
              style: const TextStyle(
                color: _onDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (_mintFailed) ...[
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _destructive),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      l10n.errorGuestMint,
                      textAlign: TextAlign.center,
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
              const SizedBox(height: 16),
              Material(
                color: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: InkWell(
                  onTap: _startMint,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Center(
                        child: Text(
                          l10n.retry,
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
            ],
          ],
        ),
      ),
    );
  }
}
