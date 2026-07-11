import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/receipt_decorations.dart';

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
  int _dailyCalories = 1800;
  String _activityLevel = 'moderate';

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

  void _nextPage() {
    if (_currentPage < 3) {
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

  // Auto-calculate calories based on goal
  void _updateCalories() {
    switch (_goalType) {
      case 'lose':
        _dailyCalories = 1500;
        break;
      case 'maintain':
        _dailyCalories = 2000;
        break;
      case 'gain':
        _dailyCalories = 2500;
        break;
    }
    switch (_activityLevel) {
      case 'sedentary':
        _dailyCalories -= 200;
        break;
      case 'active':
        _dailyCalories += 200;
        break;
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);
    try {
      _updateCalories();

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

      // Calculate macros based on calories
      final protein = (_dailyCalories * 0.30 / 4).roundToDouble();
      final carbs = (_dailyCalories * 0.45 / 4).roundToDouble();
      final fat = (_dailyCalories * 0.25 / 9).roundToDouble();

      // Save goals to Supabase
      final existing = await supabase
          .from('goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final data = {
        'user_id': userId,
        'daily_calories': _dailyCalories,
        'protein_goal': protein,
        'carbs_goal': carbs,
        'fat_goal': fat,
        'weight_goal': _targetWeight,
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
        'logged_at': DateTime.now().toIso8601String(),
      });

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
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                children: [
                  Row(
                    children: List.generate(4, (index) {
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
                        'STEP ${_currentPage + 1} OF 4',
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

            // Pages
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
                  _WeightPage(
                    currentWeight: _currentWeight,
                    targetWeight: _targetWeight,
                    goalType: _goalType,
                    onCurrentChanged: (v) =>
                        setState(() => _currentWeight = v),
                    onTargetChanged: (v) =>
                        setState(() => _targetWeight = v),
                  ),
                  _ActivityPage(
                    selectedLevel: _activityLevel,
                    activityLevels: _activityLevels,
                    onSelected: (key) =>
                        setState(() => _activityLevel = key),
                  ),
                ],
              ),
            ),

            // Next button
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
                  _currentPage == 3 ? 'Get Started 🚀' : 'Continue',
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
          // Brand hero — same barcode-strip / zigzag-tear card used on
          // Login, so onboarding opens with the same visual signature.
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
                    child: Icon(Icons.restaurant,
                        size: 32, color: colors.accentOnColor),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome to Eatsy',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'YOUR NUTRITION JOURNEY STARTS HERE',
                    style: AppFonts.mono(
                      fontSize: 10,
                      color: colors.accent,
                      letterSpacing: 1.2,
                    ),
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
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary,
              height: 1.5,
            ),
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
            // FIX: was `colors.labelCard` — a background color, not a
            // foreground/icon color. In dark mode labelCard (#16332C)
            // sits at nearly the same luminance as the tinted accent
            // chip behind it, making the icon almost invisible.
            // textPrimary is built to guarantee contrast on any surface
            // in both themes, which is what this needs.
            child: Icon(icon, color: colors.textPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
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
                  color: isSelected
                      ? colors.accent.withOpacity(0.10)
                      : colors.surface,
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
                              fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 16,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal['desc'],
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check,
                            size: 16, color: colors.accentOnColor),
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

// Page 3 — Weight
class _WeightPage extends StatelessWidget {
  final double currentWeight;
  final double targetWeight;
  final String goalType;
  final Function(double) onCurrentChanged;
  final Function(double) onTargetChanged;

  const _WeightPage({
    required this.currentWeight,
    required this.targetWeight,
    required this.goalType,
    required this.onCurrentChanged,
    required this.onTargetChanged,
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
            'Your weight',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us calculate your personalized plan.',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),

          _WeightCard(
            label: 'CURRENT WEIGHT',
            value: currentWeight,
            unit: 'kg',
            onChanged: onCurrentChanged,
            min: 30,
            max: 200,
            color: colors.protein,
          ),
          const SizedBox(height: 20),

          _WeightCard(
            label: goalType == 'lose'
                ? 'TARGET WEIGHT'
                : goalType == 'gain'
                ? 'GOAL WEIGHT'
                : 'MAINTAIN WEIGHT',
            value: targetWeight,
            unit: 'kg',
            onChanged: onTargetChanged,
            min: 30,
            max: 200,
            color: colors.carbs,
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
      padding: const EdgeInsets.all(20),
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
            style: AppFonts.mono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (value > min) onChanged(value - 0.5);
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: color,
                iconSize: 32,
              ),
              const SizedBox(width: 16),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: AppFonts.mono(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  if (value < max) onChanged(value + 0.5);
                },
                icon: const Icon(Icons.add_circle_outline),
                color: color,
                iconSize: 32,
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
                  color: isSelected
                      ? colors.accent.withOpacity(0.10)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colors.accent : colors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      level['icon'],
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level['label'],
                            style: TextStyle(
                              fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            level['desc'],
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check,
                            size: 14, color: colors.accentOnColor),
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