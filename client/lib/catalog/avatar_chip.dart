import 'package:client/l10n/app_localizations.dart';
import 'package:client/profile/avatar_assets.dart';
import 'package:flutter/material.dart';

/// Catalog header entry to `/profile` (D-74). Wood chrome like [WalletChip]; not a buy authority.
class AvatarChip extends StatelessWidget {
  const AvatarChip({
    super.key,
    this.avatarPreset = kDefaultAvatarPreset,
    this.onTap,
  });

  final String avatarPreset;
  final VoidCallback? onTap;

  static const Color _wood = Color(0xFF241810);
  static const Color _cream = Color(0xFFF4E8C8);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.openProfileA11y,
      button: true,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _wood,
                  border: Border.all(color: _cream, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ClipOval(
                    child: Image.asset(
                      avatarAssetPath(avatarPreset),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF1B6B3A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
