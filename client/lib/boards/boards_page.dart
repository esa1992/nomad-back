import 'dart:async';

import 'package:client/boards/boards_api.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Wood skill boards — game filter + season/all-time (LEAD-01…03 / 07-UI-SPEC).
class BoardsPage extends ConsumerStatefulWidget {
  const BoardsPage({super.key});

  @override
  ConsumerState<BoardsPage> createState() => _BoardsPageState();
}

class _BoardsPageState extends ConsumerState<BoardsPage> {
  static const Color _wood = Color(0xFF241810);
  static const Color _cream = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);
  static const Color _localRow = Color(0xFF3A2A1C);
  static const Color _destructive = Color(0xFFC43C2C);

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
  static const TextStyle _display = TextStyle(
    color: _cream,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  String _game = 'ALCHIKI';
  String _scope = 'season';
  List<BoardEntry> _entries = const <BoardEntry>[];
  String? _localPlayerId;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final String? playerId = await ref.read(sessionStoreProvider).playerId();
      final BoardsSnapshot snap = await ref.read(boardsApiProvider).fetch(
            game: _game,
            scope: _scope,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _localPlayerId = playerId;
        _entries = snap.entries;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = const <BoardEntry>[];
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _selectGame(String game) async {
    if (_game == game) {
      return;
    }
    setState(() => _game = game);
    await _load();
  }

  Future<void> _selectScope(String scope) async {
    if (_scope == scope) {
      return;
    }
    setState(() => _scope = scope);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
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
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      child: Text(l10n.backToCatalog, style: _label),
                    ),
                  ),
                  const Spacer(),
                  Text(l10n.boardsTitle, style: _heading),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: l10n.statsAlchiki,
                    selected: _game == 'ALCHIKI',
                    onTap: () => unawaited(_selectGame('ALCHIKI')),
                  ),
                  _FilterChip(
                    label: l10n.stickPullTitle,
                    selected: _game == 'STICK_PULL',
                    onTap: () => unawaited(_selectGame('STICK_PULL')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: l10n.boardsSeason,
                    selected: _scope == 'season',
                    onTap: () => unawaited(_selectScope('season')),
                  ),
                  _FilterChip(
                    label: l10n.boardsAllTime,
                    selected: _scope == 'all_time',
                    onTap: () => unawaited(_selectScope('all_time')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _bodyContent(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bodyContent(AppLocalizations l10n) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }
    if (_error) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: _destructive),
            ),
            child: Text(l10n.errorBoards, style: _body),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => unawaited(_load()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _onAccent,
              ),
              child: Text(l10n.retry, style: _label.copyWith(color: _onAccent)),
            ),
          ),
        ],
      );
    }
    if (_entries.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.boardsEmptyTitle, style: _heading, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.boardsEmptyBody, style: _body, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/matchmaking?mode=ranked'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _onAccent,
              ),
              child: Text(
                l10n.findRankedMatch,
                style: _label.copyWith(color: _onAccent),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text(l10n.boardsRank, style: _label)),
              Expanded(child: Text(l10n.boardsPlayer, style: _label)),
              Text(l10n.statRating, style: _label),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (BuildContext context, int index) {
              final BoardEntry entry = _entries[index];
              final bool local = _localPlayerId != null &&
                  entry.playerId == _localPlayerId;
              return Container(
                color: local ? _localRow : null,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('#${entry.rank}', style: _label),
                    ),
                    Expanded(
                      child: Text(
                        local ? l10n.you : entry.username,
                        style: local ? _display : _body,
                      ),
                    ),
                    Text('${entry.rating}', style: local ? _display : _label),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: selected ? _accent : _wood,
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? _accent : _cream),
            ),
            child: Text(
              label,
              style: _label.copyWith(
                color: selected ? _onAccent : _cream,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
