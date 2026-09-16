import 'dart:async';

import 'package:client/howto/howto_diagrams.dart';
import 'package:client/howto/howto_seen_store.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AlchikiHowToPage extends ConsumerStatefulWidget {
  const AlchikiHowToPage({
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
  ConsumerState<AlchikiHowToPage> createState() => _AlchikiHowToPageState();
}

class _AlchikiHowToPageState extends ConsumerState<AlchikiHowToPage> {
  static const Color _wood = Color(0xFF241810);
  static const Color _cream = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);

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
    HowtoCircleDiagram(),
    HowtoAimDiagram(),
    HowtoHoldDiagram(),
    HowtoScoreDiagram(),
    HowtoWinDiagram(),
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
      (title: l10n.howtoCircleTitle, body: l10n.howtoCircleBody),
      (title: l10n.howtoAimTitle, body: l10n.howtoAimBody),
      (title: l10n.howtoHoldTitle, body: l10n.howtoHoldBody),
      (title: l10n.howtoScoreTitle, body: l10n.howtoScoreBody),
      (title: l10n.howtoWinTitle, body: l10n.howtoWinBody),
    ];
  }

  Future<void> _goMatch({required bool persistSeen}) async {
    if (persistSeen && !widget.fromPause) {
      await ref.read(howToSeenStoreProvider).markSeen();
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
        '/match?mode=${Uri.encodeQueryComponent(widget.mode!)}'
        '&matchId=${Uri.encodeQueryComponent(widget.matchId!)}',
      );
      return;
    }
    context.go('/match?difficulty=${widget.difficulty}');
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
                        label: l10n.playAlchiki,
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
            ? const BorderSide(color: _AlchikiHowToPageState._cream)
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
