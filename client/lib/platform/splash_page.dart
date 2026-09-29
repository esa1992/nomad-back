import 'dart:async';

import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/theme/steppe_backdrop.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:client/theme/steppe_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// Branded splash stays at least this long after mint starts.
  /// Kept short — paid Render is warm; long hold felt like a slow API.
  static const Duration minHold = Duration(milliseconds: 1200);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  bool _inFlight = false;
  bool _mintFailed = false;
  int? _apiMs;
  Timer? _timeout;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

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
    _fade.dispose();
    super.dispose();
  }

  Future<void> _startMint() async {
    _timeout?.cancel();
    setState(() {
      _inFlight = true;
      _mintFailed = false;
      _apiMs = null;
    });
    final DateTime started = DateTime.now();
    _timeout = Timer(const Duration(seconds: 55), () {
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
      // Health first — surfaces real RTT independent of mint/auth.
      final int healthMs = await api.probeHealthMs();
      if (mounted) {
        setState(() => _apiMs = healthMs);
      }
      final String? existing = await session.playerId();
      if (existing == null || existing.isEmpty) {
        await api.mintGuest();
      }
      if (!mounted) {
        return;
      }
      _timeout?.cancel();
      _inFlight = false;
      await _holdSplash(started);
      if (!mounted) {
        return;
      }
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
      await _holdSplash(started);
      if (!mounted) {
        return;
      }
      setState(() {
        _inFlight = false;
        _mintFailed = true;
      });
    }
  }

  /// Keep the branded splash visible at least [SplashPage.minHold]
  /// (even on fast/failed mint).
  Future<void> _holdSplash(DateTime started) async {
    final Duration elapsed = DateTime.now().difference(started);
    if (elapsed < SplashPage.minHold) {
      await Future<void>.delayed(SplashPage.minHold - elapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: SteppeOps.voidBg,
      body: SteppeBackdrop(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(88, 88),
                      painter: const _BrandMarkPainter(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.appTitle.toUpperCase(),
                      style: SteppeOps.brand,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'STEPPE OPS',
                      style: SteppeOps.labelMuted.copyWith(letterSpacing: 3),
                    ),
                    if (_inFlight && !_mintFailed) ...[
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SteppeOps.accent,
                        ),
                      ),
                      if (_apiMs != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.apiLatencyMs(_apiMs!),
                          style: SteppeOps.labelMuted.copyWith(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                    if (_mintFailed) ...[
                      const SizedBox(height: 28),
                      SteppeBanner(
                        message: l10n.errorGuestMint,
                        retryLabel: l10n.retry,
                        onRetry: _startMint,
                      ),
                      if (_apiMs != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.apiLatencyMs(_apiMs!),
                          style: SteppeOps.labelMuted.copyWith(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      c,
      size.width / 2,
      Paint()
        ..color = SteppeOps.felt
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      size.width / 2 - 1,
      Paint()
        ..color = SteppeOps.accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final Color mark = SteppeOps.mist.withValues(alpha: 0.9);
    final Paint stroke = Paint()
      ..color = mark
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint fill = Paint()..color = mark;
    canvas.drawLine(
      Offset(c.dx - 18, c.dy + 6),
      Offset(c.dx + 18, c.dy - 6),
      stroke,
    );
    canvas.drawCircle(Offset(c.dx - 18, c.dy + 6), 6, fill);
    canvas.drawCircle(Offset(c.dx + 18, c.dy - 6), 6, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
