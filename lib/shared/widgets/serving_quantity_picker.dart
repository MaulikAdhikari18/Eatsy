import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';

/// Serving size (free text, purely a label) + quantity (the actual
/// multiplier) picker shown between "a food was found" and "add it to
/// the log". `baseFood` is treated as the per-1-unit values — whatever
/// Open Food Facts or the local fallback DB returned, unscaled.
///
/// Deliberately NOT trying to parse the serving-size text to drive the
/// math: neither Open Food Facts nor the local DB reliably expose
/// multiple structured serving options the way FatSecret's old
/// `servings.serving` array did, so quantity is the one real control —
/// serving size just documents what "1×" means for this food.
class ServingQuantityPicker extends StatefulWidget {
  final Map<String, dynamic> baseFood;
  final void Function(Map<String, dynamic> scaledFood, String servingSize,
      double quantity) onChanged;

  const ServingQuantityPicker({
    super.key,
    required this.baseFood,
    required this.onChanged,
  });

  @override
  State<ServingQuantityPicker> createState() => ServingQuantityPickerState();
}

class ServingQuantityPickerState extends State<ServingQuantityPicker> {
  static const _minQty = 0.25;
  static const _maxQty = 10.0;
  static const _step = 0.5;

  late final TextEditingController _servingController;
  double _quantity = 1.0;

  @override
  void initState() {
    super.initState();
    _servingController = TextEditingController(text: _defaultServingLabel());
    // Fire once on mount so the caller has scaled values immediately,
    // not just after the first edit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  /// Best-effort starting point pulled from the food name's trailing
  /// parenthetical — e.g. "White Rice (1 cup)" -> "1 cup",
  /// "Paneer Butter Masala (per 100g)" -> "100g". Falls back to
  /// "1 serving" when nothing usable is found. The field stays fully
  /// editable either way.
  String _defaultServingLabel() {
    final name = widget.baseFood['food_name']?.toString() ?? '';
    final match = RegExp(r'\(([^)]+)\)\s*$').firstMatch(name);
    if (match != null) {
      var label = match.group(1)!.trim();
      if (label.toLowerCase().startsWith('per ')) {
        label = label.substring(4).trim();
      }
      if (label.isNotEmpty) return label;
    }
    return '1 serving';
  }

  @override
  void dispose() {
    _servingController.dispose();
    super.dispose();
  }

  void _setQuantity(double value) {
    setState(() => _quantity = value.clamp(_minQty, _maxQty));
    _notify();
  }

  void _notify() {
    final base = widget.baseFood;
    double v(String key) => ((base[key] ?? 0) as num).toDouble();

    widget.onChanged(
      {
        'food_name': base['food_name'],
        'calories': v('calories') * _quantity,
        'protein': v('protein') * _quantity,
        'carbs': v('carbs') * _quantity,
        'fat': v('fat') * _quantity,
      },
      _servingController.text.trim().isEmpty
          ? '1 serving'
          : _servingController.text.trim(),
      _quantity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final base = widget.baseFood;
    double v(String key) => ((base[key] ?? 0) as num).toDouble();
    final cal = v('calories') * _quantity;
    final protein = v('protein') * _quantity;
    final carbs = v('carbs') * _quantity;
    final fat = v('fat') * _quantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERVING SIZE',
          style: AppFonts.mono(
              fontSize: 10, color: colors.textSecondary, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _servingController,
          onChanged: (_) => _notify(),
          decoration: const InputDecoration(hintText: 'e.g. 1 cup, 100g'),
        ),
        const SizedBox(height: 16),
        Text(
          'QUANTITY',
          style: AppFonts.mono(
              fontSize: 10, color: colors.textSecondary, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove,
              onTap: () => _setQuantity(_quantity - _step),
            ),
            Expanded(
              child: Text(
                // Whole numbers show as "1.0", not "1.0000000001" from
                // float subtraction — round to 2dp then trim.
                _quantity.toStringAsFixed(2).replaceFirst(
                    RegExp(r'0$'), ''),
                textAlign: TextAlign.center,
                style: AppFonts.mono(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              filled: true,
              onTap: () => _setQuantity(_quantity + _step),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ADJUSTED TOTAL',
                      style: AppFonts.mono(
                          fontSize: 11,
                          color: colors.textMuted,
                          letterSpacing: 0.5)),
                  Text('${cal.round()} kcal',
                      style: AppFonts.mono(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniMacroText(
                      label: 'PROTEIN',
                      value: '${protein.round()}g',
                      color: colors.protein),
                  const SizedBox(width: 16),
                  _MiniMacroText(
                      label: 'CARBS',
                      value: '${carbs.round()}g',
                      color: colors.carbs),
                  const SizedBox(width: 16),
                  _MiniMacroText(
                      label: 'FAT',
                      value: '${fat.round()}g',
                      color: colors.fat),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _StepButton(
      {required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: filled ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: colors.divider),
        ),
        child: Icon(icon,
            size: 18, color: filled ? colors.accentOnColor : colors.textPrimary),
      ),
    );
  }
}

class _MiniMacroText extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniMacroText(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppFonts.mono(fontSize: 9, color: color, letterSpacing: 0.3)),
        Text(value,
            style: AppFonts.mono(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}