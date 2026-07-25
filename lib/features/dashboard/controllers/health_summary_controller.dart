import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/day_boundary.dart';

class HealthTodaySummary {
  final int? steps;
  final double? activeCalories;
  final double? heartRateAvg;
  final int? sleepMinutes;
  final double? weightKg;

  /// True only if a row actually exists in health_daily_summary for
  /// today. Deliberately NOT the same as "connected" — someone can be
  /// connected but not yet synced today (e.g. right after connecting,
  /// before the first sync's data has anything for "today" yet if
  /// their phone genuinely has zero steps recorded so far). The
  /// Dashboard card treats hasData == false as "show a prompt to
  /// connect/open Health Data" either way, which is a deliberate v1
  /// simplification — see health_summary_controller.dart's own
  /// comment for the full reasoning.
  final bool hasData;

  const HealthTodaySummary({
    this.steps,
    this.activeCalories,
    this.heartRateAvg,
    this.sleepMinutes,
    this.weightKg,
    this.hasData = false,
  });

  static const empty = HealthTodaySummary();
}

/// Bumped by HealthSyncController after a successful sync (see
/// health_sync_controller.dart) so this card refreshes immediately
/// after someone connects or manually syncs from the Connect Health
/// Data screen, rather than only updating on the next cold start.
/// Mirrors the same refresh-provider pattern already used by
/// waterRefreshProvider in dashboard_controller.dart.
final healthSummaryRefreshProvider = StateProvider<int>((ref) => 0);

/// Deliberately queries only TODAY's row rather than checking
/// HealthSyncController's connection status — that would mean an extra
/// native permission-check call on every Dashboard load just to decide
/// whether to show this card, which isn't worth the cost for what's an
/// optional, secondary card. Whether someone is "connected" in the OS
/// permission sense and whether there's a row for today in practice
/// converge almost immediately anyway, since connecting triggers an
/// immediate first sync (see HealthSyncController.connect()).
final healthTodaySummaryProvider =
FutureProvider<HealthTodaySummary>((ref) async {
  ref.watch(healthSummaryRefreshProvider);

  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return HealthTodaySummary.empty;

  try {
    final today = DayBoundary.startOfLocalDay();
    final dateStr = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final row = await supabase
        .from('health_daily_summary')
        .select()
        .eq('user_id', userId)
        .eq('date', dateStr)
        .maybeSingle();

    if (row == null) return HealthTodaySummary.empty;

    return HealthTodaySummary(
      steps: (row['steps'] as num?)?.toInt(),
      activeCalories: (row['active_calories'] as num?)?.toDouble(),
      heartRateAvg: (row['heart_rate_avg'] as num?)?.toDouble(),
      sleepMinutes: (row['sleep_minutes'] as num?)?.toInt(),
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      hasData: true,
    );
  } catch (e) {
    return HealthTodaySummary.empty;
  }
});