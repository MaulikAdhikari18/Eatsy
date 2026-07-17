import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/unit_converter.dart';
import '../../core/utils/serving_format.dart';
import 'unit_dropdown.dart';

/// Quantity + Measure picker shown before a food gets logged.
///
/// This replaced an earlier version where "serving size" was just a
/// free-text label with no effect on the math — quantity was a plain
/// multiplier on whatever the food's base values represented. That
/// broke down as soon as someone wanted to log "50 tablespoons" of
/// something whose base data was "per 100g": there's no way to turn
/// tablespoons into grams without knowing how many grams the base
/// record actually represents.
///
/// So `baseFood['base_grams']` (see food_data_service.dart) now drives
/// real conversion: total grams = quantity × gramsPerUnit(measure), and
/// nutrition scales from a per-gram rate computed off that. When a
/// food's base_grams is unknown (Open Food Facts didn't have a
/// parseable serving weight), Measure conversion isn't mathematically
/// possible — the picker degrades to the old plain-multiplier behavior
/// rather than showing a number it can't actually back up.
///
/// Quantity formatting (`formatQuantity`) and the "×1.5 · cup" subtitle
/// shown later on logged items (`servingSubtitle`) both come from
/// serving_format.dart — one shared copy instead of three duplicated
/// versions across this file, food_log_screen.dart, and
/// dashboard_screen.dart.
class ServingQuantityPicker extends StatefulWidget {
  final Map<String, dynamic> baseFood;
  final void Function(Map<String, dynamic> scaledFood, String measureLabel,
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
  /// Practical quantity range differs a lot by measure — a single fixed
  /// 0.25–10 (step 0.5) range works fine for servings/cups, but makes
  /// Grams nearly unusable: there's no text field, only +/- steppers,
  /// so reaching something like "150g" would take ~300 taps. Each
  /// measure gets its own sensible range and a default to switch to.
  static const _ranges = <MeasureUnit, _MeasureRange>{
    MeasureUnit.serving: _MeasureRange(min: 0.25, max: 10, step: 0.5, defaultQty: 1),
    MeasureUnit.grams: _MeasureRange(min: 1, max: 1000, step: 10, defaultQty: 100),
    MeasureUnit.cup: _MeasureRange(min: 0.25, max: 8, step: 0.25, defaultQty: 1),
    MeasureUnit.tablespoon: _MeasureRange(min: 0.5, max: 20, step: 0.5, defaultQty: 1),
    MeasureUnit.teaspoon: _MeasureRange(min: 0.5, max: 30, step: 0.5, defaultQty: 1),
    MeasureUnit.ounce: _MeasureRange(min: 0.5, max: 32, step: 0.5, defaultQty: 4),
  };

  _MeasureRange get _range => _ranges[_measure]!;

  MeasureUnit _measure = MeasureUnit.serving;
  double _quantity = 1.0;

  double? get _baseGrams {
    final raw = widget.baseFood['base_grams'];
    return raw == null ? null : (raw as num).toDouble();
  }

  bool get _hasKnownWeight => _baseGrams != null;

  /// The actual scale factor applied to the food's base nutrition
  /// values. With a known base weight this is a real
  /// grams-in/grams-out ratio; without one, it degrades to exactly the
  /// old "quantity is a plain multiplier" behavior (the only thing
  /// still honest without knowing what a gram of this food even means).
  double get _scaleFactor {
    if (!_hasKnownWeight) return _quantity;
    final perUnit =
    UnitConverter.gramsPerMeasureUnit(_measure, baseGrams: _baseGrams);
    if (perUnit == null) return _quantity;
    final totalGrams = perUnit * _quantity;
    return totalGrams / _baseGrams!;
  }

  /// Total grams for the current quantity+measure, for the small
  /// "≈ 360g" readout — null (hidden) when base weight is unknown.
  double? get _totalGrams {
    if (!_hasKnownWeight) return null;
    final perUnit =
    UnitConverter.gramsPerMeasureUnit(_measure, baseGrams: _baseGrams);
    if (perUnit == null) return null;
    return perUnit * _quantity;
  }

  /// Just the unit name ("cup", "g", "serving") with no quantity baked
  /// in — servingSubtitle()'s "×1.5 · cup" format already supplies the
  /// quantity separately, so embedding it here too would show
  /// "×1.5 · 1.5 cup".
  String get _measureLabel =>
      measureUnitOptions.firstWhere((o) => o.value == _measure).abbrev;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _setQuantity(double value) {
    final r = _range;
    setState(() => _quantity = value.clamp(r.min, r.max));
    _notify();
  }

  void _setMeasure(MeasureUnit measure) {
    setState(() {
      _measure = measure;
      // Reset to that measure's own default rather than carrying over
      // a number that means something totally different now — e.g.
      // switching from "2 servings" to Grams shouldn't silently become
      // "2 grams".
      _quantity = _ranges[measure]!.defaultQty;
    });
    _notify();
  }

  void _notify() {
    final base = widget.baseFood;
    double v(String key) => ((base[key] ?? 0) as num).toDouble();
    final factor = _scaleFactor;

    widget.onChanged(
      {
        'food_name': base['food_name'],
        'calories': v('calories') * factor,
        'protein': v('protein') * factor,
        'carbs': v('carbs') * factor,
        'fat': v('fat') * factor,
      },
      _measureLabel,
      _quantity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final base = widget.baseFood;
    double v(String key) => ((base[key] ?? 0) as num).toDouble();
    final factor = _scaleFactor;
    final cal = v('calories') * factor;
    final protein = v('protein') * factor;
    final carbs = v('carbs') * factor;
    final fat = v('fat') * factor;
    final totalGrams = _totalGrams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MEASURE',
              style: AppFonts.mono(
                  fontSize: 10, color: colors.textSecondary, letterSpacing: 1),
            ),
            if (_hasKnownWeight)
              UnitDropdown<MeasureUnit>(
                value: _measure,
                options: measureUnitOptions,
                color: colors.textPrimary,
                onChanged: _setMeasure,
              )
            else
              Text(
                'WEIGHT UNKNOWN',
                style: AppFonts.mono(
                    fontSize: 9, color: colors.textMuted, letterSpacing: 0.5),
              ),
          ],
        ),
        if (!_hasKnownWeight) ...[
          const SizedBox(height: 4),
          Text(
            "This food's exact weight isn't known, so quantity scales "
                "the listed values directly instead of converting between units.",
            style: TextStyle(fontSize: 11, color: colors.textMuted, height: 1.3),
          ),
        ],
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
              onTap: () => _setQuantity(_quantity - _range.step),
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
              onTap: () => _setQuantity(_quantity + _range.step),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // .round(), not .toInt() — matches the app-wide
                      // rounding convention (food_log_screen.dart,
                      // dashboard_screen.dart) so this preview always
                      // matches what shows up after logging, instead of
                      // e.g. "150 kcal" here vs "149 kcal" afterward.
                      Text('${cal.round()} kcal',
                          style: AppFonts.mono(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      if (totalGrams != null) ...[
                        const SizedBox(width: 6),
                        Text('≈ ${totalGrams.round()}g',
                            style: AppFonts.mono(
                                fontSize: 11, color: colors.textMuted)),
                      ],
                    ],
                  ),
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

/// Per-measure quantity bounds: a serving/cup step of 0.5 makes sense,
/// but Grams needs a much wider range and coarser step to be usable
/// with +/- steppers alone (no text field), and Ounce's default of 4
/// (a quarter-pound-ish amount) is a more sensible starting point than
/// 1oz for most foods people actually search for.
class _MeasureRange {
  final double min;
  final double max;
  final double step;
  final double defaultQty;
  const _MeasureRange({
    required this.min,
    required this.max,
    required this.step,
    required this.defaultQty,
  });
}