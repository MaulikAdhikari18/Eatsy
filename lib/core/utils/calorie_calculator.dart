/// Implements Section 4.1 of the implementation guide:
/// BMR (Mifflin-St Jeor) → TDEE → calorie target → macro split.
///
/// This is pure calculation logic with no dependency on Flutter or
/// Supabase, so it's easy to unit test independently of the UI.
library calorie_calculator;

class MacroTargets {
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

class CalorieCalculator {
  /// Mifflin-St Jeor BMR (kcal/day at rest).
  /// Male:   10×weight(kg) + 6.25×height(cm) − 5×age + 5
  /// Female: 10×weight(kg) + 6.25×height(cm) − 5×age − 161
  /// Other:  averaged constant of the two (+5 and −161 → −78)
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender, // 'male' | 'female' | 'other'
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    switch (gender) {
      case 'male':
        return base + 5;
      case 'female':
        return base - 161;
      default:
        return base - 78; // midpoint of +5 and -161
    }
  }

  /// Activity multipliers matching the levels already collected in
  /// onboarding_screen.dart: sedentary / light / moderate / active.
  static const Map<String, double> _activityMultipliers = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
  };

  static double calculateTDEE({
    required double bmr,
    required String activityLevel,
  }) {
    final multiplier = _activityMultipliers[activityLevel] ?? 1.55;
    return bmr * multiplier;
  }

  /// Applies the goal-direction adjustment from Section 4.1:
  /// lose = TDEE − 300 to 500 (we use −400 as the midpoint),
  /// gain = TDEE + 200 to 300 (we use +250),
  /// maintain = TDEE unchanged.
  static int calculateCalorieTarget({
    required double tdee,
    required String goalType, // 'lose' | 'maintain' | 'gain'
  }) {
    switch (goalType) {
      case 'lose':
        return (tdee - 400).round();
      case 'gain':
        return (tdee + 250).round();
      default:
        return tdee.round();
    }
  }

  /// Macro split, adjusted for diet type per Section 4.1 / 4.4 guidance.
  /// Standard split: Protein 30% / Carbs 40% / Fat 30%.
  /// Keto: ~5% carbs. Diabetic-adjacent (handled via medicalConditions
  /// containing 'Diabetes'): lower carb %, higher protein, low-GI focus
  /// (the low-GI part is a prompt instruction, not a macro-split concern).
  static MacroTargets calculateMacros({
    required int calorieTarget,
    required String dietType,
    required List<String> medicalConditions,
  }) {
    double proteinPct = 0.30;
    double carbsPct = 0.40;
    double fatPct = 0.30;

    if (dietType == 'keto') {
      proteinPct = 0.25;
      carbsPct = 0.05;
      fatPct = 0.70;
    } else if (medicalConditions.contains('Diabetes')) {
      proteinPct = 0.35;
      carbsPct = 0.30;
      fatPct = 0.35;
    }

    return MacroTargets(
      calories: calorieTarget,
      proteinG: (calorieTarget * proteinPct / 4).roundToDouble(),
      carbsG: (calorieTarget * carbsPct / 4).roundToDouble(),
      fatG: (calorieTarget * fatPct / 9).roundToDouble(),
    );
  }

  /// Convenience: run the full pipeline in one call.
  static MacroTargets calculateFullTargets({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String activityLevel,
    required String goalType,
    required String dietType,
    required List<String> medicalConditions,
  }) {
    final bmr = calculateBMR(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final tdee = calculateTDEE(bmr: bmr, activityLevel: activityLevel);
    final calorieTarget =
    calculateCalorieTarget(tdee: tdee, goalType: goalType);
    return calculateMacros(
      calorieTarget: calorieTarget,
      dietType: dietType,
      medicalConditions: medicalConditions,
    );
  }
}