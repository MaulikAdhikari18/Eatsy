import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Text style helpers for the mono numeral treatment used on every
/// number in the app (calories, macros, receipt totals) — this is the
/// signature typographic detail of the "Petrol & Citrus" design system.
class AppFonts {
  static TextStyle mono({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

class AppTheme {
  static ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    colors: AppColors.light,
  );

  static ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    colors: AppColors.dark,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColors colors,
  }) {
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
        onSurface: colors.textPrimary,
        surface: colors.surface,
      ),
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],

      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
        displayMedium: baseTextTheme.displayMedium
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
        displaySmall: baseTextTheme.displaySmall
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: baseTextTheme.headlineLarge
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: baseTextTheme.headlineMedium
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
        headlineSmall: baseTextTheme.headlineSmall
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
        titleLarge: baseTextTheme.titleLarge
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: baseTextTheme.titleMedium
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: baseTextTheme.titleSmall
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: colors.textPrimary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: colors.textSecondary),
        labelLarge: baseTextTheme.labelLarge
            ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
        labelMedium: baseTextTheme.labelMedium?.copyWith(color: colors.textPrimary),
        labelSmall: baseTextTheme.labelSmall?.copyWith(color: colors.textSecondary),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        foregroundColor: colors.textPrimary,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),

      // Primary CTAs use the citrus accent with dark ink text — lime is
      // too light for white text to sit on comfortably.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.accentOnColor,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.divider, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
        hintStyle: TextStyle(color: colors.textMuted),
        labelStyle: TextStyle(color: colors.textPrimary),
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.accent.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: colors.textMuted,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.textPrimary);
          }
          return IconThemeData(color: colors.textMuted);
        }),
      ),

      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      listTileTheme: ListTileThemeData(
        textColor: colors.textPrimary,
        iconColor: colors.textSecondary,
      ),

      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accent,
        thumbColor: colors.accent,
      ),
    );
  }
}