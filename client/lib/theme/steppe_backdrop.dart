import 'package:flutter/material.dart';

/// Full-bleed steppe lobby backdrop: day art 09:00–18:00 local, night otherwise.
class SteppeBackdrop extends StatelessWidget {
  const SteppeBackdrop({super.key, this.child, this.now});

  final Widget? child;

  /// Override clock for tests; defaults to device local time.
  final DateTime? now;

  static const String dayAsset = 'assets/backgrounds/steppe_day.png';
  static const String nightAsset = 'assets/backgrounds/steppe_night.png';

  /// Inclusive start 09:00, exclusive end 18:00 (local).
  static bool isDaytime([DateTime? instant]) {
    final DateTime t = instant ?? DateTime.now();
    final int minutes = t.hour * 60 + t.minute;
    return minutes >= 9 * 60 && minutes < 18 * 60;
  }

  static String assetFor([DateTime? instant]) =>
      isDaytime(instant) ? dayAsset : nightAsset;

  @override
  Widget build(BuildContext context) {
    final String asset = assetFor(now);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: const Color(0xFF0E1410),
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF0E1410)),
          ),
        ),
        // Keep HUD readable over bright sky / horizon
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x330E1410),
                Color(0x000E1410),
                Color(0x990E1410),
              ],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.1),
              radius: 1.2,
              colors: [Color(0x000E1410), Color(0x660E1410)],
              stops: [0.4, 1],
            ),
          ),
        ),
        if (child case final Widget content) content,
      ],
    );
  }
}
