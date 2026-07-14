import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/serving_format.dart';
import '../../core/utils/unit_converter.dart';
import 'unit_dropdown.dart';

/// Per-measure stepper tuning. A single step/range that works for
/// "servings" (step 0.5, max 20) is unusable for "grams" (nobody wants
/// to tap +0.5 forty times to reach 250g) or sensible for "oz" either
/// — each measure gets its own step/range/starting value.
class _MeasureConfig {
  final double min, step, max, defaultQty;
  const _MeasureConfig(this.min, this.step, this.max, this.defaultQty);
}

const _measureConfigs = <MeasureUnit, _MeasureConfig>{
  MeasureUnit.serving: _MeasureConfig(0.25, 0.5, 20, 1),
  MeasureUnit.grams: _MeasureConfig(10, 10, 1000, 100),
  MeasureUnit.cup: _MeasureConfig(0.25, 0.25, 10, 1),
  MeasureUnit.tablespoon: _MeasureConfig(0.5, 0.5, 20, 1),
  MeasureUnit.teaspoon: _MeasureConfig(0.5, 0.5, 30, 1),
  MeasureUnit.ounce: _MeasureConfig(0.5, 0.5, 32, 4),
};

/// Quantity + Measure picker shown between "a food was found" and "add
/// it to the log". `baseFood` is treated as the per-`base_grams` values
/// — whatever food_data_service.dart returned (Open Food Facts or the
/// local fallback DB), unscaled.
///
/// Gram-based scaling (letting the user say "2 tbsp" or "150g" instead
/// of just "×2 servings") is only possible when `baseFood['base_grams']`
/// is known — see food_data_service.dart's `_mapProduct`/`_parseGrams`
/// for when that can legitimately be null (a product's serving_size
/// text didn't contain a parseable gram figure). When it's null, this
/// degrades honestly to the old plain-quantity-multiplier behavior
/// instead of pretending to support unit conversion it can't back up —
/// same principle food_data_service.dart already follows by returning
/// null rather than guessing.
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
  double _quantity = 1.0;
  MeasureUnit _measure = MeasureUnit.serving;

  double? get _baseGrams {
    final raw = widget.baseFood['base_grams'];
    return raw == null ? null : (raw as num).toDouble();
  }

  bool get _hasGramBasis => _baseGrams != null;

  _MeasureConfig get _config => _measureConfigs[_measure]!;

  @override
  void initState() {
    super.initState();
    _quantity = _config.defaultQty;
    // Fire once on mount so the caller has scaled values immediately,
    // not just after the first edit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _setQuantity(double value) {
    setState(() => _quantity = value.clamp(_config.min, _config.max));
    _notify();
  }

  void _setMeasure(MeasureUnit measure) {
    setState(() {
      _measure = measure;
      // Reset to that measure's sensible default rather than carrying
      // over a number that made sense for the old measure but not the
      // new one (e.g. "0.5" was a reasonable cup count; it's a
      // nonsensical 0.5g).
      _quantity = _measureConfigs[measure]!.defaultQty;
    });
    _notify();
  }

  /// Total grams this quantity+measure represents, or null if this
  /// food has no known gram baseline at all (see class doc above).
  double? get _totalGrams {
    if (!_hasGramBasis) return null;
    final perUnit =
    UnitConverter.gramsPerMeasureUnit(_measure, baseGrams: _baseGrams);
    if (perUnit == null) return null;
    return perUnit * _quantity;
  }

  /// Scales baseFood's calories/protein/carbs/fat for the current
  /// quantity+measure. Shared by _notify() and build() so the "what
  /// scaling logic applies" decision lives in exactly one place.
  Map<String, double> _computeScaled() {
    final base = widget.baseFood;
    double v(String key) => ((base[key] ?? 0) as num).toDouble();

    final totalGrams = _totalGrams;
    if (_hasGramBasis && totalGrams != null) {
      final scaleFactor = totalGrams / _baseGrams!;
      return {
        'calories': v('calories') * scaleFactor,
        'protein': v('protein') * scaleFactor,
        'carbs': v('carbs') * scaleFactor,
        'fat': v('fat') * scaleFactor,
      };
    }
    // No gram baseline — plain quantity multiplier, same as this
    // widget's original pre-Measure behavior.
    return {
      'calories': v('calories') * _quantity,
      'protein': v('protein') * _quantity,
      'carbs': v('carbs') * _quantity,
      'fat': v('fat') * _quantity,
    };
  }

  void _notify() {
    final scaled = _computeScaled();
    final measureAbbrev =
        measureUnitOptions.firstWhere((o) => o.value == _measure).abbrev;

    widget.onChanged(
      {'food_name': widget.baseFood['food_name'], ...scaled},
      '${formatQuantity(_quantity)} $measureAbbrev',
      _quantity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scaled = _computeScaled();
    final cal = scaled['calories']!;
    final protein = scaled['protein']!;
    final carbs = scaled['carbs']!;
    final fat = scaled['fat']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onTap: () => _setQuantity(_quantity - _config.step),
            ),
            Expanded(
              child: Text(
                formatQuantity(_quantity),
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
              onTap: () => _setQuantity(_quantity + _config.step),
            ),
            // Measure selector only makes sense — and only appears —
            // when there's an actual gram baseline to convert against.
            // Without base_grams, "grams"/"cup"/"tbsp" would all be
            // fake options that silently do nothing when picked, which
            // is worse than not offering them.
            if (_hasGramBasis) ...[
              const SizedBox(width: 10),
              UnitDropdown<MeasureUnit>(
                value: _measure,
                options: measureUnitOptions,
                onChanged: _setMeasure,
              ),
            ],
          ],
        ),
        if (!_hasGramBasis) ...[
          const SizedBox(height: 6),
          Text(
            'Weight-based measures aren\'t available for this food — '
                'quantity scales the listed serving directly.',
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
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