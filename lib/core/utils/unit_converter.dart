/// Conversion helpers for the optional imperial display units (lb, L).
///
/// Deliberately narrow: all persisted data — `goals.weight_goal`,
/// `weight_logs.weight`, `goals.water_goal_ml`, `water_logs.amount_ml` —
/// stays in metric (kg, ml) no matter what the user has chosen to see.
/// Screens convert to the display unit only at render time, and convert
/// back to metric only right before writing to Supabase. This keeps the
/// data model unambiguous even if the user flips units back and forth,
/// or if two people on different unit preferences share the same
/// backend data.
class UnitConverter {
  static const double kgPerLb = 0.45359237;

  static double kgToLb(double kg) => kg / kgPerLb;
  static double lbToKg(double lb) => lb * kgPerLb;

  static double mlToL(num ml) => ml / 1000.0;
  static double lToMl(double l) => l * 1000.0;
}