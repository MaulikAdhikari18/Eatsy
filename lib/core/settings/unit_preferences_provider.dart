import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeightUnit { kg, lb, stone }

enum WaterUnit { ml, liter, flOz, glasses }

enum HeightUnit { cm, ftIn }

/// Display option metadata for a unit dropdown: `abbrev` is what shows
/// in the compact chip (e.g. "kg"), `fullLabel` is what shows in the
/// dropdown menu itself (e.g. "Kilograms (kg)").
class UnitOption<T> {
  final T value;
  final String abbrev;
  final String fullLabel;
  const UnitOption({required this.value, required this.abbrev, required this.fullLabel});
}

const weightUnitOptions = <UnitOption<WeightUnit>>[
  UnitOption(value: WeightUnit.kg, abbrev: 'kg', fullLabel: 'Kilograms (kg)'),
  UnitOption(value: WeightUnit.lb, abbrev: 'lb', fullLabel: 'Pounds (lb)'),
  UnitOption(value: WeightUnit.stone, abbrev: 'st', fullLabel: 'Stone (st)'),
];

const waterUnitOptions = <UnitOption<WaterUnit>>[
  UnitOption(value: WaterUnit.ml, abbrev: 'ml', fullLabel: 'Milliliters (ml)'),
  UnitOption(value: WaterUnit.liter, abbrev: 'L', fullLabel: 'Liters (L)'),
  UnitOption(value: WaterUnit.flOz, abbrev: 'fl oz', fullLabel: 'Fluid ounces (US)'),
  UnitOption(value: WaterUnit.glasses, abbrev: 'glass', fullLabel: 'Glasses (~250ml)'),
];

const heightUnitOptions = <UnitOption<HeightUnit>>[
  UnitOption(value: HeightUnit.cm, abbrev: 'cm', fullLabel: 'Centimeters (cm)'),
  UnitOption(value: HeightUnit.ftIn, abbrev: 'ft', fullLabel: 'Feet (decimal)'),
];

const _weightUnitPrefsKey = 'unit_pref_weight';
const _waterUnitPrefsKey = 'unit_pref_water';
const _heightUnitPrefsKey = 'unit_pref_height';

/// Controls the app-wide preferred display unit for weight and persists
/// it to SharedPreferences, same pattern as ThemeModeController. This is
/// a *display* preference only — every weight value in Supabase
/// (`goals.weight_goal`, `weight_logs.weight`) is always stored in kg
/// regardless of this setting.
class WeightUnitController extends StateNotifier<WeightUnit> {
  WeightUnitController() : super(WeightUnit.kg) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_weightUnitPrefsKey);
    state = switch (saved) {
      'lb' => WeightUnit.lb,
      'st' => WeightUnit.stone,
      _ => WeightUnit.kg,
    };
  }

  Future<void> setUnit(WeightUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    final key = switch (unit) {
      WeightUnit.lb => 'lb',
      WeightUnit.stone => 'st',
      WeightUnit.kg => 'kg',
    };
    await prefs.setString(_weightUnitPrefsKey, key);
  }
}

/// Same idea for water (ml / L / fl oz / glasses). `goals.water_goal_ml`
/// and `water_logs.amount_ml` always stay in ml in Supabase — only the
/// Goals screen and the Dashboard water card read this to decide how to
/// format/label numbers.
class WaterUnitController extends StateNotifier<WaterUnit> {
  WaterUnitController() : super(WaterUnit.ml) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_waterUnitPrefsKey);
    state = switch (saved) {
      'l' => WaterUnit.liter,
      'floz' => WaterUnit.flOz,
      'glasses' => WaterUnit.glasses,
      _ => WaterUnit.ml,
    };
  }

  Future<void> setUnit(WaterUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    final key = switch (unit) {
      WaterUnit.liter => 'l',
      WaterUnit.flOz => 'floz',
      WaterUnit.glasses => 'glasses',
      WaterUnit.ml => 'ml',
    };
    await prefs.setString(_waterUnitPrefsKey, key);
  }
}

/// Same idea for height (cm / ft). `goals.height_cm` always stays in cm
/// in Supabase.
class HeightUnitController extends StateNotifier<HeightUnit> {
  HeightUnitController() : super(HeightUnit.cm) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_heightUnitPrefsKey) == 'ft'
        ? HeightUnit.ftIn
        : HeightUnit.cm;
  }

  Future<void> setUnit(HeightUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_heightUnitPrefsKey, unit == HeightUnit.ftIn ? 'ft' : 'cm');
  }
}

final weightUnitProvider =
StateNotifierProvider<WeightUnitController, WeightUnit>((ref) => WeightUnitController());

final waterUnitProvider =
StateNotifierProvider<WaterUnitController, WaterUnit>((ref) => WaterUnitController());

final heightUnitProvider =
StateNotifierProvider<HeightUnitController, HeightUnit>((ref) => HeightUnitController());