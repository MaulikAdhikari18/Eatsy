import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/settings/unit_preferences_provider.dart';

/// A compact "unit ▾" chip that opens a dropdown menu of unit options.
/// Meant to sit directly next to the field it controls (e.g. right of a
/// "Target Weight" input), so the unit is changed in context rather than
/// buried in a separate Settings screen — while still reading from and
/// writing to the single shared provider, so every screen showing that
/// data agrees on what unit it's in.
class UnitDropdown<T> extends StatelessWidget {
  final T value;
  final List<UnitOption<T>> options;
  final ValueChanged<T> onChanged;
  final Color? color;

  const UnitDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final current = options.firstWhere((o) => o.value == value);
    final chipColor = color ?? colors.textPrimary;

    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => options
          .map((o) => PopupMenuItem<T>(
        value: o.value,
        child: Row(
          children: [
            if (o.value == value)
              Icon(Icons.check, size: 16, color: colors.accent)
            else
              const SizedBox(width: 16),
            const SizedBox(width: 8),
            Text(
              o.fullLabel,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: o.value == value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.abbrev,
              style: AppFonts.mono(fontSize: 12, fontWeight: FontWeight.w600, color: chipColor),
            ),
            Icon(Icons.arrow_drop_down, size: 16, color: chipColor),
          ],
        ),
      ),
    );
  }
}