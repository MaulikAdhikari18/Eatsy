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

            _SectionLabel('🌏 Cuisines you enjoy', colors),
            const SizedBox(height: 4),
            _SectionHint('SELECT ALL THAT APPLY', colors),
            const SizedBox(height: 12),
            _ChipGroup(
              options: DietPreferenceOptions.cuisines,
              selected: _selectedCuisines,
              onToggle: (v) => _toggle(_selectedCuisines, v),
              chipColor: colors.protein,
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
                          ? colors.labelCard
                          : colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? colors.labelCard
                            : colors.divider,
                      ),
                    ),
                    child: Text(
                      type['label']!,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : colors.textSecondary,
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
            _SectionHint("WE'LL EXCLUDE THESE FROM EVERY PLAN", colors),
            const SizedBox(height: 12),
            _ChipGroup(
              options: DietPreferenceOptions.allergies,
              selected: _selectedAllergies,
              onToggle: (v) => _toggle(_selectedAllergies, v),
              chipColor: colors.fat,
            ),

            const SizedBox(height: 28),
            _SectionLabel('🩺 Known medical conditions', colors),
            const SizedBox(height: 4),
            _SectionHint(
                'OPTIONAL — HELPS US TAILOR SODIUM, SUGAR & GI FOCUS',
                colors),
            const SizedBox(height: 12),
            _ChipGroup(
              options: DietPreferenceOptions.medicalConditions,
              selected: _selectedConditions,
              onToggle: (v) => _toggle(_selectedConditions, v),
              chipColor: colors.dinner,
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
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
      ),
    );
  }
}

/// Small mono uppercase hint text — same eyebrow-label treatment used for
/// field labels and data tags elsewhere in the app.
class _SectionHint extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionHint(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppFonts.mono(
        fontSize: 10,
        color: colors.textMuted,
        letterSpacing: 0.6,
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
    required this.chipColor,
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
                  ? chipColor.withOpacity(0.14)
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