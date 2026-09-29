import 'dart:async';

import 'package:client/catalog/catalog_models.dart';
import 'package:client/catalog/soft_lock_sheet.dart';
import 'package:client/howto/howto_seen_store.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/platform/locale_controller.dart';
import 'package:client/profile/avatar_assets.dart';
import 'package:client/profile/custom_avatar_store.dart';
import 'package:client/profile/player_avatar.dart';
import 'package:client/shop/wallet_chip.dart';
import 'package:client/theme/steppe_backdrop.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:client/theme/steppe_widgets.dart';
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
  Difficulty _difficulty = Difficulty.easy;
  Difficulty _stickPullDifficulty = Difficulty.easy;
  CatalogSnapshot? _snapshot;
  bool _loading = true;
  bool _error = false;
  int? _apiMs;
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
  String _displayName = '';
  bool _useCustomAvatar = false;
  String? _customAvatarPath;

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
      _apiMs = null;
    });
    final NomadApi api = ref.read(nomadApiProvider);
    final bool guest = await ref.read(sessionStoreProvider).isGuest();

    // Fire health RTT early so lobby spinner can show real backend ms.
    unawaited(() async {
      final int ms = await api.probeHealthMs();
      if (mounted && _loading) {
        setState(() => _apiMs = ms);
      }
    }());

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
      final CustomAvatarStore customs = ref.read(customAvatarStoreProvider);
      final bool customActive = await customs.isActive();
      final String? customPath = await customs.filePath();
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarPreset = profile!.avatarPreset;
        _displayName = profile!.displayName;
        _useCustomAvatar = customActive;
        _customAvatarPath = customPath;
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

  Future<void> _reloadIdentity() async {
    try {
      final bool guest = await ref.read(sessionStoreProvider).isGuest();
      final PlayerProfile profile =
          await ref.read(nomadApiProvider).fetchProfile();
      final CustomAvatarStore customs = ref.read(customAvatarStoreProvider);
      final bool customActive = await customs.isActive();
      final String? customPath = await customs.filePath();
      if (!mounted) {
        return;
      }
      setState(() {
        _isGuest = guest;
        _avatarPreset = profile.avatarPreset;
        _displayName = profile.displayName;
        _useCustomAvatar = customActive;
        _customAvatarPath = customPath;
      });
    } catch (_) {
      // Keep last known identity on transient errors.
    }
  }

  Future<void> _openProfile() async {
    await context.push('/profile');
    if (!mounted) {
      return;
    }
    await _reloadIdentity();
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
      backgroundColor: SteppeOps.voidBg,
      body: SteppeBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _LobbyTopBar(
                coins: _coins,
                gems: _gems,
                shopLabel: l10n.shop,
                boardsLabel: l10n.boards,
                languageCode: enSelected ? 'en' : 'ru',
                langEn: l10n.langEn,
                langRu: l10n.langRu,
                showNavLinks: !_loading,
                onShop: () => context.push('/shop'),
                onBoards: () => unawaited(_onBoardsTap()),
                onLanguage: (String code) => ref
                    .read(localeOverrideProvider.notifier)
                    .setOverride(code),
              ),
              Expanded(
                child: _loading
                    ? SteppeLoading(
                        label: _apiMs == null
                            ? l10n.checkingApi
                            : '${l10n.apiLatencyMs(_apiMs!)}\n${l10n.loadingCatalog}',
                      )
                    : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LobbyHero(
                        avatarPreset: _avatarPreset,
                        customPath: _customAvatarPath,
                        useCustom: _useCustomAvatar,
                        displayName: _displayName,
                        isGuest: _isGuest,
                        guestLabel: l10n.guestDisplay,
                        onTap: () => unawaited(_openProfile()),
                      ),
                      const SizedBox(height: 16),
                      if (_walletError) ...[
                        SteppeBanner(
                          message: l10n.errorWallet,
                          retryLabel: l10n.retry,
                          onRetry: () => unawaited(_reloadWallet()),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_error)
                        SteppeBanner(
                          message: l10n.errorCatalog,
                          retryLabel: l10n.retry,
                          onRetry: _load,
                        )
                      else if (tiles.isEmpty)
                        SteppeBanner(
                          message: l10n.emptyCatalogTitle,
                          retryLabel: l10n.retry,
                          onRetry: _load,
                        )
                      else ...[
                        if (_createError) ...[
                          SteppeBanner(
                            message: l10n.errorRoomCreate,
                            retryLabel: l10n.retry,
                            onRetry: () => unawaited(_createRoom()),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_stickPullCreateError) ...[
                          SteppeBanner(
                            message: l10n.errorRoomCreate,
                            retryLabel: l10n.retry,
                            onRetry: () => unawaited(_createStickPullRoom()),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_quickMatchError) ...[
                          SteppeBanner(
                            message: l10n.errorQuickMatch,
                            retryLabel: l10n.retry,
                            onRetry: () {
                              setState(() => _quickMatchError = false);
                              unawaited(_quickMatch());
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_stickPullQuickMatchError) ...[
                          SteppeBanner(
                            message: l10n.errorQuickMatch,
                            retryLabel: l10n.retry,
                            onRetry: () {
                              setState(() => _stickPullQuickMatchError = false);
                              unawaited(_quickMatchStickPull());
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        for (final CatalogTile tile in tiles) ...[
                          if (tile.id == 'alchiki' &&
                              tile.availability ==
                                  CatalogAvailability.playable)
                            _GameModePanel(
                              title: l10n.alchikiTitle,
                              accent: true,
                              difficulty: _difficulty,
                              isGuest: _isGuest,
                              l10n: l10n,
                              playLabel: l10n.playAlchiki,
                              createEnabled: !_creating && !_createError,
                              onCreate: () => unawaited(_createRoom()),
                              onJoin: () => context.go('/join'),
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
                            )
                          else if (tile.id == 'stick_pull' &&
                              tile.availability ==
                                  CatalogAvailability.playable)
                            _GameModePanel(
                              title: l10n.stickPullTitle,
                              accent: false,
                              difficulty: _stickPullDifficulty,
                              isGuest: _isGuest,
                              l10n: l10n,
                              playLabel: l10n.playStickPull,
                              createEnabled: !_creatingStickPull &&
                                  !_stickPullCreateError,
                              onCreate: () =>
                                  unawaited(_createStickPullRoom()),
                              onJoin: () => context.go('/join'),
                              onDifficulty: (Difficulty next) {
                                setState(() => _stickPullDifficulty = next);
                                ref
                                    .read(
                                      lastStickPullBotDifficultyProvider
                                          .notifier,
                                    )
                                    .setDifficulty(next.query);
                              },
                              onRanked: () =>
                                  unawaited(_onRankedTap(game: 'STICK_PULL')),
                              onQuickMatch: () =>
                                  unawaited(_quickMatchStickPull()),
                              onPlay: () => unawaited(_playStickPull()),
                            )
                          else
                            _ComingSoonTile(
                              title: tile.id == 'stick_pull'
                                  ? l10n.stickPullTitle
                                  : l10n.moreGamesTitle,
                              badge: l10n.comingSoon,
                            ),
                          if (tile != tiles.last) const SizedBox(height: 20),
                        ],
                      ],
                    ],
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

class _LobbyHero extends StatelessWidget {
  const _LobbyHero({
    required this.avatarPreset,
    required this.displayName,
    required this.isGuest,
    required this.guestLabel,
    required this.onTap,
    this.customPath,
    this.useCustom = false,
  });

  final String avatarPreset;
  final String? customPath;
  final bool useCustom;
  final String displayName;
  final bool isGuest;
  final String guestLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name =
        displayName.isEmpty ? guestLabel : displayName;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 148,
          child: Stack(
            children: [
              Align(
                alignment: const Alignment(-0.55, 0.85),
                child: Container(
                  width: 140,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: SteppeOps.accent.withValues(alpha: 0.22),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 120,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned(
                          bottom: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: SteppeOps.accent.withValues(alpha: 0.55),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: PlayerAvatar(
                              presetId: avatarPreset,
                              customPath: customPath,
                              useCustom: useCustom,
                              size: 112,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            name.toUpperCase(),
                            style: SteppeOps.heading.copyWith(fontSize: 20),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isGuest ? 'GUEST · CASUAL' : 'BOUND · RANKED READY',
                            style: SteppeOps.labelMuted.copyWith(
                              letterSpacing: 1.2,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 72,
                            height: 3,
                            color: SteppeOps.accent.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LobbyTopBar extends StatelessWidget {
  const _LobbyTopBar({
    required this.coins,
    required this.gems,
    required this.shopLabel,
    required this.boardsLabel,
    required this.languageCode,
    required this.langEn,
    required this.langRu,
    required this.showNavLinks,
    required this.onShop,
    required this.onBoards,
    required this.onLanguage,
  });

  final int? coins;
  final int? gems;
  final String shopLabel;
  final String boardsLabel;
  final String languageCode;
  final String langEn;
  final String langRu;
  final bool showNavLinks;
  final VoidCallback onShop;
  final VoidCallback onBoards;
  final ValueChanged<String> onLanguage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          if (coins != null && gems != null) ...[
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: WalletChip(coins: coins!, gems: gems!, compact: true),
              ),
            ),
          ] else
            const Spacer(),
          if (showNavLinks) ...[
            _HudLink(label: shopLabel, onTap: onShop),
            const SizedBox(width: 4),
            _HudLink(label: boardsLabel, onTap: onBoards),
            const SizedBox(width: 4),
          ],
          _LanguageMenu(
            languageCode: languageCode,
            langEn: langEn,
            langRu: langRu,
            onLanguage: onLanguage,
          ),
        ],
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.languageCode,
    required this.langEn,
    required this.langRu,
    required this.onLanguage,
  });

  final String languageCode;
  final String langEn;
  final String langRu;
  final ValueChanged<String> onLanguage;

  @override
  Widget build(BuildContext context) {
    final String current = languageCode == 'ru' ? langRu : langEn;
    return PopupMenuButton<String>(
      tooltip: current,
      onSelected: onLanguage,
      color: SteppeOps.panelSolid,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'en',
          child: Text(
            langEn,
            style: SteppeOps.label.copyWith(
              color: languageCode == 'en' ? SteppeOps.accent : SteppeOps.mist,
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'ru',
          child: Text(
            langRu,
            style: SteppeOps.label.copyWith(
              color: languageCode == 'ru' ? SteppeOps.accent : SteppeOps.mist,
            ),
          ),
        ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: SteppeOps.mist.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current.toUpperCase(),
                style: SteppeOps.label.copyWith(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: SteppeOps.accent,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: SteppeOps.mist.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudLink extends StatelessWidget {
  const _HudLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: SteppeOps.mist,
        minimumSize: const Size(40, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        side: BorderSide(color: SteppeOps.mist.withValues(alpha: 0.35)),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(
        label.toUpperCase(),
        style: SteppeOps.label.copyWith(fontSize: 11, letterSpacing: 0.6),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _GameModePanel extends StatelessWidget {
  const _GameModePanel({
    required this.title,
    required this.accent,
    required this.difficulty,
    required this.isGuest,
    required this.l10n,
    required this.playLabel,
    required this.onDifficulty,
    required this.onRanked,
    required this.onQuickMatch,
    required this.onPlay,
    required this.createEnabled,
    required this.onCreate,
    required this.onJoin,
  });

  final String title;
  final bool accent;
  final Difficulty difficulty;
  final bool isGuest;
  final AppLocalizations l10n;
  final String playLabel;
  final ValueChanged<Difficulty> onDifficulty;
  final VoidCallback onRanked;
  final VoidCallback onQuickMatch;
  final VoidCallback onPlay;
  final bool createEnabled;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: HudPanel(
          accentEdge: accent,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    color: accent ? SteppeOps.accent : SteppeOps.felt,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: SteppeOps.heading.copyWith(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SteppeChip(
                    label: l10n.diffEasy,
                    selected: difficulty == Difficulty.easy,
                    onSelected: () => onDifficulty(Difficulty.easy),
                    dense: true,
                  ),
                  SteppeChip(
                    label: l10n.diffNormal,
                    selected: difficulty == Difficulty.normal,
                    onSelected: () => onDifficulty(Difficulty.normal),
                    dense: true,
                  ),
                  SteppeChip(
                    label: l10n.diffHard,
                    selected: difficulty == Difficulty.hard,
                    onSelected: () => onDifficulty(Difficulty.hard),
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SteppePlayButton(
                label: playLabel,
                onTap: onPlay,
                dense: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SteppeGhostButton(
                      label: l10n.quickMatch,
                      onTap: onQuickMatch,
                      filled: true,
                      dense: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SteppeGhostButton(
                      label: l10n.ranked,
                      onTap: onRanked,
                      filled: !isGuest,
                      dense: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SteppeGhostButton(
                      label: l10n.createRoom,
                      onTap: onCreate,
                      enabled: createEnabled,
                      dense: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SteppeGhostButton(
                      label: l10n.joinByCode,
                      onTap: onJoin,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      child: HudPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: 0.65,
                child: Text(title.toUpperCase(), style: SteppeOps.label),
              ),
            ),
            Text(
              badge.toUpperCase(),
              style: SteppeOps.labelMuted.copyWith(
                color: SteppeOps.accent.withValues(alpha: 0.8),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
