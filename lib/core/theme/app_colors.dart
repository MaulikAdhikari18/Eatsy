import 'package:flutter/material.dart';

/// Semantic colors that change between light and dark mode.
///
/// Screens should read colors from here (via `context.appColors.xxx`)
/// instead of hardcoding `Color(0xFF...)` values. That's what makes
/// dark mode actually work everywhere automatically.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface; // card / sheet background
  final Color surfaceVariant; // subtle tinted surfaces (chip tracks, rings)
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color cardShadow;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.cardShadow,
  });

  static const light = AppColors(
    background: Color(0xFFF9F9F9),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF0F0F0),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF555555),
    textMuted: Color(0xFF9E9E9E),
    divider: Color(0xFFEEEEEE),
    cardShadow: Color(0x0D000000), // ~5% black
  );

  static const dark = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceVariant: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFF2F2F2),
    textSecondary: Color(0xFFB5B5B5),
    textMuted: Color(0xFF7D7D7D),
    divider: Color(0xFF2C2C2C),
    cardShadow: Color(0x40000000), // ~25% black, needs to read on dark bg
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? cardShadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}

/// Shortcut so screens can write `context.appColors.background`
/// instead of `Theme.of(context).extension<AppColors>()!.background`.
extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}