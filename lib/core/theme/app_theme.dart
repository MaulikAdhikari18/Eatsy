import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Brand colors — stay the same in both light and dark mode.
  static const Color primary = Color(0xFF4CAF50);
  static const Color secondary = Color(0xFF81C784);
  static const Color accent = Color(0xFFFF7043);

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
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        onSurface: colors.textPrimary,
        surface: colors.surface,
      ),
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],

      textTheme: TextTheme(
        displayLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: colors.textPrimary),
        bodyMedium: TextStyle(color: colors.textPrimary),
        bodySmall: TextStyle(color: colors.textSecondary),
        labelLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: colors.textPrimary),
        labelSmall: TextStyle(color: colors.textSecondary),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        foregroundColor: colors.textPrimary,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colors.surfaceVariant : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
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
        indicatorColor: primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary);
          }
          return IconThemeData(color: colors.textSecondary);
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

      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
      ),
    );
  }
}