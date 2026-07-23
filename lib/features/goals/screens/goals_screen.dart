import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/calorie_calculator.dart';
import '../../preferences/controllers/diet_preferences_controller.dart';
import '../../dashboard/controllers/water_controller.dart';
import '../../../core/settings/unit_preferences_provider.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../shared/widgets/unit_dropdown.dart';
import '../../../core/utils/day_boundary.dart';

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
  final _waterGoalController = TextEditingController();
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
    _waterGoalController.dispose();
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
        _weightGoalController.text = goals['weight_goal'] != null
            ? _formatWeightFromKg(
            (goals['weight_goal'] as num), ref.read(weightUnitProvider))
            : '';
        _waterGoalController.text = _formatWaterFromMl(
            (goals['water_goal_ml'] ?? 2000) as num, ref.read(waterUnitProvider));
        _ageController.text = (goals['age'] ?? '').toString();
        _heightController.text = goals['height_cm'] != null
            ? _formatHeightFromCm(
            (goals['height_cm'] as num), ref.read(heightUnitProvider))
            : '';
        _selectedGender = goals['gender']?.toString() ?? 'female';
        _selectedActivityLevel =
            goals['activity_level']?.toString() ?? 'moderate';
      } else {
        // Set defaults
        _calorieController.text = '2000';
        _proteinController.text = '150';
        _carbsController.text = '250';
        _fatController.text = '65';
        _waterGoalController.text =
            _formatWaterFromMl(2000, ref.read(waterUnitProvider));
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
        'weight_goal': _parseWeightToKg(
            _weightGoalController.text, ref.read(weightUnitProvider)) ??
            0,
        'water_goal_ml': _parseWaterToMl(
            _waterGoalController.text, ref.read(waterUnitProvider)) ??
            2000,
        'age': int.tryParse(_ageController.text),
        'height_cm': _parseHeightToCm(
            _heightController.text, ref.read(heightUnitProvider)),
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
        ref.invalidate(waterSummaryProvider);
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
        'weight':
        _parseWeightToKg(_currentWeightController.text, ref.read(weightUnitProvider)) ?? 0,
        'logged_at': DayBoundary.nowUtcIso(),
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
    final height = _parseHeightToCm(_heightController.text, ref.read(heightUnitProvider));

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
    currentWeight ??=
        _parseWeightToKg(_currentWeightController.text, ref.read(weightUnitProvider));

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

  // --- Unit conversion helpers -------------------------------------
  // The `goals`/`weight_logs`/`water_logs` tables always store kg, ml,
  // and cm — these helpers are the only place that translates to/from
  // whatever the user has chosen to display. Keeping the conversion in
  // one spot means load/save/history all stay consistent even as the
  // preference changes mid-session, and even though the unit can now be
  // changed from several different inline dropdowns instead of one
  // Settings toggle — they all read/write the same underlying provider,
  // so there's never a case where two fields disagree about the unit.

  double? _parseWeightToKg(String text, WeightUnit unit) {
    final value = double.tryParse(text);
    if (value == null) return null;
    return switch (unit) {
      WeightUnit.lb => UnitConverter.lbToKg(value),
      WeightUnit.stone => UnitConverter.stoneToKg(value),
      WeightUnit.kg => value,
    };
  }

  String _formatWeightFromKg(num kg, WeightUnit unit) {
    final display = switch (unit) {
      WeightUnit.lb => UnitConverter.kgToLb(kg.toDouble()),
      WeightUnit.stone => UnitConverter.kgToStone(kg.toDouble()),
      WeightUnit.kg => kg.toDouble(),
    };
    return display.toStringAsFixed(1);
  }

  int? _parseWaterToMl(String text, WaterUnit unit) {
    final value = double.tryParse(text);
    if (value == null) return null;
    final ml = switch (unit) {
      WaterUnit.liter => UnitConverter.lToMl(value),
      WaterUnit.flOz => UnitConverter.flOzToMl(value),
      WaterUnit.glasses => UnitConverter.glassesToMl(value),
      WaterUnit.ml => value,
    };
    return ml.round();
  }

  String _formatWaterFromMl(num ml, WaterUnit unit) {
    return switch (unit) {
      WaterUnit.liter => UnitConverter.mlToL(ml).toStringAsFixed(2),
      WaterUnit.flOz => UnitConverter.mlToFlOz(ml).toStringAsFixed(1),
    // Glasses is an integer count target ("8 glasses"), not a decimal
    // — a target of "8.3 glasses" is awkward, so this rounds to the
    // nearest whole glass rather than showing a fraction.
      WaterUnit.glasses => UnitConverter.mlToGlasses(ml).round().toString(),
      WaterUnit.ml => ml.round().toString(),
    };
  }

  double? _parseHeightToCm(String text, HeightUnit unit) {
    final value = double.tryParse(text);
    if (value == null) return null;
    return unit == HeightUnit.ftIn ? UnitConverter.ftToCm(value) : value;
  }

  String _formatHeightFromCm(num cm, HeightUnit unit) {
    final display =
    unit == HeightUnit.ftIn ? UnitConverter.cmToFt(cm.toDouble()) : cm.toDouble();
    return display.toStringAsFixed(unit == HeightUnit.ftIn ? 2 : 0);
  }

  /// Called when a unit is flipped — from any of the inline dropdowns,
  /// or if a future Settings entry point still exists elsewhere —
  /// reformats whatever's currently typed in place instead of losing it
  /// or leaving it silently mislabeled.
  void _onWeightUnitChanged(WeightUnit from, WeightUnit to) {
    for (final controller in [_weightGoalController, _currentWeightController]) {
      final kg = _parseWeightToKg(controller.text, from);
      if (kg == null) continue;
      controller.text = _formatWeightFromKg(kg, to);
    }
    if (mounted) setState(() {});
  }

  void _onWaterUnitChanged(WaterUnit from, WaterUnit to) {
    final ml = _parseWaterToMl(_waterGoalController.text, from);
    if (ml == null) return;
    _waterGoalController.text = _formatWaterFromMl(ml, to);
  }

  void _onHeightUnitChanged(HeightUnit from, HeightUnit to) {
    final cm = _parseHeightToCm(_heightController.text, from);
    if (cm == null) return;
    _heightController.text = _formatHeightFromCm(cm, to);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final weightUnit = ref.watch(weightUnitProvider);
    final waterUnit = ref.watch(waterUnitProvider);
    final heightUnit = ref.watch(heightUnitProvider);

    ref.listen<WeightUnit>(weightUnitProvider, (previous, next) {
      if (previous != null && previous != next) {
        _onWeightUnitChanged(previous, next);
      }
    });
    ref.listen<WaterUnit>(waterUnitProvider, (previous, next) {
      if (previous != null && previous != next) {
        _onWaterUnitChanged(previous, next);
      }
    });
    ref.listen<HeightUnit>(heightUnitProvider, (previous, next) {
      if (previous != null && previous != next) {
        _onHeightUnitChanged(previous, next);
      }
    });

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
                  _LabeledField(
                    label: 'Age',
                    controller: _ageController,
                    suffix: 'yrs',
                  ),
                  const SizedBox(height: 16),

                  // Height — the one field in Body Profile that needs a
                  // unit dropdown (cm vs ft), so it gets its own row
                  // instead of sharing one with Age.
                  Text('Height',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      UnitDropdown<HeightUnit>(
                        value: heightUnit,
                        options: heightUnitOptions,
                        onChanged: (u) =>
                            ref.read(heightUnitProvider.notifier).setUnit(u),
                      ),
                    ],
                  ),
                  if (heightUnit == HeightUnit.ftIn) ...[
                    Builder(builder: (context) {
                      final cm = _parseHeightToCm(_heightController.text, heightUnit);
                      if (cm == null) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '≈ ${UnitConverter.cmToFeetInchesLabel(cm)}',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                      );
                    }),
                  ],

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

            // Weight Goal — unit dropdown replaces the old static "kg"
            // suffix, and controls the SAME weightUnitProvider used by
            // Log Today's Weight and Weight History below, so all three
            // always agree on what unit they're showing.
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
                unit: '',
                accentColor: colors.carbs,
                unitControl: UnitDropdown<WeightUnit>(
                  value: weightUnit,
                  options: weightUnitOptions,
                  color: colors.carbs,
                  onChanged: (u) => ref.read(weightUnitProvider.notifier).setUnit(u),
                ),
              ),
            ),
            if (weightUnit == WeightUnit.stone) ...[
              Builder(builder: (context) {
                final kg = _parseWeightToKg(_weightGoalController.text, weightUnit);
                if (kg == null) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '≈ ${UnitConverter.kgToStoneLabel(kg)}',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),

            // Water Goal — same editable-field pattern as Weight Goal
            // above; feeds the `water_goal_ml` column that the
            // Dashboard's water card (water_controller.dart) already
            // reads from, so saving here updates that card immediately.
            _SectionHeading('Water Goal', colors),
            const SizedBox(height: 4),
            Text(
              'Your daily water target — shown on the Dashboard water card',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _GoalField(
                label: '💧 Target Water',
                controller: _waterGoalController,
                unit: '',
                accentColor: colors.water,
                unitControl: UnitDropdown<WaterUnit>(
                  value: waterUnit,
                  options: waterUnitOptions,
                  color: colors.water,
                  onChanged: (u) => ref.read(waterUnitProvider.notifier).setUnit(u),
                ),
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

            // Log weight — same inline dropdown pattern, same shared
            // weightUnitProvider as Target Weight above.
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Enter weight',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  UnitDropdown<WeightUnit>(
                    value: weightUnit,
                    options: weightUnitOptions,
                    onChanged: (u) => ref.read(weightUnitProvider.notifier).setUnit(u),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _logWeight,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(70, 52),
                    ),
                    child: const Text('Log'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Weight history — uses the same "protein" green as the
            // Onboarding weight page, since this is the same semantic
            // reading: a live, current-state figure. Always formatted in
            // whatever unit the two fields above are currently using.
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
                    final date = DayBoundary.parseToLocal(
                        log['logged_at'].toString());
                    final unitAbbrev =
                        weightUnitOptions.firstWhere((o) => o.value == weightUnit).abbrev;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.protein.withOpacity(0.14),
                        child: Icon(Icons.monitor_weight,
                            color: colors.protein, size: 20),
                      ),
                      title: Text(
                        '${_formatWeightFromKg((log['weight'] as num? ?? 0), weightUnit)} $unitAbbrev',
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
  /// Optional inline unit-dropdown control. When provided, it renders
  /// after the numeric field instead of a static suffix — used for
  /// Target Weight / Target Water, which now have a selectable unit
  /// rather than a fixed one.
  final Widget? unitControl;

  const _GoalField({
    required this.label,
    required this.controller,
    required this.unit,
    this.accentColor,
    this.unitControl,
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
          width: unitControl != null ? 70 : 80,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: AppFonts.mono(fontSize: 14, color: colors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              suffixText: unitControl == null ? unit : null,
              suffixStyle: TextStyle(
                  color: accentColor ?? colors.textMuted, fontSize: 12),
            ),
          ),
        ),
        if (unitControl != null) ...[
          const SizedBox(width: 8),
          unitControl!,
        ],
      ],
    );
  }
}