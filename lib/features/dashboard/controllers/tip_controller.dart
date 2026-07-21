import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/day_boundary.dart';
import 'dashboard_controller.dart';
import 'water_controller.dart';

enum TipCategory { engagement, nutrition, hydration, general }

class DailyTip {
  final String message;
  final TipCategory category;
  const DailyTip({required this.message, required this.category});
}

/// "AI Tip of the Day" (implementation guide, Section 5.3). The guide
/// describes this as a nightly cron job on a separate backend that
/// evaluates a rule table, then calls an LLM to phrase the message —
/// Eatsy has no backend service, so this evaluates the same rules live,
/// client-side, whenever the Dashboard loads or new data is logged.
///
/// Only three rules from the guide's table are implemented — the ones
/// that depend purely on food/water logging, which Eatsy already has.
/// Everything else in that table (sleep, steps, resting heart rate,
/// blood pressure) needs Section 2's wearable/HealthKit/Health Connect
/// integration, which doesn't exist in this app, so those rules aren't
/// reachable and are intentionally left out rather than faked.
///
/// Messages are hardcoded rather than LLM-generated: the guide's own
/// example messages are already good, specific, and free — no API
/// cost or latency for a tip whose logic is this simple.
final dailyTipProvider = FutureProvider<DailyTip>((ref) async {
  // Same refresh triggers as the rest of the dashboard, so logging a
  // meal or a glass of water immediately re-evaluates the tip instead
  // of waiting for the next cold load.
  ref.watch(dashboardRefreshProvider);
  ref.watch(waterRefreshProvider);

  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  final now = DateTime.now();

  const loggedOutTip = DailyTip(
    message: 'Log in to get a personalized tip based on your day.',
    category: TipCategory.general,
  );
  if (userId == null) return loggedOutTip;

  try {
    final startOfDay = DayBoundary.startOfLocalDay(now);
    final endOfDay = DayBoundary.endOfLocalDay(now);

    final foodLogs = await supabase
        .from('food_logs')
        .select('calories')
        .eq('user_id', userId)
        .gte('logged_at', startOfDay.toIso8601String())
        .lt('logged_at', endOfDay.toIso8601String());

    final waterLogs = await supabase
        .from('water_logs')
        .select('amount_ml')
        .eq('user_id', userId)
        .gte('logged_at', startOfDay.toIso8601String())
        .lt('logged_at', endOfDay.toIso8601String());

    final goalsRow = await supabase
        .from('goals')
        .select('gender')
        .eq('user_id', userId)
        .maybeSingle();

    final foodRows = foodLogs as List;
    final hasLoggedFood = foodRows.isNotEmpty;
    final caloriesConsumed = foodRows.fold<double>(
        0, (sum, row) => sum + ((row['calories'] ?? 0) as num).toDouble());

    final waterConsumedMl = (waterLogs as List).fold<int>(
        0, (sum, row) => sum + ((row['amount_ml'] ?? 0) as num).toInt());

    // Same default as elsewhere in the app (goals_screen.dart) when no
    // gender is set yet.
    final gender = goalsRow?['gender']?.toString() ?? 'female';
    final calorieFloor = gender == 'male' ? 1400 : 1200;

    // Priority order matters: "you haven't eaten at all" is the most
    // actionable nudge, so it wins if true. The other two only make
    // sense to judge once enough of the day has actually passed —
    // flagging someone as "under target" at 9am, before they've had
    // lunch, would just be wrong, not helpful.
    if (now.hour >= 14 && !hasLoggedFood) {
      return const DailyTip(
        message: 'No meals logged yet today. Skipping meals or logging '
            'late makes it hard to hit your calorie targets — log '
            'breakfast even if it was simple.',
        category: TipCategory.engagement,
      );
    }

    if (now.hour >= 18 && hasLoggedFood && caloriesConsumed < calorieFloor) {
      return DailyTip(
        message: "You're at ${caloriesConsumed.toInt()} kcal today — "
            'well below your target. Severe restriction slows '
            'metabolism and causes muscle loss. Aim for at least '
            '$calorieFloor kcal.',
        category: TipCategory.nutrition,
      );
    }

    if (now.hour >= 18 && waterConsumedMl < 1500) {
      final liters = (waterConsumedMl / 1000).toStringAsFixed(1);
      return DailyTip(
        message: "You've logged only ${liters}L today. Dehydration "
            'mimics hunger and raises heart rate — drink a glass of '
            'water before your next meal.',
        category: TipCategory.hydration,
      );
    }

    return const DailyTip(
      message: "You're on track today — keep logging your meals and "
          'water to stay on top of your goals.',
      category: TipCategory.general,
    );
  } catch (e) {
    return const DailyTip(
      message: 'Log your meals and water today to get a personalized tip.',
      category: TipCategory.general,
    );
  }
});

/// Dismissing the tip is session-only (resets on app restart) — there's
/// no `health_suggestions` table backing this, since that would need
/// the cron job this provider is deliberately standing in for. If you
/// want "dismissed" to persist across restarts later, this is the spot
/// to swap for a real table + is_dismissed column, matching the guide's
/// schema in Section 6.2.
final tipDismissedProvider = StateProvider<bool>((ref) => false);