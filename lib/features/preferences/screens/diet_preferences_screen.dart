import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diet_preferences.dart';
import '../controllers/diet_preferences_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';

class DietPreferencesScreen extends ConsumerStatefulWidget {
  const DietPreferencesScreen({super.key});

  @override
  ConsumerState<DietPreferencesScreen> createState() =>
      _DietPreferencesScreenState();
}

class _DietPreferencesScreenState
    extends ConsumerState<DietPreferencesScreen> {
  List<String> _selectedCuisines = [];
  List<String> _selectedAllergies = [];
  String _selectedDietType = 'no_restriction';
  List<String> _selectedConditions = [];
  bool _initialized = false;
  bool _isSaving = false;

  void _initFromPrefs(DietPreferences? prefs) {
    if (_initialized || prefs == null) return;
    _selectedCuisines = List.from(prefs.cuisines);
    _selectedAllergies = List.from(prefs.allergies);
    _selectedDietType = prefs.dietType;
    _selectedConditions = List.from(prefs.medicalConditions);
    _initialized = true;
  }

  void _toggle(List<String> list, String value) {
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else {
        list.add(value);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final prefs = DietPreferences(
      cuisines: _selectedCuisines,
      allergies: _selectedAllergies,
      dietType: _selectedDietType,
      medicalConditions: _selectedConditions,
    );
    final success = await ref
        .read(dietPreferencesControllerProvider.notifier)
        .save(prefs);

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Diet preferences saved!'
            : 'Error saving preferences — please try again'),
        backgroundColor: success ? AppTheme.primary : Colors.red,
      ),
    );
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final prefsAsync = ref.watch(dietPreferencesProvider);

    // One-time hydrate of local selection state once data arrives.
    prefsAsync.whenData(_initFromPrefs);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Diet Preferences',
            style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: prefsAsync.isLoading && !_initialized
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'These personalize your AI-generated meal plan — '
                  'cuisine, allergies, and any dietary or medical '
                  'considerations get factored into every plan we generate.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 28),

            _SectionLabel('🌏 Cuisines you enjoy', colors),
            const SizedBox(height: 4),
            Text('Select all that apply',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            _ChipGroup(
              options: DietPreferenceOptions.cuisines,
              selected: _selectedCuisines,
              onToggle: (v) => _toggle(_selectedCuisines, v),
            ),

            const SizedBox(height: 28),
            _SectionLabel('🍽️ Diet type', colors),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DietPreferenceOptions.dietTypes.map((type) {
                final isSelected = _selectedDietType == type['key'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedDietType = type['key']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : colors.divider,
                      ),
                    ),
                    child: Text(
                      type['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : colors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            _SectionLabel('⚠️ Allergies / intolerances', colors),
            const SizedBox(height: 4),
            Text('We\'ll exclude these from every plan',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            _ChipGroup(
              options: DietPreferenceOptions.allergies,
              selected: _selectedAllergies,
              onToggle: (v) => _toggle(_selectedAllergies, v),
              chipColor: const Color(0xFFE53935),
            ),

            const SizedBox(height: 28),
            _SectionLabel('🩺 Known medical conditions', colors),
            const SizedBox(height: 4),
            Text('Optional — helps us tailor sodium, sugar & GI focus',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            _ChipGroup(
              options: DietPreferenceOptions.medicalConditions,
              selected: _selectedConditions,
              onToggle: (v) => _toggle(_selectedConditions, v),
              chipColor: const Color(0xFF8E24AA),
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text('Save Preferences'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: colors.textPrimary,
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final void Function(String) onToggle;
  final Color chipColor;

  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onToggle,
    this.chipColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return GestureDetector(
          onTap: () => onToggle(option),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? chipColor.withOpacity(0.12)
                  : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? chipColor : colors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check, size: 14, color: chipColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? chipColor : colors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}