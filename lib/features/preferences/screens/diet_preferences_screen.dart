import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diet_preferences.dart';
import '../controllers/diet_preferences_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/diet_preferences_form.dart';

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
    final colors = context.appColors;
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
        content: Text(
          success
              ? 'Diet preferences saved!'
              : 'Error saving preferences — please try again',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: success ? colors.labelCard : colors.fat,
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
        title: const Text('Diet Preferences'),
      ),
      body: prefsAsync.isLoading && !_initialized
          ? Center(
          child: CircularProgressIndicator(color: colors.accent))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro — framed like the mono eyebrow tags used everywhere
            // else, so this reads as part of the same design system
            // rather than a plain paragraph.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: colors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'These personalize your AI-generated meal plan — '
                          'cuisine, allergies, and any dietary or medical '
                          'considerations get factored into every plan we generate.',
                      style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            DietPreferencesForm(
              selectedCuisines: _selectedCuisines,
              selectedAllergies: _selectedAllergies,
              selectedDietType: _selectedDietType,
              selectedConditions: _selectedConditions,
              onToggleCuisine: (v) => _toggle(_selectedCuisines, v),
              onToggleAllergy: (v) => _toggle(_selectedAllergies, v),
              onToggleCondition: (v) => _toggle(_selectedConditions, v),
              onDietTypeSelected: (key) =>
                  setState(() => _selectedDietType = key),
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: colors.accentOnColor,
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