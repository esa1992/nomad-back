import 'package:client/theme/steppe_ops.dart';
import 'package:flutter/material.dart';
import 'package:client/l10n/app_localizations.dart';
import 'package:client/profile/avatar_assets.dart';

/// Catalog header entry to `/profile` (D-74).
class AvatarChip extends StatelessWidget {
  const AvatarChip({
    super.key,
    this.avatarPreset = kDefaultAvatarPreset,
    this.onTap,
  });

  final String avatarPreset;
  final VoidCallback? onTap;

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
                  color: SteppeOps.panelSolid,
                  border: Border.all(
                    color: SteppeOps.accent.withValues(alpha: 0.7),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: Image.asset(
                      avatarAssetPath(avatarPreset),
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: SteppeOps.felt),
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
