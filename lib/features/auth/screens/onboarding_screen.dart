import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/calorie_calculator.dart';
import '../../../core/utils/day_boundary.dart';
import '../../../shared/widgets/receipt_decorations.dart';
import '../../../shared/widgets/diet_preferences_form.dart';
import '../../preferences/models/diet_preferences.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // User selections
  String _goalType = 'lose';
  double _currentWeight = 70;
  double _targetWeight = 65;
  int _age = 25;
  double _height = 165;
  String _gender = 'female';
  String _activityLevel = 'moderate';
  List<String> _dietCuisines = [];
  List<String> _dietAllergies = [];
  String _dietType = 'no_restriction';
  List<String> _dietConditions = [];

  final List<Map<String, dynamic>> _goalTypes = [
    {'key': 'lose', 'label': 'Lose Weight', 'icon': '📉', 'desc': 'I want to lose weight and burn fat'},
    {'key': 'maintain', 'label': 'Stay Fit', 'icon': '⚖️', 'desc': 'I want to maintain my current weight'},
    {'key': 'gain', 'label': 'Build Muscle', 'icon': '💪', 'desc': 'I want to gain weight and build muscle'},
  ];

  final List<Map<String, dynamic>> _activityLevels = [
    {'key': 'sedentary', 'label': 'Sedentary', 'desc': 'Little or no exercise', 'icon': '🛋️'},
    {'key': 'light', 'label': 'Lightly Active', 'desc': 'Exercise 1-3 days/week', 'icon': '🚶'},
    {'key': 'moderate', 'label': 'Moderately Active', 'desc': 'Exercise 3-5 days/week', 'icon': '🏃'},
    {'key': 'active', 'label': 'Very Active', 'desc': 'Exercise 6-7 days/week', 'icon': '⚡'},
  ];

  void _toggleDietSelection(List<String> list, String value) {
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else {
        list.add(value);
      }
    });
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndContinue();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);
    try {
      // Diet preferences are now collected as part of this same
      // onboarding flow (see the diet-preferences page below), so the
      // calorie/macro split can use the user's real dietType and
      // medicalConditions immediately instead of the previous
      // no_restriction/empty-list placeholder.
      final targets = CalorieCalculator.calculateFullTargets(
        weightKg: _currentWeight,
        heightCm: _height,
        age: _age,
        gender: _gender,
        activityLevel: _activityLevel,
        goalType: _goalType,
        dietType: _dietType,
        medicalConditions: _dietConditions,
      );

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
            ),
          );
          context.go('/login');
        }
        return;
      }

      // Save goals to Supabase — including age/height/gender/activity
      // so the Goals screen's Body Profile arrives pre-filled instead
      // of asking the user to re-enter what they just told onboarding.
      final existing = await supabase
          .from('goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final data = {
        'user_id': userId,
        'daily_calories': targets.calories,
        'protein_goal': targets.proteinG,
        'carbs_goal': targets.carbsG,
        'fat_goal': targets.fatG,
        'weight_goal': _targetWeight,
        'age': _age,
        'height_cm': _height,
        'gender': _gender,
        'activity_level': _activityLevel,
      };

      if (existing != null) {
        await supabase.from('goals').update(data).eq('user_id', userId);
      } else {
        await supabase.from('goals').insert(data);
      }

      // Log current weight
      await supabase.from('weight_logs').insert({
        'user_id': userId,
        'weight': _currentWeight,
        'logged_at': DayBoundary.nowUtcIso(),
      });

      // Save diet preferences — same upsert shape as
      // DietPreferencesController.save(), so whether someone sets these
      // here during onboarding or later from the Goals screen, they end
      // up in the same row with the same column layout.
      await supabase.from('user_preferences').upsert(
        DietPreferences(
          cuisines: _dietCuisines,
          allergies: _dietAllergies,
          dietType: _dietType,
          medicalConditions: _dietConditions,
        ).toMap(userId),
        onConflict: 'user_id',
      );

      // Mark onboarding as done
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done_$userId', true);

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving goals: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= _currentPage
                                ? colors.accent
                                : colors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STEP ${_currentPage + 1} OF 5',
                        style: AppFonts.mono(
                          fontSize: 11,
                          color: colors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      if (_currentPage > 0)
                        GestureDetector(
                          onTap: _previousPage,
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  const _WelcomePage(),
                  _GoalTypePage(
                    selectedGoal: _goalType,
                    goalTypes: _goalTypes,
                    onSelected: (key) => setState(() => _goalType = key),
                  ),
                  _BodyDetailsPage(
                    currentWeight: _currentWeight,
                    targetWeight: _targetWeight,
                    goalType: _goalType,
                    age: _age,
                    height: _height,
                    gender: _gender,
                    onCurrentWeightChanged: (v) => setState(() => _currentWeight = v),
                    onTargetWeightChanged: (v) => setState(() => _targetWeight = v),
                    onAgeChanged: (v) => setState(() => _age = v),
                    onHeightChanged: (v) => setState(() => _height = v),
                    onGenderChanged: (v) => setState(() => _gender = v),
                  ),
                  _ActivityPage(
                    selectedLevel: _activityLevel,
                    activityLevels: _activityLevels,
                    onSelected: (key) => setState(() => _activityLevel = key),
                  ),
                  _DietPreferencesPage(
                    selectedCuisines: _dietCuisines,
                    selectedAllergies: _dietAllergies,
                    selectedDietType: _dietType,
                    selectedConditions: _dietConditions,
                    onToggleCuisine: (v) =>
                        _toggleDietSelection(_dietCuisines, v),
                    onToggleAllergy: (v) =>
                        _toggleDietSelection(_dietAllergies, v),
                    onToggleCondition: (v) =>
                        _toggleDietSelection(_dietConditions, v),
                    onDietTypeSelected: (key) =>
                        setState(() => _dietType = key),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextPage,
                child: _isLoading
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: colors.accentOnColor,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  _currentPage == 4 ? 'Get Started 🚀' : 'Continue',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Page 1 — Welcome
class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Container(
              width: double.infinity,
              color: colors.labelCard,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  BarcodeStrip(color: colors.accent),
                  const SizedBox(height: 16),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.restaurant, size: 32, color: colors.accentOnColor),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome to Eatsy',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'YOUR NUTRITION JOURNEY STARTS HERE',
                    style: AppFonts.mono(fontSize: 10, color: colors.accent, letterSpacing: 1.2),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          ZigzagEdge(color: colors.labelCard),
          const SizedBox(height: 28),
          Text(
            "Let's set up your personal nutrition plan in just a few steps.",
            style: TextStyle(fontSize: 15, color: colors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          const _FeatureRow(icon: Icons.camera_alt, text: 'Scan food with AI camera'),
          const SizedBox(height: 12),
          const _FeatureRow(icon: Icons.pie_chart, text: 'Track calories & macros daily'),
          const SizedBox(height: 12),
          const _FeatureRow(icon: Icons.flag, text: 'Reach your personal goals'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.textPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 14, color: colors.accentOnColor),
          ),
        ],
      ),
    );
  }
}

