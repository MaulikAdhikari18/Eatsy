import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WaterSummary {
  final int consumedMl;
  final int goalMl;
  const WaterSummary({required this.consumedMl, required this.goalMl});
}

// Separate from dashboardRefreshProvider on purpose — logging water
// shouldn't trigger a refetch of the whole calorie/macro summary, and
// logging food shouldn't refetch water totals either.
final waterRefreshProvider = StateProvider<int>((ref) => 0);

final waterSummaryProvider = FutureProvider<WaterSummary>((ref) async {
  ref.watch(waterRefreshProvider);

  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  const fallback = WaterSummary(consumedMl: 0, goalMl: 2000);
  if (userId == null) return fallback;

  try {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final logsResponse = await supabase
        .from('water_logs')
        .select('amount_ml')
        .eq('user_id', userId)
        .gte('logged_at', startOfDay.toIso8601String())
        .lt('logged_at', endOfDay.toIso8601String());

    int consumed = 0;
    for (final row in (logsResponse as List)) {
      consumed += ((row['amount_ml'] ?? 0) as num).toInt();
    }

    // water_goal_ml on `goals` is optional — most users won't have set
    // one explicitly, so 2000ml (~8 glasses) is a sane default rather
    // than showing "0 / 0 ml".
    final goalsRow = await supabase
        .from('goals')
        .select('water_goal_ml')
        .eq('user_id', userId)
        .maybeSingle();

    final goal = ((goalsRow?['water_goal_ml'] ?? 2000) as num).toInt();

    return WaterSummary(consumedMl: consumed, goalMl: goal);
  } catch (e) {
    return fallback;
  }
});

Future<void> logWaterMl(int amountMl) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  await supabase.from('water_logs').insert({
    'user_id': userId,
    'amount_ml': amountMl,
    'logged_at': DateTime.now().toIso8601String(),
  });
}