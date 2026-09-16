import 'dart:async';

import 'package:client/howto/howto_seen_store.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StickPullHowToPage extends ConsumerStatefulWidget {
  const StickPullHowToPage({
    super.key,
    required this.difficulty,
    this.fromPause = false,
    this.mode,
    this.matchId,
  });

  final String difficulty;
  final bool fromPause;
  final String? mode;
  final String? matchId;

  @override
  ConsumerState<StickPullHowToPage> createState() => _StickPullHowToPageState();
}

class _StickPullHowToPageState extends ConsumerState<StickPullHowToPage> {
  static const Color _wood = Color(0xFF241810);
  static const Color _cream = Color(0xFFF4E8C8);
  static const Color _felt = Color(0xFF1B6B3A);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);
  static const Color _stick = Color(0xFF8B5A2B);
  static const Color _rim = Color(0xFFE8D4A8);

  static const TextStyle _label = TextStyle(
    color: _cream,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle _body = TextStyle(
    color: _cream,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle _heading = TextStyle(
    color: _cream,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const List<Widget> _diagrams = <Widget>[
    _HowtoStickSitDiagram(),
    _HowtoStickGoDiagram(),
    _HowtoStickTapDiagram(),
    _HowtoStickStaminaDiagram(),
    _HowtoStickWinDiagram(),
  ];

  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<({String title, String body})> _cards(AppLocalizations l10n) {
    return <({String title, String body})>[
      (title: l10n.howtoStickSitTitle, body: l10n.howtoStickSitBody),
      (title: l10n.howtoStickGoTitle, body: l10n.howtoStickGoBody),
      (title: l10n.howtoStickTapTitle, body: l10n.howtoStickTapBody),
      (title: l10n.howtoStickStaminaTitle, body: l10n.howtoStickStaminaBody),
      (title: l10n.howtoStickWinTitle, body: l10n.howtoStickWinBody),
    ];
  }

  Future<void> _goMatch({required bool persistSeen}) async {
    if (persistSeen && !widget.fromPause) {
      await ref.read(howToSeenStoreProvider).markStickPullSeen();
    }
    if (!mounted) {
      return;
    }
    if (widget.fromPause && context.canPop()) {
      context.pop();
      return;
    }
    if ((widget.mode == 'private' || widget.mode == 'casual') &&
        widget.matchId != null &&
        widget.matchId!.isNotEmpty) {
      context.go(
        '/match?game=stickPull'
        '&mode=${Uri.encodeQueryComponent(widget.mode!)}'
        '&matchId=${Uri.encodeQueryComponent(widget.matchId!)}',
      );
      return;
    }
    context.go(
      '/match?game=stickPull&difficulty=${widget.difficulty}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<({String title, String body})> cards = _cards(l10n);
    final ({String title, String body}) card = cards[_index];
    final bool lastCard = _index == cards.length - 1;

    return Scaffold(
      backgroundColor: _wood,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.howToPlay, style: _heading)),
                  if (widget.fromPause)
                    _HowToButton(
                      label: l10n.backToMatch,
                      fill: _wood,
                      textColor: _cream,
                      outlined: true,
                      onTap: () => unawaited(_goMatch(persistSeen: false)),
                    )
                  else
                    _HowToButton(
                      label: l10n.skip,
                      fill: _wood,
                      textColor: _cream,
                      outlined: true,
                      onTap: () => unawaited(_goMatch(persistSeen: true)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: cards.length,
                        onPageChanged: (int index) {
                          setState(() => _index = index);
                        },
                        itemBuilder: (BuildContext context, int index) {
                          return _diagrams[index];
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(card.title, style: _heading, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(card.body, style: _body, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Opacity(
                            opacity: i == _index ? 1 : 0.4,
                            child: const SizedBox(
                              width: 8,
                              height: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _cream,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${_index + 1} / 5', style: _label),
                    const SizedBox(height: 16),
                    if (!lastCard)
                      _HowToButton(
                        label: l10n.next,
                        fill: _wood,
                        textColor: _cream,
                        outlined: true,
                        onTap: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          );
                        },
                      )
                    else if (widget.fromPause)
                      _HowToButton(
                        label: l10n.backToMatch,
                        fill: _wood,
                        textColor: _cream,
                        outlined: true,
                        onTap: () => unawaited(_goMatch(persistSeen: false)),
                      )
                    else
                      _HowToButton(
                        label: l10n.playStickPull,
                        fill: _accent,
                        textColor: _onAccent,
                        minWidth: 192,
                        onTap: () => unawaited(_goMatch(persistSeen: true)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowToButton extends StatelessWidget {
  const _HowToButton({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.onTap,
    this.outlined = false,
    this.minWidth = 48,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final VoidCallback onTap;
  final bool outlined;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.transparent : fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: outlined
            ? const BorderSide(color: _StickPullHowToPageState._cream)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 48),
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
    );
  }
}

class _HowtoStickSitDiagram extends StatelessWidget {
  const _HowtoStickSitDiagram();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _StickLanePainter(markerT: 0.5),
      child: SizedBox.expand(),
    );
  }
}

class _HowtoStickGoDiagram extends StatelessWidget {
  const _HowtoStickGoDiagram();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _StickGoPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _HowtoStickTapDiagram extends StatelessWidget {
  const _HowtoStickTapDiagram();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _StickLanePainter(markerT: 0.35, showTapZone: true),
      child: SizedBox.expand(),
    );
  }
}

class _HowtoStickStaminaDiagram extends StatelessWidget {
  const _HowtoStickStaminaDiagram();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _StickStaminaPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _HowtoStickWinDiagram extends StatelessWidget {
  const _HowtoStickWinDiagram();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _StickLanePainter(markerT: 0.12, showThreshold: true),
      child: SizedBox.expand(),
    );
  }
}

class _StickLanePainter extends CustomPainter {
  const _StickLanePainter({
    required this.markerT,
    this.showTapZone = false,
    this.showThreshold = false,
  });

  final double markerT;
  final bool showTapZone;
  final bool showThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect lane = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.28,
      size.width * 0.8,
      size.height * 0.28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lane, const Radius.circular(8)),
      Paint()..color = _StickPullHowToPageState._felt,
    );
    final double midY = lane.center.dy;
    canvas.drawLine(
      Offset(lane.left + 16, midY),
      Offset(lane.right - 16, midY),
      Paint()
        ..color = _StickPullHowToPageState._stick
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    if (showThreshold) {
      final Paint tick = Paint()
        ..color = _StickPullHowToPageState._rim
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(lane.left + 24, lane.top + 8),
        Offset(lane.left + 24, lane.bottom - 8),
        tick,
      );
      canvas.drawLine(
        Offset(lane.right - 24, lane.top + 8),
        Offset(lane.right - 24, lane.bottom - 8),
        tick,
      );
    }
    final double markerX =
        lane.left + 24 + (lane.width - 48) * markerT.clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(markerX, midY),
      10,
      Paint()..color = _StickPullHowToPageState._cream,
    );
    if (showTapZone) {
      final Rect zone = Rect.fromLTWH(
        lane.left,
        lane.bottom + 12,
        lane.width,
        28,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(zone, const Radius.circular(4)),
        Paint()
          ..color = _StickPullHowToPageState._cream.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StickLanePainter oldDelegate) =>
      oldDelegate.markerT != markerT ||
      oldDelegate.showTapZone != showTapZone ||
      oldDelegate.showThreshold != showThreshold;
}

class _StickGoPainter extends CustomPainter {
  const _StickGoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final TextPainter tp = TextPainter(
      text: const TextSpan(
        text: 'GO',
        style: TextStyle(
          color: _StickPullHowToPageState._accent,
          fontSize: 48,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StickStaminaPainter extends CustomPainter {
  const _StickStaminaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect track = Rect.fromLTWH(
      size.width * 0.2,
      size.height * 0.42,
      size.width * 0.6,
      16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(4)),
      Paint()..color = const Color(0xFF3A2A1C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(track.left, track.top, track.width * 0.25, track.height),
        const Radius.circular(4),
      ),
      Paint()..color = _StickPullHowToPageState._cream,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