// Page 2 — Goal Type
class _GoalTypePage extends StatelessWidget {
  final String selectedGoal;
  final List<Map<String, dynamic>> goalTypes;
  final Function(String) onSelected;

  const _GoalTypePage({
    required this.selectedGoal,
    required this.goalTypes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your goal?",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll customize your daily calorie target based on this.",
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ...goalTypes.map((goal) {
            final isSelected = selectedGoal == goal['key'];
            return GestureDetector(
              onTap: () => onSelected(goal['key']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected ? colors.accent.withOpacity(0.10) : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colors.accent : colors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(goal['icon'], style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal['label'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 16,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal['desc'],
                            style: TextStyle(color: colors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 16, color: colors.accentOnColor),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Page 3 — Body Details (weight + age + height + gender). Everything
// collected here feeds directly into CalorieCalculator.calculateFullTargets
// — the exact same function Goals screen's "Calculate My Targets" uses —
// so the number a user sees at signup matches what they'd get recalculating
// later, instead of two different formulas producing two different answers.
class _BodyDetailsPage extends StatelessWidget {
  final double currentWeight;
  final double targetWeight;
  final String goalType;
  final int age;
  final double height;
  final String gender;
  final Function(double) onCurrentWeightChanged;
  final Function(double) onTargetWeightChanged;
  final Function(int) onAgeChanged;
  final Function(double) onHeightChanged;
  final Function(String) onGenderChanged;

  const _BodyDetailsPage({
    required this.currentWeight,
    required this.targetWeight,
    required this.goalType,
    required this.age,
    required this.height,
    required this.gender,
    required this.onCurrentWeightChanged,
    required this.onTargetWeightChanged,
    required this.onAgeChanged,
    required this.onHeightChanged,
    required this.onGenderChanged,
  });

  static const _genders = [
    {'key': 'female', 'label': 'Female'},
    {'key': 'male', 'label': 'Male'},
    {'key': 'other', 'label': 'Other'},
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About you',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us calculate your personalized calorie and macro targets.',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),

          _WeightCard(
            label: 'CURRENT WEIGHT',
            value: currentWeight,
            unit: 'kg',
            onChanged: onCurrentWeightChanged,
            min: 30,
            max: 200,
            color: colors.protein,
          ),
          const SizedBox(height: 16),

          _WeightCard(
            label: goalType == 'lose'
                ? 'TARGET WEIGHT'
                : goalType == 'gain'
                ? 'GOAL WEIGHT'
                : 'MAINTAIN WEIGHT',
            value: targetWeight,
            unit: 'kg',
            onChanged: onTargetWeightChanged,
            min: 30,
            max: 200,
            color: colors.carbs,
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _StepperCard(
                  label: 'AGE',
                  value: age.toDouble(),
                  unit: 'yrs',
                  step: 1,
                  min: 13,
                  max: 90,
                  decimals: 0,
                  color: colors.fat,
                  onChanged: (v) => onAgeChanged(v.round()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StepperCard(
                  label: 'HEIGHT',
                  value: height,
                  unit: 'cm',
                  step: 1,
                  min: 120,
                  max: 220,
                  decimals: 0,
                  color: colors.dinner,
                  onChanged: onHeightChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text('GENDER',
              style: AppFonts.mono(fontSize: 11, color: colors.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: _genders.map((g) {
              final isSelected = gender == g['key'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onGenderChanged(g['key']!),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.labelCard : colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      g['label']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Function(double) onChanged;
  final double min;
  final double max;
  final Color color;

  const _WeightCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.mono(fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (value > min) onChanged(value - 0.5);
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: color,
                iconSize: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: AppFonts.mono(fontSize: 24, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  if (value < max) onChanged(value + 0.5);
                },
                icon: const Icon(Icons.add_circle_outline),
                color: color,
                iconSize: 28,
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: color,
            inactiveColor: color.withOpacity(0.2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Compact +/- stepper card used for Age and Height — same visual
/// language as _WeightCard but without the slider, since a 1-unit
/// step doesn't need one.
class _StepperCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final Color color;
  final Function(double) onChanged;

  const _StepperCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.step,
    required this.min,
    required this.max,
    required this.decimals,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppFonts.mono(fontSize: 10, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (value > min) onChanged(value - step);
                },
                child: Icon(Icons.remove_circle_outline, color: color, size: 22),
              ),
              Expanded(
                child: Text(
                  '${value.toStringAsFixed(decimals)} $unit',
                  textAlign: TextAlign.center,
                  style: AppFonts.mono(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (value < max) onChanged(value + step);
                },
                child: Icon(Icons.add_circle_outline, color: color, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Page 4 — Activity Level
class _ActivityPage extends StatelessWidget {
  final String selectedLevel;
  final List<Map<String, dynamic>> activityLevels;
  final Function(String) onSelected;

  const _ActivityPage({
    required this.selectedLevel,
    required this.activityLevels,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity level',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'How active are you on a typical week?',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ...activityLevels.map((level) {
            final isSelected = selectedLevel == level['key'];
            return GestureDetector(
              onTap: () => onSelected(level['key']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? colors.accent.withOpacity(0.10) : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colors.accent : colors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(level['icon'], style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level['label'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            level['desc'],
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 14, color: colors.accentOnColor),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
// Page 5 — Diet Preferences
class _DietPreferencesPage extends StatelessWidget {
  final List<String> selectedCuisines;
  final List<String> selectedAllergies;
  final String selectedDietType;
  final List<String> selectedConditions;
  final ValueChanged<String> onToggleCuisine;
  final ValueChanged<String> onToggleAllergy;
  final ValueChanged<String> onToggleCondition;
  final ValueChanged<String> onDietTypeSelected;

  const _DietPreferencesPage({
    required this.selectedCuisines,
    required this.selectedAllergies,
    required this.selectedDietType,
    required this.selectedConditions,
    required this.onToggleCuisine,
    required this.onToggleAllergy,
    required this.onToggleCondition,
    required this.onDietTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalize your plan',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          // Explicitly framed as optional/skippable — unlike goal type,
          // weight, or activity level, none of this blocks the app from
          // working. Leaving everything at its default (no cuisines
          // picked, no_restriction, no allergies/conditions) is a valid
          // choice, not an incomplete one, and "Get Started" below works
          // exactly the same either way — there's no separate Skip
          // button because there's nothing to skip past.
          Text(
            'This shapes your AI meal plans — cuisine, allergies, diet '
                'type, and medical considerations. Totally optional: skip '
                'anything you\'re not sure about and adjust it later from '
                'Goals.',
            style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 28),
          DietPreferencesForm(
            selectedCuisines: selectedCuisines,
            selectedAllergies: selectedAllergies,
            selectedDietType: selectedDietType,
            selectedConditions: selectedConditions,
            onToggleCuisine: onToggleCuisine,
            onToggleAllergy: onToggleAllergy,
            onToggleCondition: onToggleCondition,
            onDietTypeSelected: onDietTypeSelected,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}