import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/day_boundary.dart';
import 'dashboard_controller.dart';
import 'health_summary_controller.dart';
import 'water_controller.dart';

enum TipCategory { engagement, nutrition, hydration, sleep, activity, general }

class DailyTip {
  final String message;
  final TipCategory category;
  const DailyTip({required this.message, required this.category});
}

/// A commonly used general daily-activity guideline. Eatsy has no
/// user-configurable step goal anywhere (Goals only covers
/// calories/macros/weight) — adding one just to back a single tip rule
/// would be real scope creep, so this fixed default is used instead.
const _stepGoal = 8000;

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

/// True only if [rows] (already sorted most-recent-date-first) has at
/// least [count] entries AND those entries are genuinely consecutive
/// calendar days ending at [today] — a gap (a day with no sync at all,
/// as opposed to a day that synced but had zero of a given metric)
/// breaks the pattern rather than being silently skipped over. Telling
/// someone "3 bad nights in a row" when one of those nights actually
/// has no data at all — rather than confirmed bad data — would be
/// misleading, not helpful.
bool _isConsecutiveFromToday(
    List<Map<String, dynamic>> rows, int count, DateTime today) {
  if (rows.length < count) return false;
  for (var i = 0; i < count; i++) {
    final expected = today.subtract(Duration(days: i));
    if (rows[i]['date'] != _dateStr(expected)) return false;
  }
  return true;
}

/// "AI Tip of the Day" (implementation guide, Section 5.3). The guide
/// describes this as a nightly cron job on a separate backend that
/// evaluates a rule table, then calls an LLM to phrase the message —
/// Eatsy has no backend service, so this evaluates the same rules live,
/// client-side, whenever the Dashboard loads or new data is logged.
///
/// Originally only three food/water rules were implemented — everything
/// else in the guide's table needed Section 2's HealthKit/Health
/// Connect integration, which didn't exist yet. That integration is now
/// live (see lib/features/health/ and health_daily_summary), which is
/// what unblocked the sleep and steps rules added below.
///
/// Still NOT implemented, and worth being explicit about why rather
/// than silently missing them: deep-sleep-percentage and sleep-timing-
/// consistency rules need per-stage sleep data (Deep/REM/Light tracked
/// separately) and actual bedtime/wake timestamps — health_service.dart
/// deliberately sums all sleep stages into one daily total rather than
/// storing them separately, so that data doesn't exist yet. Resting
/// heart rate trend isn't implemented either — only average heart rate
/// is synced (see health_service.dart's own comment on why resting HR
/// specifically was left out), and average HR is too noisy from
/// exercise to stand in for it honestly. Blood pressure alerts aren't
/// implemented since Eatsy doesn't collect BP at all — that's part of
/// the BLE device work that was explicitly deferred.
///
/// Messages are hardcoded rather than LLM-generated: the guide's own
/// example messages are already good, specific, and free — no API
/// cost or latency for a tip whose logic is this simple.
final dailyTipProvider = FutureProvider<DailyTip>((ref) async {
  // Same refresh triggers as the rest of the dashboard, so logging a
  // meal, a glass of water, or syncing health data immediately
  // re-evaluates the tip instead of waiting for the next cold load.
  ref.watch(dashboardRefreshProvider);
  ref.watch(waterRefreshProvider);
  ref.watch(healthSummaryRefreshProvider);

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

    // Last 5 days (most-recent-first) covers every health-based rule
    // below in one query: the 3-night sleep check and 2-day low-steps
    // check each only look at their own leading slice of this list,
    // and the 5-day streak check uses the whole thing.
    final healthRows = await supabase
        .from('health_daily_summary')
        .select('date, steps, sleep_minutes')
        .eq('user_id', userId)
        .order('date', ascending: false)
        .limit(5);
    final recentHealth = List<Map<String, dynamic>>.from(healthRows);
    final today = DayBoundary.startOfLocalDay(now);

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

    // Priority order: the most fundamental, actionable nudge
    // (engagement) first, then multi-day health patterns (sleep,
    // steps) — these reflect real trends worth surfacing any time of
    // day, unlike the nutrition/hydration checks below which only make
    // sense to judge once enough of today has actually passed. The
    // positive step-streak message sits just above the generic
    // fallback, as a specific, better version of "you're doing great."
    if (now.hour >= 14 && !hasLoggedFood) {
      return const DailyTip(
        message: 'No meals logged yet today. Skipping meals or logging '
            'late makes it hard to hit your calorie targets — log '
            'breakfast even if it was simple.',
        category: TipCategory.engagement,
      );
    }

    if (_isConsecutiveFromToday(recentHealth, 3, today)) {
      final last3 = recentHealth.take(3).toList();
      final allLowSleep = last3.every((r) =>
      r['sleep_minutes'] != null && (r['sleep_minutes'] as num) < 360);
      if (allLowSleep) {
        final avgHours = last3
            .map((r) => (r['sleep_minutes'] as num).toDouble())
            .reduce((a, b) => a + b) /
            3 /
            60;
        return DailyTip(
          message: "You've averaged only ${avgHours.toStringAsFixed(1)} "
              'hours of sleep this week. Poor sleep raises hunger '
              "hormones — your cravings tomorrow are not just "
              'willpower. Try a 30-min earlier bedtime tonight.',
          category: TipCategory.sleep,
        );
      }
    }

    if (_isConsecutiveFromToday(recentHealth, 2, today)) {
      final last2 = recentHealth.take(2).toList();
      final allLowSteps = last2
          .every((r) => r['steps'] != null && (r['steps'] as num) < 3000);
      if (allLowSteps) {
        return const DailyTip(
          message: "You've been very sedentary this week. Even a "
              '10-minute walk after meals improves blood sugar and BP '
              'significantly.',
          category: TipCategory.activity,
        );
      }
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

    if (_isConsecutiveFromToday(recentHealth, 5, today)) {
      final last5 = recentHealth.take(5).toList();
      final allHitGoal = last5.every(
              (r) => r['steps'] != null && (r['steps'] as num) >= _stepGoal);
      if (allHitGoal) {
        return const DailyTip(
          message: '5-day step streak! 🎯 You are in the top 20% of '
              'active users this week. Keep it up!',
          category: TipCategory.activity,
        );
      }
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