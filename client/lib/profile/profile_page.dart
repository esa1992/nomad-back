import 'package:client/l10n/app_localizations.dart';
import 'package:client/platform/api/nomad_api.dart';
import 'package:client/platform/auth/session_store.dart';
import 'package:client/profile/avatar_assets.dart';
import 'package:client/profile/bind_sheet.dart';
import 'package:client/profile/sign_in_sheet.dart';
import 'package:client/shop/shop_page.dart';
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
  static const Color _wood = Color(0xFF241810);
  static const Color _cream = Color(0xFFF4E8C8);
  static const Color _accent = Color(0xFFF0B429);
  static const Color _onAccent = Color(0xFF241810);
  static const Color _destructive = Color(0xFFC43C2C);
  static const Color _xpTrack = Color(0xFF3A2A1C);

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

  PlayerProfile? _profile;
  String _selectedPreset = kDefaultAvatarPreset;
  bool _loading = true;
  bool _error = false;
  bool _saving = false;
  bool _saveError = false;
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
    });
    try {
      final bool guest = await ref.read(sessionStoreProvider).isGuest();
      final PlayerProfile profile =
          await ref.read(nomadApiProvider).fetchProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _isGuest = guest;
        _profile = profile;
        _selectedPreset = profile.avatarPreset;
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

  bool get _dirty =>
      _profile != null && _selectedPreset != _profile!.avatarPreset;

  Future<void> _saveAvatar() async {
    if (!_dirty || _saving) {
      return;
    }
    if (!kAvatarPresets.contains(_selectedPreset)) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = false;
    });
    try {
      final PlayerProfile updated =
          await ref.read(nomadApiProvider).putAvatar(_selectedPreset);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = updated;
        _selectedPreset = updated.avatarPreset;
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
      backgroundColor: _wood,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _OutlineButton(
                    label: l10n.backToCatalog,
                    onTap: () => context.go('/'),
                  ),
                  const Spacer(),
                  Text(l10n.profileTitle, style: _heading),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildBody(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }
    if (_error || _profile == null) {
      return _MessagePanel(
        title: l10n.errorProfileTitle,
        body: l10n.errorProfileBody,
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
            child: ClipOval(
              child: Image.asset(
                avatarAssetPath(_selectedPreset),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF1B6B3A),
                  child: SizedBox(width: 64, height: 64),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.displayName.isEmpty
                ? l10n.guestDisplay
                : profile.displayName,
            style: _heading,
            textAlign: TextAlign.center,
          ),
          Text(
            profile.subtitle,
            style: _label,
            textAlign: TextAlign.center,
          ),
          if (_isGuest) ...[
            const SizedBox(height: 16),
            Text(
              l10n.guestBindHelper,
              style: _body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _openBind,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _onAccent,
                ),
                child: Text(
                  l10n.bindAccount,
                  style: _label.copyWith(color: _onAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _openSignIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cream,
                  side: const BorderSide(color: _cream),
                ),
                child: Text(l10n.signIn, style: _label),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              l10n.boundLabel,
              style: _label,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => context.push('/boards'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _onAccent,
                ),
                child: Text(
                  l10n.boards,
                  style: _label.copyWith(color: _onAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _logOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cream,
                  side: const BorderSide(color: _cream),
                ),
                child: Text(l10n.logOut, style: _label),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(l10n.statRating, style: _label, textAlign: TextAlign.center),
          Text(
            '${profile.rating}',
            style: _display,
            textAlign: TextAlign.center,
          ),
          Text(
            '${l10n.statBestRating} ${profile.bestRating}',
            style: _label,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(l10n.levelLabel(profile.level), style: _label),
          const SizedBox(height: 8),
          _XpBar(
            xp: profile.xp,
            xpToNext: profile.xpToNext,
            track: _xpTrack,
            fill: _accent,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.xpProgress(
              profile.xp,
              profile.xp + profile.xpToNext,
            ),
            style: _label,
          ),
          const SizedBox(height: 16),
          _MetricRow(label: l10n.statMatches, value: '${profile.matches}'),
          _MetricRow(label: l10n.statWins, value: '${profile.wins}'),
          _MetricRow(label: l10n.statLosses, value: '${profile.losses}'),
          _MetricRow(
            label: l10n.statWinRate,
            value: l10n.statWinRateValue((profile.winRate * 100).round()),
          ),
          const SizedBox(height: 24),
          Text(l10n.cosmeticsSection, style: _heading),
          const SizedBox(height: 8),
          ..._cosmeticsLines(l10n, profile.cosmetics),
          const SizedBox(height: 24),
          Text(l10n.statsAlchiki, style: _heading),
          const SizedBox(height: 8),
          _MetricRow(label: l10n.statMatches, value: '${alchiki.matches}'),
          _MetricRow(label: l10n.statWins, value: '${alchiki.wins}'),
          _MetricRow(label: l10n.statLosses, value: '${alchiki.losses}'),
          const SizedBox(height: 24),
          Text(l10n.statsStickPull, style: _heading),
          const SizedBox(height: 8),
          if (stickPull.noMatchesYet || stickPull.matches == 0)
            Text(l10n.noMatchesYet, style: _label)
          else ...[
            _MetricRow(label: l10n.statMatches, value: '${stickPull.matches}'),
            _MetricRow(label: l10n.statWins, value: '${stickPull.wins}'),
            _MetricRow(label: l10n.statLosses, value: '${stickPull.losses}'),
          ],
          const SizedBox(height: 24),
          Text(l10n.avatarSection, style: _heading),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 48,
            ),
            itemCount: kAvatarPresets.length,
            itemBuilder: (BuildContext context, int index) {
              final String id = kAvatarPresets[index];
              final bool selected = id == _selectedPreset;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('avatar_preset_$id'),
                  onTap: () => setState(() => _selectedPreset = id),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected ? _accent : _wood,
                        border: Border.all(
                          color: selected ? _accent : _cream,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: Image.asset(
                            avatarAssetPath(id),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: selected ? _onAccent : const Color(0xFF1B6B3A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_saveError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: _destructive, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(l10n.errorAvatarSave, style: _body),
                ),
              ),
            ),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _dirty && !_saving ? _saveAvatar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                foregroundColor: _onAccent,
                disabledForegroundColor: _onAccent.withValues(alpha: 0.7),
              ),
              child: Text(l10n.saveAvatar, style: _label.copyWith(color: _onAccent)),
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
      return <Widget>[Text(l10n.cosmeticsDefault, style: _body)];
    }
    final List<Widget> lines = <Widget>[];
    for (final MapEntry<String, String> entry in cosmetics.entries) {
      final String name = skuDisplayName(l10n, _nameKeyForSkuId(entry.value));
      lines.add(Text(name, style: _body));
    }
    if (lines.isEmpty) {
      return <Widget>[Text(l10n.cosmeticsDefault, style: _body)];
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
  const _XpBar({
    required this.xp,
    required this.xpToNext,
    required this.track,
    required this.fill,
  });

  final int xp;
  final int xpToNext;
  final Color track;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final int span = xp + xpToNext;
    final double progress =
        span <= 0 ? 1.0 : (xp / span).clamp(0.0, 1.0);
    return SizedBox(
      height: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(color: track),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: ColoredBox(color: fill),
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

  static const TextStyle _style = TextStyle(
    color: Color(0xFFF4E8C8),
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: _style),
          const SizedBox(width: 4),
          const Spacer(),
          Text(value, style: _style),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF4E8C8),
          side: const BorderSide(color: Color(0xFFF4E8C8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String? body;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFF4E8C8),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            style: const TextStyle(
              color: Color(0xFFF4E8C8),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (retryLabel != null && onRetry != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF4E8C8),
                side: const BorderSide(color: Color(0xFFC43C2C)),
              ),
              child: Text(retryLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
