import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeightUnit { kg, lb }

enum WaterUnit { ml, liter }

const _weightUnitPrefsKey = 'unit_pref_weight';
const _waterUnitPrefsKey = 'unit_pref_water';

/// Controls the app-wide preferred display unit for weight (kg / lb)
/// and persists it to SharedPreferences, same pattern as
/// ThemeModeController. This is a *display* preference only — every
/// weight value in Supabase (`goals.weight_goal`, `weight_logs.weight`)
/// is always stored in kg regardless of this setting.
class WeightUnitController extends StateNotifier<WeightUnit> {
  WeightUnitController() : super(WeightUnit.kg) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_weightUnitPrefsKey) == 'lb'
        ? WeightUnit.lb
        : WeightUnit.kg;
  }

  Future<void> setUnit(WeightUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _weightUnitPrefsKey, unit == WeightUnit.lb ? 'lb' : 'kg');
  }
}

/// Same idea for water (ml / L). `goals.water_goal_ml` and
/// `water_logs.amount_ml` always stay in ml in Supabase — only the
/// Goals screen and the Dashboard water card read this to decide how
/// to format/label numbers.
class WaterUnitController extends StateNotifier<WaterUnit> {
  WaterUnitController() : super(WaterUnit.ml) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_waterUnitPrefsKey) == 'l'
        ? WaterUnit.liter
        : WaterUnit.ml;
  }

  Future<void> setUnit(WaterUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _waterUnitPrefsKey, unit == WaterUnit.liter ? 'l' : 'ml');
  }
}

final weightUnitProvider =
StateNotifierProvider<WeightUnitController, WeightUnit>(
        (ref) => WeightUnitController());

final waterUnitProvider =
StateNotifierProvider<WaterUnitController, WaterUnit>(
        (ref) => WaterUnitController());