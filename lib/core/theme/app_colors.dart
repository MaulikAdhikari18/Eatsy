import 'package:flutter/material.dart';

/// Semantic colors for the "Petrol & Citrus" design system — a nutrition
/// label / receipt visual language used across Dashboard, Food Log,
/// Scan, Goals, and Meal Plan.
///
/// Screens read colors from here (via `context.appColors.xxx`) instead
/// of hardcoding values, so light/dark mode and future palette tweaks
/// propagate everywhere automatically.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // Structural
  final Color background;
  final Color surface; // card background
  final Color surfaceVariant; // chips, inactive pills, subtle fills
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color cardShadow;

  // Brand
  final Color accent; // citrus lime — primary CTA color
  final Color accentOnColor; // text/icon color to use ON the accent (dark ink)
  final Color labelCard; // the dark "nutrition label" header card background

  // Macro colors (protein / carbs / fat) — used consistently everywhere
  // a macro is shown: dashboard strip, food log, goals, meal plan.
  final Color protein;
  final Color carbs;
  final Color fat;

  // Meal-type colors — used for pills and section headers in Food Log
  // and Meal Plan.
  final Color breakfast;
  final Color lunch;
  final Color dinner;
  final Color snack;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.cardShadow,
    required this.accent,
    required this.accentOnColor,
    required this.labelCard,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snack,
  });

  /// Returns the color for a given meal_type string ('breakfast', 'lunch',
  /// 'dinner', 'snack'), falling back to textSecondary for unknown values.
  Color mealTypeColor(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return breakfast;
      case 'lunch':
        return lunch;
      case 'dinner':
        return dinner;
      case 'snack':
        return snack;
      default:
        return textSecondary;
    }
  }

  static const light = AppColors(
    background: Color(0xFFF5F6F1),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEFEDE0),
    textPrimary: Color(0xFF14302E),
    textSecondary: Color(0xFF5C7A74),
    textMuted: Color(0xFF8F8D80),
    divider: Color(0xFFE4E2D6),
    cardShadow: Color(0x0F000000),
    accent: Color(0xFFC4D82E),
    accentOnColor: Color(0xFF14302E),
    labelCard: Color(0xFF14302E),
    protein: Color(0xFF4F9B74),
    carbs: Color(0xFFC79A3A),
    fat: Color(0xFFDD6B55),
    breakfast: Color(0xFFCB9A3D),
    lunch: Color(0xFF8FB93A),
    dinner: Color(0xFF7C8FCA),
    snack: Color(0xFFC97CA0),
  );

  static const dark = AppColors(
    background: Color(0xFF0E1A18),
    surface: Color(0xFF152825),
    surfaceVariant: Color(0xFF1E3A34),
    textPrimary: Color(0xFFEAF2EF),
    textSecondary: Color(0xFF9FB5AE),
    textMuted: Color(0xFF6E8880),
    divider: Color(0xFF24413B),
    cardShadow: Color(0x40000000),
    accent: Color(0xFFC4D82E),
    accentOnColor: Color(0xFF0E1A18),
    labelCard: Color(0xFF16332C),
    protein: Color(0xFF7BD9A0),
    carbs: Color(0xFFF5C56B),
    fat: Color(0xFFE8917A),
    breakfast: Color(0xFFE3A855),
    lunch: Color(0xFFA8D95A),
    dinner: Color(0xFF9AA8E0),
    snack: Color(0xFFE0A0BE),
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
    Color? accent,
    Color? accentOnColor,
    Color? labelCard,
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? breakfast,
    Color? lunch,
    Color? dinner,
    Color? snack,
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
      accent: accent ?? this.accent,
      accentOnColor: accentOnColor ?? this.accentOnColor,
      labelCard: labelCard ?? this.labelCard,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
      snack: snack ?? this.snack,
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
      accent: Color.lerp(accent, other.accent, t)!,
      accentOnColor: Color.lerp(accentOnColor, other.accentOnColor, t)!,
      labelCard: Color.lerp(labelCard, other.labelCard, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      breakfast: Color.lerp(breakfast, other.breakfast, t)!,
      lunch: Color.lerp(lunch, other.lunch, t)!,
      dinner: Color.lerp(dinner, other.dinner, t)!,
      snack: Color.lerp(snack, other.snack, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}