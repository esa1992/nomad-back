import 'dart:async';

import 'package:client/catalog/avatar_chip.dart';
import 'package:client/catalog/catalog_models.dart';
import 'package:client/catalog/soft_lock_sheet.dart';
import 'package:client/howto/howto_seen_store.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/platform/locale_controller.dart';
import 'package:client/profile/avatar_assets.dart';
import 'package:client/shop/wallet_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key, this.snapshot});

  final CatalogSnapshot? snapshot;

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  static const Color _surround = Color(0xFF241810);
  static const Color _felt = Color(0xFF1B6B3A);
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
  static const TextStyle _heading = TextStyle(
    color: _onDark,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  Difficulty _difficulty = Difficulty.easy;
  Difficulty _stickPullDifficulty = Difficulty.easy;
  CatalogSnapshot? _snapshot;
  bool _loading = true;
  bool _error = false;
  bool _createError = false;
  bool _creating = false;
  bool _quickMatchError = false;
  bool _stickPullQuickMatchError = false;
  bool _stickPullCreateError = false;
  bool _creatingStickPull = false;
  int? _coins;
  int? _gems;
  bool _walletError = false;
  String _avatarPreset = kDefaultAvatarPreset;
  bool _isGuest = true;

  @override
  void initState() {
    super.initState();
    if (widget.snapshot != null) {
      _snapshot = widget.snapshot;
      _loading = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_bootCatalog());
      }
    });
  }

  Future<void> _bootCatalog() async {
    if (await _openStoredRejoin()) {
      return;
    }
    if (widget.snapshot != null) {
      return;
    }
    await _load();
  }

  Future<bool> _openStoredRejoin() async {
    final SessionStore session = ref.read(sessionStoreProvider);
    final String? token = await session.reconnectToken();
    final String? matchId = await session.reconnectMatchId();
    if (token == null ||
        token.isEmpty ||
        matchId == null ||
        matchId.isEmpty) {
      return false;
    }
    if (!mounted) {
      return true;
    }
    final String? game = await session.reconnectGame();
    final String? mode = await session.reconnectMode();
    final String gameQ = game == 'STICK_PULL' ? '&game=stickPull' : '';
    final String modeQ = '&mode=${mode ?? 'private'}';
    context.go(
      '/match?matchId=${Uri.encodeQueryComponent(matchId)}$modeQ$gameQ',
    );
    return true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _walletError = false;
    });
    final NomadApi api = ref.read(nomadApiProvider);
    final bool guest = await ref.read(sessionStoreProvider).isGuest();

    CatalogSnapshot? catalog;
    Object? catalogError;
    int? catalogStatus;
    WalletBalance? wallet;
    Object? walletError;
    int? walletStatus;
    PlayerProfile? profile;

    await Future.wait<void>([
      () async {
        try {
          catalog = await api.fetchCatalog();
        } on NomadApiException catch (error) {
          catalogError = error;
          catalogStatus = error.statusCode;
        } catch (error) {
          catalogError = error;
        }
      }(),
      () async {
        try {
          wallet = await api.fetchWallet();
        } on NomadApiException catch (error) {
          walletError = error;
          walletStatus = error.statusCode;
        } catch (error) {
          walletError = error;
        }
      }(),
      () async {
        try {
          profile = await api.fetchProfile();
        } catch (_) {
          // Avatar chip still renders with default preset (D-74).
        }
      }(),
    ]);

    if (!mounted) {
      return;
    }

    if (catalogStatus == 401 || walletStatus == 401) {
      await ref.read(sessionStoreProvider).clear();
      if (mounted) {
        context.go('/splash');
      }
      return;
    }

    if (catalogError != null) {
      setState(() {
        _loading = false;
        _error = true;
        _isGuest = guest;
      });
    } else {
      setState(() {
        _snapshot = catalog;
        _loading = false;
        _error = false;
        _isGuest = guest;
      });
    }

    if (walletError != null) {
      setState(() {
        _walletError = true;
        _coins = null;
        _gems = null;
      });
    } else if (wallet != null) {
      setState(() {
        _coins = wallet!.coins;
        _gems = wallet!.gems;
        _walletError = false;
      });
    }

    if (profile != null) {
      setState(() {
        _avatarPreset = profile!.avatarPreset;
      });
    }
  }

  Future<void> _reloadWallet() async {
    setState(() {
      _walletError = false;
    });
    try {
      final WalletBalance wallet = await ref.read(nomadApiProvider).fetchWallet();
      if (!mounted) {
        return;
      }
      setState(() {
        _coins = wallet.coins;
        _gems = wallet.gems;
        _walletError = false;
      });
    } on NomadApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.statusCode == 401) {
        await ref.read(sessionStoreProvider).clear();
        if (mounted) {
          context.go('/splash');
        }
        return;
      }
      setState(() {
        _walletError = true;
        _coins = null;
        _gems = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _walletError = true;
        _coins = null;
        _gems = null;
      });
    }
  }

  Future<void> _playAlchiki() async {
    final HowToSeenStore store = ref.read(howToSeenStoreProvider);
    final bool seen = await store.isSeen();
    if (!mounted) {
      return;
    }
    final String query = _difficulty.query;
    if (!seen) {
      context.go('/howto/alchiki?difficulty=$query');
    } else {
      context.go('/match?difficulty=$query');
    }
  }

  Future<void> _playStickPull() async {
    final HowToSeenStore store = ref.read(howToSeenStoreProvider);
    final bool seen = await store.isStickPullSeen();
    if (!mounted) {
      return;
    }
    final String query = _stickPullDifficulty.query;
    if (!seen) {
      context.go('/howto/stick-pull?difficulty=$query');
    } else {
      context.go('/match?game=stickPull&difficulty=$query');
    }
  }

  Future<void> _quickMatch() async {
    setState(() {
      _createError = false;
    });
    try {
      ref
          .read(lastBotDifficultyProvider.notifier)
          .setDifficulty(_difficulty.query);
      await ref.read(nomadApiProvider).enqueueCasual();
      if (!mounted) {
        return;
      }
      context.go('/matchmaking');
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      setState(() {
        _quickMatchError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _quickMatchError = true;
      });
    }
  }

  Future<void> _quickMatchStickPull() async {
    setState(() {
      _stickPullCreateError = false;
    });
    try {
      ref
          .read(lastStickPullBotDifficultyProvider.notifier)
          .setDifficulty(_stickPullDifficulty.query);
      await ref.read(nomadApiProvider).enqueueCasual(game: 'STICK_PULL');
      if (!mounted) {
        return;
      }
      context.go('/matchmaking?game=stickPull');
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      setState(() {
        _stickPullQuickMatchError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stickPullQuickMatchError = true;
      });
    }
  }

  Future<void> _createRoom() async {
    setState(() {
      _createError = false;
      _creating = true;
    });
    try {
      final RoomCreated room = await ref.read(nomadApiProvider).createRoom();
      if (!mounted) {
        return;
      }
      context.go(
        '/lobby?roomId=${Uri.encodeQueryComponent(room.roomId)}'
        '&code=${Uri.encodeQueryComponent(room.code)}'
        '&hostLabel=${Uri.encodeQueryComponent(room.hostLabel)}',
      );
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      setState(() {
        _creating = false;
        _createError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _creating = false;
        _createError = true;
      });
    }
  }

  Future<void> _onRankedTap({required String game}) async {
    if (_isGuest) {
      await showSoftLockSheet(context, kind: SoftLockKind.ranked);
      return;
    }
    setState(() {
      if (game == 'STICK_PULL') {
        _stickPullQuickMatchError = false;
      } else {
        _quickMatchError = false;
      }
    });
    try {
      await ref.read(nomadApiProvider).enqueueRanked(game: game);
      if (!mounted) {
        return;
      }
      if (game == 'STICK_PULL') {
        context.go('/matchmaking?mode=ranked&game=stickPull');
      } else {
        context.go('/matchmaking?mode=ranked');
      }
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      setState(() {
        if (game == 'STICK_PULL') {
          _stickPullQuickMatchError = true;
        } else {
          _quickMatchError = true;
        }
      });
    }
  }

  Future<void> _onBoardsTap() async {
    if (_isGuest) {
      await showSoftLockSheet(context, kind: SoftLockKind.boards);
      return;
    }
    context.push('/boards');
  }

  Future<void> _createStickPullRoom() async {
    setState(() {
      _stickPullCreateError = false;
      _creatingStickPull = true;
    });
    try {
      final RoomCreated room =
          await ref.read(nomadApiProvider).createRoom(game: 'STICK_PULL');
      if (!mounted) {
        return;
      }
      context.go(
        '/lobby?roomId=${Uri.encodeQueryComponent(room.roomId)}'
        '&code=${Uri.encodeQueryComponent(room.code)}'
        '&hostLabel=${Uri.encodeQueryComponent(room.hostLabel)}'
        '&game=stickPull',
      );
    } on NomadApiException {
      if (!mounted) {
        return;
      }
      setState(() {
        _creatingStickPull = false;
        _stickPullCreateError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _creatingStickPull = false;
        _stickPullCreateError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Locale? override = ref.watch(localeOverrideProvider);
    final String activeCode =
        override?.languageCode ?? Localizations.localeOf(context).languageCode;
    final bool enSelected = activeCode != 'ru';
    final List<CatalogTile> tiles = _snapshot?.tiles ?? const <CatalogTile>[];

    return Scaffold(
      backgroundColor: _surround,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.appTitle, style: _heading)),
                  AvatarChip(
                    avatarPreset: _avatarPreset,
                    onTap: () => context.push('/profile'),
                  ),
                  const SizedBox(width: 8),
                  if (_coins != null && _gems != null) ...[
                    WalletChip(coins: _coins!, gems: _gems!),
                    const SizedBox(width: 8),
                  ],
                  _ShopEntry(
                    label: l10n.shop,
                    onTap: () => context.push('/shop'),
                  ),
                  const SizedBox(width: 8),
                  _ShopEntry(
                    label: l10n.boards,
                    onTap: () => unawaited(_onBoardsTap()),
                  ),
                  _LangTarget(
                    label: l10n.langEn,
                    selected: enSelected,
                    onTap: () => ref
                        .read(localeOverrideProvider.notifier)
                        .setOverride('en'),
                  ),
                  _LangTarget(
                    label: l10n.langRu,
                    selected: !enSelected,
                    onTap: () => ref
                        .read(localeOverrideProvider.notifier)
                        .setOverride('ru'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_walletError) ...[
                _CatalogBanner(
                  message: l10n.errorWallet,
                  retryLabel: l10n.retry,
                  onRetry: () => unawaited(_reloadWallet()),
                ),
                const SizedBox(height: 16),
              ],
              if (_error)
                _CatalogBanner(
                  message: l10n.errorCatalog,
                  retryLabel: l10n.retry,
                  onRetry: _load,
                )
              else if (!_loading && tiles.isEmpty)
                _CatalogBanner(
                  message: l10n.emptyCatalogTitle,
                  retryLabel: l10n.retry,
                  onRetry: _load,
                )
              else ...[
                if (_createError)
                  _CatalogBanner(
                    message: l10n.errorRoomCreate,
                    retryLabel: l10n.retry,
                    onRetry: () => unawaited(_createRoom()),
                  ),
                if (_createError) const SizedBox(height: 16),
                if (_stickPullCreateError)
                  _CatalogBanner(
                    message: l10n.errorRoomCreate,
                    retryLabel: l10n.retry,
                    onRetry: () => unawaited(_createStickPullRoom()),
                  ),
                if (_stickPullCreateError) const SizedBox(height: 16),
                if (_quickMatchError)
                  _CatalogBanner(
                    message: l10n.errorQuickMatch,
                    retryLabel: l10n.retry,
                    onRetry: () {
                      setState(() => _quickMatchError = false);
                      unawaited(_quickMatch());
                    },
                  ),
                if (_quickMatchError) const SizedBox(height: 16),
                if (_stickPullQuickMatchError)
                  _CatalogBanner(
                    message: l10n.errorQuickMatch,
                    retryLabel: l10n.retry,
                    onRetry: () {
                      setState(() => _stickPullQuickMatchError = false);
                      unawaited(_quickMatchStickPull());
                    },
                  ),
                if (_stickPullQuickMatchError) const SizedBox(height: 16),
                for (final CatalogTile tile in tiles) ...[
                  if (tile.id == 'alchiki' &&
                      tile.availability == CatalogAvailability.playable) ...[
                    _AlchikiTile(
                      l10n: l10n,
                      difficulty: _difficulty,
                      isGuest: _isGuest,
                      onDifficulty: (Difficulty next) {
                        setState(() => _difficulty = next);
                        ref
                            .read(lastBotDifficultyProvider.notifier)
                            .setDifficulty(next.query);
                      },
                      onRanked: () =>
                          unawaited(_onRankedTap(game: 'ALCHIKI')),
                      onQuickMatch: () => unawaited(_quickMatch()),
                      onPlay: () => unawaited(_playAlchiki()),
                    ),
                    const SizedBox(height: 16),
                    _PrivateCtaBand(
                      l10n: l10n,
                      createEnabled: !_creating && !_createError,
                      onCreateRoom: () => unawaited(_createRoom()),
                      onJoinByCode: () => context.go('/join'),
                    ),
                  ] else if (tile.id == 'stick_pull' &&
                      tile.availability == CatalogAvailability.playable)
                    _StickPullTile(
                      l10n: l10n,
                      difficulty: _stickPullDifficulty,
                      isGuest: _isGuest,
                      onDifficulty: (Difficulty next) {
                        setState(() => _stickPullDifficulty = next);
                        ref
                            .read(lastStickPullBotDifficultyProvider.notifier)
                            .setDifficulty(next.query);
                      },
                      onRanked: () =>
                          unawaited(_onRankedTap(game: 'STICK_PULL')),
                      onQuickMatch: () => unawaited(_quickMatchStickPull()),
                      onPlay: () => unawaited(_playStickPull()),
                      createEnabled:
                          !_creatingStickPull && !_stickPullCreateError,
                      onCreateRoom: () => unawaited(_createStickPullRoom()),
                    )
                  else
                    _ComingSoonTile(
                      title: tile.id == 'stick_pull'
                          ? l10n.stickPullTitle
                          : l10n.moreGamesTitle,
                      badge: l10n.comingSoon,
                    ),
                  if (tile != tiles.last) const SizedBox(height: 64),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogBanner extends StatelessWidget {
  const _CatalogBanner({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _CatalogPageState._destructive),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(message, style: _CatalogPageState._label),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.center,
          child: _TableButton(
            label: retryLabel,
            fill: _CatalogPageState._accent,
            textColor: _CatalogPageState._onAccent,
            onTap: onRetry,
          ),
        ),
      ],
    );
  }
}

class _ShopEntry extends StatelessWidget {
  const _ShopEntry({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: _CatalogPageState._onDark,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        side: const BorderSide(color: _CatalogPageState._onDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label, style: _CatalogPageState._label),
    );
  }
}

class _LangTarget extends StatelessWidget {
  const _LangTarget({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Opacity(
            opacity: selected ? 1 : 0.4,
            child: Text(label, style: _CatalogPageState._label),
          ),
        ),
      ),
    );
  }
}

class _AlchikiTile extends StatelessWidget {
  const _AlchikiTile({
    required this.l10n,
    required this.difficulty,
    required this.isGuest,
    required this.onDifficulty,
    required this.onRanked,
    required this.onQuickMatch,
    required this.onPlay,
  });

  final AppLocalizations l10n;
  final Difficulty difficulty;
  final bool isGuest;
  final ValueChanged<Difficulty> onDifficulty;
  final VoidCallback onRanked;
  final VoidCallback onQuickMatch;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 192),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _CatalogPageState._felt),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.alchikiTitle, style: _CatalogPageState._heading),
              const SizedBox(height: 8),
              Row(
                children: [
                  _DifficultyChip(
                    label: l10n.diffEasy,
                    selected: difficulty == Difficulty.easy,
                    onSelected: () => onDifficulty(Difficulty.easy),
                  ),
                  const SizedBox(width: 8),
                  _DifficultyChip(
                    label: l10n.diffNormal,
                    selected: difficulty == Difficulty.normal,
                    onSelected: () => onDifficulty(Difficulty.normal),
                  ),
                  const SizedBox(width: 8),
                  _DifficultyChip(
                    label: l10n.diffHard,
                    selected: difficulty == Difficulty.hard,
                    onSelected: () => onDifficulty(Difficulty.hard),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: _TableButton(
                  label: l10n.ranked,
                  fill: isGuest
                      ? _CatalogPageState._felt
                      : _CatalogPageState._accent,
                  textColor: isGuest
                      ? _CatalogPageState._onDark
                      : _CatalogPageState._onAccent,
                  outlined: isGuest,
                  minWidth: 192,
                  onTap: onRanked,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: _TableButton(
                  label: l10n.quickMatch,
                  fill: _CatalogPageState._accent,
                  textColor: _CatalogPageState._onAccent,
                  minWidth: 192,
                  onTap: onQuickMatch,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: _TableButton(
                  label: l10n.playAlchiki,
                  fill: _CatalogPageState._felt,
                  textColor: _CatalogPageState._onDark,
                  outlined: true,
                  minWidth: 192,
                  onTap: onPlay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickPullTile extends StatelessWidget {
  const _StickPullTile({
    required this.l10n,
    required this.difficulty,
    required this.isGuest,
    required this.onDifficulty,
    required this.onRanked,
    required this.onQuickMatch,
    required this.onPlay,
    required this.createEnabled,
    required this.onCreateRoom,
  });

  final AppLocalizations l10n;
  final Difficulty difficulty;
  final bool isGuest;
  final ValueChanged<Difficulty> onDifficulty;
  final VoidCallback onRanked;
  final VoidCallback onQuickMatch;
  final VoidCallback onPlay;
  final bool createEnabled;
  final VoidCallback onCreateRoom;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 192),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _CatalogPageState._felt),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.stickPullTitle, style: _CatalogPageState._heading),
              const SizedBox(height: 8),
              Row(
                children: [
                  _DifficultyChip(
                    label: l10n.diffEasy,
                    selected: difficulty == Difficulty.easy,
                    onSelected: () => onDifficulty(Difficulty.easy),
                  ),
                  const SizedBox(width: 8),
                  _DifficultyChip(
                    label: l10n.diffNormal,
                    selected: difficulty == Difficulty.normal,
                    onSelected: () => onDifficulty(Difficulty.normal),
                  ),
                  const SizedBox(width: 8),
                  _DifficultyChip(
                    label: l10n.diffHard,
                    selected: difficulty == Difficulty.hard,
                    onSelected: () => onDifficulty(Difficulty.hard),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: _TableButton(
                  label: l10n.ranked,
                  fill: isGuest
                      ? _CatalogPageState._felt
                      : _CatalogPageState._accent,
                  textColor: isGuest
                      ? _CatalogPageState._onDark
                      : _CatalogPageState._onAccent,
                  outlined: isGuest,
                  minWidth: 192,
                  onTap: onRanked,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: _TableButton(
                  label: l10n.quickMatch,
                  fill: _CatalogPageState._accent,
                  textColor: _CatalogPageState._onAccent,
                  minWidth: 192,
                  onTap: onQuickMatch,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: _TableButton(
                  label: l10n.playStickPull,
                  fill: _CatalogPageState._felt,
                  textColor: _CatalogPageState._onDark,
                  outlined: true,
                  minWidth: 192,
                  onTap: onPlay,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: Opacity(
                  opacity: createEnabled ? 1 : 0.4,
                  child: _TableButton(
                    label: l10n.createStickPullRoom,
                    fill: _CatalogPageState._felt,
                    textColor: _CatalogPageState._onDark,
                    outlined: true,
                    minWidth: 192,
                    onTap: createEnabled ? onCreateRoom : () {},
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

class _PrivateCtaBand extends StatelessWidget {
  const _PrivateCtaBand({
    required this.l10n,
    required this.createEnabled,
    required this.onCreateRoom,
    required this.onJoinByCode,
  });

  final AppLocalizations l10n;
  final bool createEnabled;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinByCode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: _CatalogPageState._surround),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: createEnabled ? 1 : 0.4,
              child: _TableButton(
                label: l10n.createRoom,
                fill: _CatalogPageState._surround,
                textColor: _CatalogPageState._onDark,
                outlined: true,
                onTap: createEnabled ? onCreateRoom : () {},
              ),
            ),
            const SizedBox(height: 16),
            _TableButton(
              label: l10n.joinByCode,
              fill: _CatalogPageState._surround,
              textColor: _CatalogPageState._onDark,
              outlined: true,
              onTap: onJoinByCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? _CatalogPageState._onAccent
              : _CatalogPageState._onDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: _CatalogPageState._accent,
      backgroundColor: Colors.transparent,
      side: selected
          ? BorderSide.none
          : const BorderSide(color: _CatalogPageState._onDark, width: 1),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.title, required this.badge});

  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: '$title, $badge',
      child: SizedBox(
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _CatalogPageState._surround,
            border: Border.all(
              color: _CatalogPageState._onDark.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: 0.7,
                    child: Text(title, style: _CatalogPageState._label),
                  ),
                ),
                Text(badge, style: _CatalogPageState._label),
              ],
            ),
          ),
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
    required this.onTap,
    this.minWidth = 48,
    this.outlined = false,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final VoidCallback onTap;
  final double minWidth;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.transparent : fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: outlined
            ? const BorderSide(color: _CatalogPageState._onDark)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
