import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';

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
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _weightLogs = [];
  String _selectedGoalType = 'lose';

  final List<Map<String, String>> _goalTypes = [
    {'key': 'lose', 'label': 'Lose Weight', 'icon': '📉'},
    {'key': 'maintain', 'label': 'Maintain', 'icon': '⚖️'},
    {'key': 'gain', 'label': 'Gain Weight', 'icon': '📈'},
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goals saved successfully!'),
            backgroundColor: AppTheme.primary,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weight logged!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging weight: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Goals & Tracking',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal type selector
            Text(
              'My Goal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
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
                            ? AppTheme.primary
                            : colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
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
                  border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant_menu,
                          color: AppTheme.primary, size: 20),
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

            // Calorie & Macro Goals
            Text(
              'Daily Targets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
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
                  ),
                  Divider(height: 24, color: colors.divider),
                  _GoalField(
                    label: '🌾 Carbohydrates',
                    controller: _carbsController,
                    unit: 'g',
                  ),
                  Divider(height: 24, color: colors.divider),
                  _GoalField(
                    label: '🥑 Fat',
                    controller: _fatController,
                    unit: 'g',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Weight Goal
            Text(
              'Weight Goal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
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
              ),
            ),

            const SizedBox(height: 16),

            // Save button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveGoals,
              child: _isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text('Save Goals'),
            ),

            const SizedBox(height: 24),

            // Log weight
            Text(
              'Log Today\'s Weight',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
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

            // Weight history
            if (_weightLogs.isNotEmpty) ...[
              Text(
                'Weight History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
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
                        backgroundColor: AppTheme.primary.withOpacity(0.12),
                        child: const Icon(Icons.monitor_weight,
                            color: AppTheme.primary, size: 20),
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

class _GoalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String unit;

  const _GoalField({
    required this.label,
    required this.controller,
    required this.unit,
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
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              suffixText: unit,
              suffixStyle: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}