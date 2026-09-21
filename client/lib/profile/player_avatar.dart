import 'dart:io';

import 'package:client/profile/avatar_assets.dart';
import 'package:client/theme/steppe_ops.dart';
import 'package:flutter/material.dart';

/// Renders allow-listed asset preset or a local custom file.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.presetId,
    this.customPath,
    this.size = 112,
    this.useCustom = false,
  });

  final String presetId;
  final String? customPath;
  final double size;
  final bool useCustom;

  @override
  Widget build(BuildContext context) {
    final bool showCustom =
        useCustom && customPath != null && customPath!.isNotEmpty;
    final Widget image = showCustom
        ? Image.file(
            File(customPath!),
            key: ValueKey<String>('custom:$customPath'),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          )
        : Image.asset(
            avatarAssetPath(presetId),
            key: ValueKey<String>(presetId),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: false,
            errorBuilder: (_, _, _) => _fallback(),
          );
    return SizedBox(width: size, height: size, child: image);
  }

  Widget _fallback() => ColoredBox(
        color: SteppeOps.felt,
        child: SizedBox(width: size, height: size),
      );
}
