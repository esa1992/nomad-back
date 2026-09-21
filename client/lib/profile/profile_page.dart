import 'dart:async';

import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/profile/avatar_assets.dart';
import 'package:client/profile/bind_sheet.dart';
import 'package:client/profile/custom_avatar_store.dart';
import 'package:client/profile/player_avatar.dart';
import 'package:client/profile/sign_in_sheet.dart';
import 'package:client/shop/shop_page.dart';
import 'package:client/theme/steppe_backdrop.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:client/theme/steppe_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full guest profile UI (PROF-01…03, D-74…D-77, RESEARCH Q2 LOCKED).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  PlayerProfile? _profile;
  String _selectedPreset = kDefaultAvatarPreset;
  bool _useCustom = false;
  String? _customPath;
  bool _savedUseCustom = false;
  String? _savedCustomPath;
  bool _loading = true;
  bool _error = false;
  bool _saving = false;
  bool _saveError = false;
  bool _pickError = false;
  bool _isGuest = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _saveError = false;
      _pickError = false;
    });
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
        _profile = profile;
        _selectedPreset = profile.avatarPreset;
        _useCustom = customActive;
        _customPath = customPath;
        _savedUseCustom = customActive;
        _savedCustomPath = customPath;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = null;
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _openBind() async {
    await showBindSheet(context, markPromptSeen: false);
    if (!mounted) {
      return;
    }
    final bool guest = await ref.read(sessionStoreProvider).isGuest();
    setState(() => _isGuest = guest);
    await _load();
  }

  Future<void> _openSignIn() async {
    final bool signedIn = await showSignInSheet(context);
    if (!mounted) {
      return;
    }
    if (signedIn) {
      final bool guest = await ref.read(sessionStoreProvider).isGuest();
      setState(() => _isGuest = guest);
      await _load();
    }
  }

  Future<void> _logOut() async {
    final bool done = await showLogOutConfirm(context);
    if (!mounted || !done) {
      return;
    }
    context.go('/');
  }

  bool get _dirty {
    if (_profile == null) {
      return false;
    }
    if (_useCustom != _savedUseCustom) {
      return true;
    }
    if (_useCustom) {
      return _customPath != _savedCustomPath;
    }
    return _selectedPreset != _profile!.avatarPreset;
  }

  Future<void> _pickCustom() async {
    setState(() => _pickError = false);
    try {
      final String? path =
          await ref.read(customAvatarStoreProvider).pickFromGallery();
      if (!mounted) {
        return;
      }
      if (path == null) {
        return;
      }
      setState(() {
        _customPath = path;
        _useCustom = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _pickError = true);
    }
  }

  Future<void> _saveAvatar() async {
    if (!_dirty || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = false;
    });
    try {
      final CustomAvatarStore customs = ref.read(customAvatarStoreProvider);
      if (_useCustom) {
        if (_customPath == null || _customPath!.isEmpty) {
          throw StateError('custom path missing');
        }
        await customs.setActive(true);
        if (!mounted) {
          return;
        }
        setState(() {
          _savedUseCustom = true;
          _savedCustomPath = _customPath;
          _saving = false;
          _saveError = false;
        });
        return;
      }
      if (!kAvatarPresets.contains(_selectedPreset)) {
        throw StateError('bad preset');
      }
      await customs.setActive(false);
      final PlayerProfile updated =
          await ref.read(nomadApiProvider).putAvatar(_selectedPreset);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = updated;
        _selectedPreset = updated.avatarPreset;
        _useCustom = false;
        _savedUseCustom = false;
        _saving = false;
        _saveError = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saveError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: SteppeOps.voidBg,
      body: SteppeBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SteppeGhostButton(
                      label: l10n.backToCatalog,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      minWidth: 88,
                    ),
                    const Spacer(),
                    Text(
                      l10n.profileTitle.toUpperCase(),
                      style: SteppeOps.heading,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildBody(l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SteppeOps.accent),
      );
    }
    if (_error || _profile == null) {
      return SteppeBanner(
        message: '${l10n.errorProfileTitle}\n${l10n.errorProfileBody}',
        retryLabel: l10n.retry,
        onRetry: _load,
      );
    }
    final PlayerProfile profile = _profile!;
    final GameStats stickPull = profile.games['stickPull'] ??
        const GameStats(
          matches: 0,
          wins: 0,
          losses: 0,
          draws: 0,
          noMatchesYet: true,
        );
    final GameStats alchiki = profile.games['alchiki'] ??
        GameStats(
          matches: profile.matches,
          wins: profile.wins,
          losses: profile.losses,
          draws: 0,
          noMatchesYet: profile.matches == 0,
        );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: SteppeOps.accent.withValues(alpha: 0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SteppeOps.accent.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: PlayerAvatar(
                presetId: _selectedPreset,
                customPath: _customPath,
                useCustom: _useCustom,
                size: 120,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            (profile.displayName.isEmpty
                    ? l10n.guestDisplay
                    : profile.displayName)
                .toUpperCase(),
            style: SteppeOps.heading.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          Text(
            profile.subtitle,
            style: SteppeOps.labelMuted,
            textAlign: TextAlign.center,
          ),
          if (_isGuest) ...[
            const SizedBox(height: 16),
            Text(
              l10n.guestBindHelper,
              style: SteppeOps.labelMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SteppePlayButton(label: l10n.bindAccount, onTap: _openBind),
            const SizedBox(height: 12),
            SteppeGhostButton(label: l10n.signIn, onTap: _openSignIn),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              l10n.boundLabel.toUpperCase(),
              style: SteppeOps.label.copyWith(color: SteppeOps.accent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SteppePlayButton(
              label: l10n.boards,
              onTap: () => context.push('/boards'),
            ),
            const SizedBox(height: 12),
            SteppeGhostButton(label: l10n.logOut, onTap: _logOut),
          ],
          const SizedBox(height: 24),
          HudPanel(
            child: Column(
              children: [
                Text(l10n.statRating, style: SteppeOps.labelMuted),
                Text(
                  '${profile.rating}',
                  style: SteppeOps.brand.copyWith(fontSize: 36),
                ),
                Text(
                  '${l10n.statBestRating} ${profile.bestRating}',
                  style: SteppeOps.labelMuted,
                ),
                const SizedBox(height: 12),
                Text(l10n.levelLabel(profile.level), style: SteppeOps.label),
                const SizedBox(height: 8),
                _XpBar(xp: profile.xp, xpToNext: profile.xpToNext),
                const SizedBox(height: 8),
                Text(
                  l10n.xpProgress(profile.xp, profile.xp + profile.xpToNext),
                  style: SteppeOps.labelMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HudPanel(
            child: Column(
              children: [
                _MetricRow(label: l10n.statMatches, value: '${profile.matches}'),
                _MetricRow(label: l10n.statWins, value: '${profile.wins}'),
                _MetricRow(label: l10n.statLosses, value: '${profile.losses}'),
                _MetricRow(
                  label: l10n.statWinRate,
                  value: l10n.statWinRateValue((profile.winRate * 100).round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.cosmeticsSection.toUpperCase(), style: SteppeOps.heading),
          const SizedBox(height: 8),
          HudPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _cosmeticsLines(l10n, profile.cosmetics),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.statsAlchiki.toUpperCase(), style: SteppeOps.heading),
          const SizedBox(height: 8),
          HudPanel(
            child: Column(
              children: [
                _MetricRow(label: l10n.statMatches, value: '${alchiki.matches}'),
                _MetricRow(label: l10n.statWins, value: '${alchiki.wins}'),
                _MetricRow(label: l10n.statLosses, value: '${alchiki.losses}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.statsStickPull.toUpperCase(), style: SteppeOps.heading),
          const SizedBox(height: 8),
          HudPanel(
            child: stickPull.noMatchesYet || stickPull.matches == 0
                ? Text(l10n.noMatchesYet, style: SteppeOps.label)
                : Column(
                    children: [
                      _MetricRow(
                        label: l10n.statMatches,
                        value: '${stickPull.matches}',
                      ),
                      _MetricRow(
                        label: l10n.statWins,
                        value: '${stickPull.wins}',
                      ),
                      _MetricRow(
                        label: l10n.statLosses,
                        value: '${stickPull.losses}',
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text(l10n.avatarSection.toUpperCase(), style: SteppeOps.heading),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 56,
            ),
            itemCount: kAvatarPresets.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == kAvatarPresets.length) {
                final bool selected = _useCustom;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('avatar_preset_custom'),
                    onTap: () => unawaited(_pickCustom()),
                    child: Semantics(
                      label: l10n.avatarCustomA11y,
                      button: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: SteppeOps.panelSolid,
                          border: Border.all(
                            color: selected
                                ? SteppeOps.accent
                                : SteppeOps.mist.withValues(alpha: 0.35),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: _customPath != null
                            ? Padding(
                                padding: const EdgeInsets.all(4),
                                child: PlayerAvatar(
                                  presetId: _selectedPreset,
                                  customPath: _customPath,
                                  useCustom: true,
                                  size: 48,
                                ),
                              )
                            : const Icon(
                                Icons.add,
                                color: SteppeOps.accent,
                                size: 28,
                              ),
                      ),
                    ),
                  ),
                );
              }
              final String id = kAvatarPresets[index];
              final bool selected = !_useCustom && id == _selectedPreset;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('avatar_preset_$id'),
                  onTap: () => setState(() {
                    _useCustom = false;
                    _selectedPreset = id;
                  }),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SteppeOps.panelSolid,
                      border: Border.all(
                        color: selected
                            ? SteppeOps.accent
                            : SteppeOps.mist.withValues(alpha: 0.35),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: PlayerAvatar(presetId: id, size: 48),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_pickError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: SteppeOps.danger),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(l10n.errorAvatarPick, style: SteppeOps.label),
                ),
              ),
            ),
          if (_saveError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: SteppeOps.danger),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(l10n.errorAvatarSave, style: SteppeOps.label),
                ),
              ),
            ),
          Opacity(
            opacity: _dirty && !_saving ? 1 : 0.45,
            child: SteppePlayButton(
              label: l10n.saveAvatar,
              onTap: _dirty && !_saving ? _saveAvatar : () {},
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _cosmeticsLines(
    AppLocalizations l10n,
    Map<String, String> cosmetics,
  ) {
    if (cosmetics.isEmpty || _isDefaultLoadout(cosmetics)) {
      return <Widget>[Text(l10n.cosmeticsDefault, style: SteppeOps.label)];
    }
    final List<Widget> lines = <Widget>[];
    for (final MapEntry<String, String> entry in cosmetics.entries) {
      final String name = skuDisplayName(l10n, _nameKeyForSkuId(entry.value));
      lines.add(Text(name, style: SteppeOps.label));
    }
    if (lines.isEmpty) {
      return <Widget>[Text(l10n.cosmeticsDefault, style: SteppeOps.label)];
    }
    return lines;
  }

  bool _isDefaultLoadout(Map<String, String> cosmetics) {
    if (cosmetics.isEmpty) {
      return true;
    }
    return cosmetics.values.every((String id) => id.endsWith('_default'));
  }

  String _nameKeyForSkuId(String skuId) {
    return switch (skuId) {
      'saka_color_default' => 'skuSakaColorDefault',
      'saka_color_gold' => 'skuSakaColorGold',
      'saka_color_neon' => 'skuSakaColorNeon',
      'saka_material_default' => 'skuSakaMaterialDefault',
      'saka_material_ice' => 'skuSakaMaterialIce',
      'saka_material_fire' => 'skuSakaMaterialFire',
      'saka_ornament_default' => 'skuSakaOrnamentDefault',
      'saka_ornament_space' => 'skuSakaOrnamentSpace',
      'saka_ornament_knot' => 'skuSakaOrnamentKnot',
      'trail_default' => 'skuTrailDefault',
      'trail_gold' => 'skuTrailGold',
      'table_fx_default' => 'skuTableFxDefault',
      'table_fx_neon' => 'skuTableFxNeon',
      'victory_default' => 'skuVictoryDefault',
      'victory_fire' => 'skuVictoryFire',
      'stick_pull_default' => 'skuStickPullDefault',
      'stick_pull_ice' => 'skuStickPullIce',
      _ => skuId,
    };
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.xp, required this.xpToNext});

  final int xp;
  final int xpToNext;

  @override
  Widget build(BuildContext context) {
    final int span = xp + xpToNext;
    final double progress = span <= 0 ? 1.0 : (xp / span).clamp(0.0, 1.0);
    return SizedBox(
      height: 10,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: SteppeOps.panelSolid),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: const ColoredBox(color: SteppeOps.accent),
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: SteppeOps.label),
          const Spacer(),
          Text(value, style: SteppeOps.label.copyWith(color: SteppeOps.accent)),
        ],
      ),
    );
  }
}
