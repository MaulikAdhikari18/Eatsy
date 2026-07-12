/// Conversion helpers for every optional display unit in the app.
///
/// Deliberately narrow: all persisted data — `goals.weight_goal`,
/// `weight_logs.weight`, `goals.water_goal_ml`, `water_logs.amount_ml`,
/// `goals.height_cm` — stays in metric (kg, ml, cm) no matter what the
/// user has chosen to see. Screens convert to the display unit only at
/// render time, and convert back to metric only right before writing to
/// Supabase. This keeps the data model unambiguous even if the user
/// flips units back and forth, or if two people on different unit
/// preferences share the same backend data.
class UnitConverter {
  static const double kgPerLb = 0.45359237;
  static const double lbPerStone = 14;
  static const double mlPerFlOzUS = 29.5735;
  static const double mlPerGlass = 250; // approximate — common health-app convention (240-250ml)
  static const double cmPerFoot = 30.48;
  static const double cmPerInch = 2.54;

  // --- Weight ---
  static double kgToLb(double kg) => kg / kgPerLb;
  static double lbToKg(double lb) => lb * kgPerLb;

  static double kgToStone(double kg) => kgToLb(kg) / lbPerStone;
  static double stoneToKg(double stone) => lbToKg(stone * lbPerStone);

  /// Compound display only, e.g. "11 st 4 lb" — used as a caption under
  /// the editable decimal-stone field so the number stays intuitive
  /// even though the underlying input is a single decimal value.
  static String kgToStoneLabel(double kg) {
    final totalLb = kgToLb(kg);
    final stone = (totalLb / lbPerStone).floor();
    final remainderLb = (totalLb - stone * lbPerStone).round();
    return '$stone st $remainderLb lb';
  }

  // --- Water ---
  static double mlToL(num ml) => ml / 1000.0;
  static double lToMl(double l) => l * 1000.0;

  static double mlToFlOz(num ml) => ml / mlPerFlOzUS;
  static double flOzToMl(double flOz) => flOz * mlPerFlOzUS;

  static double mlToGlasses(num ml) => ml / mlPerGlass;
  static double glassesToMl(double glasses) => glasses * mlPerGlass;

  // --- Height ---
  static double cmToFt(double cm) => cm / cmPerFoot;
  static double ftToCm(double ft) => ft * cmPerFoot;

  /// Compound display only, e.g. `5'6"` — same caption pattern as
  /// kgToStoneLabel, shown under the editable decimal-feet field.
  static String cmToFeetInchesLabel(double cm) {
    final totalInches = cm / cmPerInch;
    final feet = (totalInches / 12).floor();
    final inches = (totalInches - feet * 12).round();
    return '$feet\'$inches"';
  }
}