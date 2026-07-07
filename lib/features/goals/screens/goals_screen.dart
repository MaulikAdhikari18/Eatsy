import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/calorie_calculator.dart';
import '../../preferences/controllers/diet_preferences_controller.dart';

// Every color below comes from context.appColors (colors.*), same as
// Dashboard / Scan / Food Log / Barcode. AppTheme is only imported for
// AppFonts.mono — there is no dead AppTheme.primary reference left here.

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _calorieController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _weightGoalController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isCalculating = false;
  List<Map<String, dynamic>> _weightLogs = [];
  String _selectedGoalType = 'lose';
  String _selectedGender = 'female';
  String _selectedActivityLevel = 'moderate';

  final List<Map<String, String>> _goalTypes = [
    {'key': 'lose', 'label': 'Lose Weight', 'icon': '📉'},
    {'key': 'maintain', 'label': 'Maintain', 'icon': '⚖️'},
    {'key': 'gain', 'label': 'Gain Weight', 'icon': '📈'},
  ];

  final List<Map<String, String>> _genders = [
    {'key': 'female', 'label': 'Female'},
    {'key': 'male', 'label': 'Male'},
    {'key': 'other', 'label': 'Other'},
  ];

  final List<Map<String, String>> _activityLevels = [
    {'key': 'sedentary', 'label': 'Sedentary'},
    {'key': 'light', 'label': 'Light'},
    {'key': 'moderate', 'label': 'Moderate'},
    {'key': 'active', 'label': 'Active'},
  ];

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadWeightLogs();
  }

  @override
  void dispose() {
    _calorieController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _weightGoalController.dispose();
    _currentWeightController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final goals = await supabase
          .from('goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (goals != null) {
        _calorieController.text =
            (goals['daily_calories'] ?? 2000).toString();
        _proteinController.text =
            (goals['protein_goal'] ?? 150).toString();
        _carbsController.text =
            (goals['carbs_goal'] ?? 250).toString();
        _fatController.text =
            (goals['fat_goal'] ?? 65).toString();
        _weightGoalController.text =
            (goals['weight_goal'] ?? '').toString();
        _ageController.text = (goals['age'] ?? '').toString();
        _heightController.text = (goals['height_cm'] ?? '').toString();
        _selectedGender = goals['gender']?.toString() ?? 'female';
        _selectedActivityLevel =
            goals['activity_level']?.toString() ?? 'moderate';
      } else {
        // Set defaults
        _calorieController.text = '2000';
        _proteinController.text = '150';
        _carbsController.text = '250';
        _fatController.text = '65';
      }
    } catch (e) {
      debugPrint('Error loading goals: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeightLogs() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final logs = await supabase
          .from('weight_logs')
          .select()
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(7);

      setState(() =>
      _weightLogs = List<Map<String, dynamic>>.from(logs));
    } catch (e) {
      debugPrint('Error loading weight logs: $e');
    }
  }

  void _showSnack(String message, {required Color background}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: background,
      ),
    );
  }

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final existing = await supabase
          .from('goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final data = {
        'user_id': userId,
        'daily_calories': int.tryParse(_calorieController.text) ?? 2000,
        'protein_goal': double.tryParse(_proteinController.text) ?? 150,
        'carbs_goal': double.tryParse(_carbsController.text) ?? 250,
        'fat_goal': double.tryParse(_fatController.text) ?? 65,
        'weight_goal': double.tryParse(_weightGoalController.text) ?? 0,
        'age': int.tryParse(_ageController.text),
        'height_cm': double.tryParse(_heightController.text),
        'gender': _selectedGender,
        'activity_level': _selectedActivityLevel,
      };

      if (existing != null) {
        await supabase
            .from('goals')
            .update(data)
            .eq('user_id', userId);
      } else {
        await supabase.from('goals').insert(data);
      }

      if (mounted) {
        _showSnack('Goals saved successfully!',
            background: context.appColors.labelCard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving goals: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logWeight() async {
    if (_currentWeightController.text.isEmpty) return;
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('weight_logs').insert({
        'user_id': userId,
        'weight': double.tryParse(_currentWeightController.text) ?? 0,
        'logged_at': DateTime.now().toIso8601String(),
      });

      _currentWeightController.clear();
      _loadWeightLogs();

      if (mounted) {
        _showSnack('Weight logged!', background: context.appColors.labelCard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging weight: $e')),
        );
      }
    }
  }

  /// Runs the BMR → TDEE → calorie target → macro pipeline (Section 4.1)
  /// and pre-fills the Daily Targets fields below. Nothing is saved until
  /// the user taps "Save Goals" — this only sets smart defaults.
  Future<void> _calculateTargets() async {
    final colors = context.appColors;
    final age = int.tryParse(_ageController.text);
    final height = double.tryParse(_heightController.text);

    if (age == null || height == null) {
      _showSnack('Enter your age and height first', background: colors.carbs);
      return;
    }

    // Use the most recent logged weight; fall back to the current-weight
    // input field if the user just typed one but hasn't tapped "Log" yet.
    double? currentWeight;
    if (_weightLogs.isNotEmpty) {
      currentWeight = (_weightLogs.first['weight'] as num?)?.toDouble();
    }
    currentWeight ??= double.tryParse(_currentWeightController.text);

    if (currentWeight == null) {
      _showSnack('Log your current weight below first',
          background: colors.carbs);
      return;
    }

    setState(() => _isCalculating = true);
    try {
      // Pull diet type / medical conditions from the preferences we
      // collected earlier, so keto/diabetic macro adjustments apply.
      final prefs = await ref.read(dietPreferencesProvider.future);

      final targets = CalorieCalculator.calculateFullTargets(
        weightKg: currentWeight,
        heightCm: height,
        age: age,
        gender: _selectedGender,
        activityLevel: _selectedActivityLevel,
        goalType: _selectedGoalType,
        dietType: prefs?.dietType ?? 'no_restriction',
        medicalConditions: prefs?.medicalConditions ?? [],
      );

      setState(() {
        _calorieController.text = targets.calories.toString();
        _proteinController.text = targets.proteinG.toInt().toString();
        _carbsController.text = targets.carbsG.toInt().toString();
        _fatController.text = targets.fatG.toInt().toString();
      });

      if (mounted) {
        _showSnack(
            'Targets calculated from your profile — review below, then Save',
            background: colors.labelCard);
      }
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Goals & Tracking'),
      ),
      body: _isLoading
          ? Center(
          child: CircularProgressIndicator(color: colors.accent))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal type selector — same solid label-card fill used for
            // every single-select segmented control in the app (meal
            // type pills, diet type pills).
            _SectionHeading('My Goal', colors),
            const SizedBox(height: 12),
            Row(
              children: _goalTypes.map((type) {
                final isSelected = _selectedGoalType == type['key'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                            () => _selectedGoalType = type['key']!),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.labelCard
                            : colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colors.labelCard
                              : colors.divider,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(type['icon']!,
                              style:
                              const TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            type['label']!,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Diet Preferences entry point
            GestureDetector(
              onTap: () => context.push('/diet-preferences'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                  Border.all(color: colors.accent.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.restaurant_menu,
                          color: colors.accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diet Preferences',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cuisine, allergies & diet type for your AI meal plan',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.textMuted),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Body Profile — needed for BMR/TDEE calculation
            _SectionHeading('Body Profile', colors),
            const SizedBox(height: 4),
            Text(
              'Used to calculate your personalized calorie & macro targets',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Age',
                          controller: _ageController,
                          suffix: 'yrs',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledField(
                          label: 'Height',
                          controller: _heightController,
                          suffix: 'cm',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Gender',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _genders.map((g) {
                      final isSelected = _selectedGender == g['key'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                                  () => _selectedGender = g['key']!),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding:
                            const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.labelCard
                                  : colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              g['label']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Activity Level',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _activityLevels.map((level) {
                      final isSelected =
                          _selectedActivityLevel == level['key'];
                      return GestureDetector(
                        onTap: () => setState(() =>
                        _selectedActivityLevel = level['key']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.labelCard
                                : colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            level['label']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isCalculating ? null : _calculateTargets,
                    icon: _isCalculating
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.accent),
                    )
                        : const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('Calculate My Targets'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Calorie & Macro Goals — each field's label is tinted with
            // the same protein/carbs/fat colors used on Dashboard, Scan
            // and Barcode, so the same macro reads as the same color
            // everywhere in the app.
            _SectionHeading('Daily Targets', colors),
            const SizedBox(height: 4),
            Text(
              'Auto-filled by the calculator above — edit anytime',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _GoalField(
                    label: '🔥 Daily Calories',
                    controller: _calorieController,
                    unit: 'kcal',
                  ),
                  Divider(height: 24, color: colors.divider),
                  _GoalField(
                    label: '🥩 Protein',
                    controller: _proteinController,
                    unit: 'g',
                    accentColor: colors.protein,
                  ),
                  Divider(height: 24, color: colors.divider),
                  _GoalField(
                    label: '🌾 Carbohydrates',
                    controller: _carbsController,
                    unit: 'g',
                    accentColor: colors.carbs,
                  ),
                  Divider(height: 24, color: colors.divider),
                  _GoalField(
                    label: '🥑 Fat',
                    controller: _fatController,
                    unit: 'g',
                    accentColor: colors.fat,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Weight Goal
            _SectionHeading('Weight Goal', colors),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _GoalField(
                label: '🎯 Target Weight',
                controller: _weightGoalController,
                unit: 'kg',
                accentColor: colors.carbs,
              ),
            ),

            const SizedBox(height: 16),

            // Save button — inherits accent fill / accentOnColor text
            // from ElevatedButtonThemeData.
            ElevatedButton(
              onPressed: _isSaving ? null : _saveGoals,
              child: _isSaving
                  ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: colors.accentOnColor,
                  strokeWidth: 2,
                ),
              )
                  : const Text('Save Goals'),
            ),

            const SizedBox(height: 24),

            // Log weight
            _SectionHeading("Log Today's Weight", colors),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _currentWeightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter weight in kg',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _logWeight,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 52),
                    ),
                    child: const Text('Log'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Weight history — uses the same "protein" green as the
            // Onboarding weight page, since this is the same semantic
            // reading: a live, current-state figure.
            if (_weightLogs.isNotEmpty) ...[
              _SectionHeading('Weight History', colors),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _weightLogs.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (context, index) {
                    final log = _weightLogs[index];
                    final date = DateTime.parse(
                        log['logged_at'].toString());
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.protein.withOpacity(0.14),
                        child: Icon(Icons.monitor_weight,
                            color: colors.protein, size: 20),
                      ),
                      title: Text(
                        '${log['weight']} kg',
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: TextStyle(
                            color: colors.textMuted, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionHeading(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String suffix;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: TextStyle(color: colors.textMuted, fontSize: 12),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _GoalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String unit;
  final Color? accentColor;

  const _GoalField({
    required this.label,
    required this.controller,
    required this.unit,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: accentColor ?? colors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: AppFonts.mono(fontSize: 14, color: colors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              suffixText: unit,
              suffixStyle: TextStyle(
                  color: accentColor ?? colors.textMuted, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}