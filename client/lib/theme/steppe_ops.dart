import 'package:flutter/material.dart';

/// Steppe Ops — PUBG-like lobby chrome for Nomad Games (menu / splash).
abstract final class SteppeOps {
  static const Color voidBg = Color(0xFF0E1410);
  static const Color panel = Color(0xCC121A16);
  static const Color panelSolid = Color(0xFF1A2420);
  static const Color mist = Color(0xFFE8EDE6);
  static const Color mistMuted = Color(0xB3E8EDE6);
  static const Color accent = Color(0xFFC4A35A);
  static const Color onAccent = Color(0xFF0E1410);
  static const Color danger = Color(0xFFB83A2F);
  static const Color felt = Color(0xFF1B6B3A);
  static const Color horizonWarm = Color(0xFF3A2A18);
  static const Color skyCool = Color(0xFF1A2830);
  static const Color rim = Color(0x66C4A35A);

  static const TextStyle brand = TextStyle(
    color: mist,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    height: 1.15,
  );

  static const TextStyle heading = TextStyle(
    color: mist,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.2,
  );

  static const TextStyle label = TextStyle(
    color: mist,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    height: 1.2,
  );

  static const TextStyle labelMuted = TextStyle(
    color: mistMuted,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.2,
  );

  static const TextStyle cta = TextStyle(
    color: onAccent,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    height: 1.1,
  );

  static ThemeData theme() {
    final ColorScheme scheme = ColorScheme.dark(
      surface: voidBg,
      primary: accent,
      onPrimary: onAccent,
      secondary: felt,
      onSecondary: mist,
      error: danger,
      onSurface: mist,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: voidBg,
      textTheme: const TextTheme(
        headlineMedium: brand,
        titleLarge: heading,
        titleMedium: label,
        bodyMedium: label,
        labelLarge: cta,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
