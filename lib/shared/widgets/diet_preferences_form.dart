import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../features/preferences/models/diet_preferences.dart';

/// The cuisine/diet-type/allergy/medical-condition selection UI, shared
/// between the standalone Diet Preferences screen (reached from Goals)
/// and the onboarding wizard's diet-preferences step. Deliberately does
/// NOT include a save button or a screen-level intro card — those differ
/// between the two hosts (the standalone screen has its own AppBar +
/// Save button; onboarding uses the wizard's shared Continue button and
/// a different intro treatment), so the two callers compose this with
/// whatever wrapper makes sense for their context.
class DietPreferencesForm extends StatelessWidget {
  final List<String> selectedCuisines;
  final List<String> selectedAllergies;
  final String selectedDietType;
  final List<String> selectedConditions;
  final ValueChanged<String> onToggleCuisine;
  final ValueChanged<String> onToggleAllergy;
  final ValueChanged<String> onToggleCondition;
  final ValueChanged<String> onDietTypeSelected;

  const DietPreferencesForm({
    super.key,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DietSectionLabel('🌏 Cuisines you enjoy', colors),
        const SizedBox(height: 4),
        DietSectionHint('SELECT ALL THAT APPLY', colors),
        const SizedBox(height: 12),
        DietChipGroup(
          options: DietPreferenceOptions.cuisines,
          selected: selectedCuisines,
          onToggle: onToggleCuisine,
          chipColor: colors.protein,
        ),

        const SizedBox(height: 28),
        DietSectionLabel('🍽️ Diet type', colors),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DietPreferenceOptions.dietTypes.map((type) {
            final isSelected = selectedDietType == type['key'];
            return GestureDetector(
              onTap: () => onDietTypeSelected(type['key']!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? colors.labelCard : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? colors.labelCard : colors.divider,
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
        DietSectionLabel('⚠️ Allergies / intolerances', colors),
        const SizedBox(height: 4),
        DietSectionHint("WE'LL EXCLUDE THESE FROM EVERY PLAN", colors),
        const SizedBox(height: 12),
        DietChipGroup(
          options: DietPreferenceOptions.allergies,
          selected: selectedAllergies,
          onToggle: onToggleAllergy,
          chipColor: colors.fat,
        ),

        const SizedBox(height: 28),
        DietSectionLabel('🩺 Known medical conditions', colors),
        const SizedBox(height: 4),
        DietSectionHint(
            'OPTIONAL — HELPS US TAILOR SODIUM, SUGAR & GI FOCUS', colors),
        const SizedBox(height: 12),
        DietChipGroup(
          options: DietPreferenceOptions.medicalConditions,
          selected: selectedConditions,
          onToggle: onToggleCondition,
          chipColor: colors.dinner,
        ),
      ],
    );
  }
}

class DietSectionLabel extends StatelessWidget {
  final String text;
  final AppColors colors;
  const DietSectionLabel(this.text, this.colors, {super.key});

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
class DietSectionHint extends StatelessWidget {
  final String text;
  final AppColors colors;
  const DietSectionHint(this.text, this.colors, {super.key});

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

class DietChipGroup extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final void Function(String) onToggle;
  final Color chipColor;

  const DietChipGroup({
    super.key,
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
                  ? chipColor.withValues(alpha: 0.14)
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