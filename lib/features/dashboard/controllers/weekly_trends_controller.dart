import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// One day's totals within the current week. `mealCount == 0` means
/// nothing was logged that day — including future days later this
/// week, which naturally have no food_logs yet.
class DayTrend {
  final String label;
  final DateTime date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int mealCount;

  const DayTrend({
    required this.label,
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealCount,
  });
}

class WeeklyTrendsSummary {
  /// Always exactly 7 entries, Monday first, Sunday last — the week is
  /// always Mon–Sun regardless of what day it is "today", so the chart
  /// doesn't shift its window day to day.
  final List<DayTrend> days;
  final double avgCaloriesPerDay;
  final int goalCalories;

  /// Null when there are fewer than 2 weight_logs entries this week —
  /// not enough points to show a meaningful change yet. The screen
  /// should show a "not enough data" state rather than "0.0 kg".
  final double? weightChangeKg;
  final double? startWeightKg;
  final double? endWeightKg;

  const WeeklyTrendsSummary({
    required this.days,
    required this.avgCaloriesPerDay,
    required this.goalCalories,
    this.weightChangeKg,
    this.startWeightKg,
    this.endWeightKg,
  });
}

// Separate from dashboardRefreshProvider / waterRefreshProvider on
// purpose, same reasoning as the water card: logging a meal shouldn't
// force a refetch of the whole week's trend data on every tap.
final weeklyTrendsRefreshProvider = StateProvider<int>((ref) => 0);

DateTime _mondayOfThisWeek() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - 1));
}

WeeklyTrendsSummary _emptySummary({int goalCalories = 2000}) {
  final monday = _mondayOfThisWeek();
  final days = List.generate(7, (i) {
    return DayTrend(
      label: _dayLabels[i],
      date: monday.add(Duration(days: i)),
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      mealCount: 0,
    );
  });
  return WeeklyTrendsSummary(
      days: days, avgCaloriesPerDay: 0, goalCalories: goalCalories);
}

final weeklyTrendsProvider =
FutureProvider<WeeklyTrendsSummary>((ref) async {
  ref.watch(weeklyTrendsRefreshProvider);

  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return _emptySummary();

  try {
    final monday = _mondayOfThisWeek();
    final nextMonday = monday.add(const Duration(days: 7));

    final logsResponse = await supabase
        .from('food_logs')
        .select('calories, protein, carbs, fat, logged_at')
        .eq('user_id', userId)
        .gte('logged_at', monday.toIso8601String())
        .lt('logged_at', nextMonday.toIso8601String());

    // Bucket by weekday (Dart: 1=Mon .. 7=Sun) into 7 slots, 0=Mon.
    final buckets = List.generate(7, (_) => <Map<String, dynamic>>[]);
    for (final row in (logsResponse as List)) {
      final loggedAt = DateTime.parse(row['logged_at'] as String);
      final idx = loggedAt.weekday - 1;
      if (idx >= 0 && idx < 7) {
        buckets[idx].add(Map<String, dynamic>.from(row));
      }
    }

    final days = List.generate(7, (i) {
      final rows = buckets[i];
      double cal = 0, protein = 0, carbs = 0, fat = 0;
      for (final r in rows) {
        cal += ((r['calories'] ?? 0) as num).toDouble();
        protein += ((r['protein'] ?? 0) as num).toDouble();
        carbs += ((r['carbs'] ?? 0) as num).toDouble();
        fat += ((r['fat'] ?? 0) as num).toDouble();
      }
      return DayTrend(
        label: _dayLabels[i],
        date: monday.add(Duration(days: i)),
        calories: cal,
        protein: protein,
        carbs: carbs,
        fat: fat,
        mealCount: rows.length,
      );
    });

    // Average only counts days that actually have logs — a Wednesday
    // with nothing logged shouldn't drag the average down as if it
    // were a real zero-calorie day.
    final loggedDays = days.where((d) => d.mealCount > 0).toList();
    final avgCalories = loggedDays.isEmpty
        ? 0.0
        : loggedDays.map((d) => d.calories).reduce((a, b) => a + b) /
        loggedDays.length;

    final goalsRow = await supabase
        .from('goals')
        .select('daily_calories')
        .eq('user_id', userId)
        .maybeSingle();
    final goalCalories = ((goalsRow?['daily_calories'] ?? 2000) as num).toInt();

    final weightLogs = await supabase
        .from('weight_logs')
        .select('weight, logged_at')
        .eq('user_id', userId)
        .gte('logged_at', monday.toIso8601String())
        .lt('logged_at', nextMonday.toIso8601String())
        .order('logged_at', ascending: true);

    double? startWeight;
    double? endWeight;
    final weightList = weightLogs as List;
    if (weightList.length >= 2) {
      startWeight = (weightList.first['weight'] as num).toDouble();
      endWeight = (weightList.last['weight'] as num).toDouble();
    }

    return WeeklyTrendsSummary(
      days: days,
      avgCaloriesPerDay: avgCalories,
      goalCalories: goalCalories,
      weightChangeKg:
      (startWeight != null && endWeight != null) ? endWeight - startWeight : null,
      startWeightKg: startWeight,
      endWeightKg: endWeight,
    );
  } catch (e) {
    return _emptySummary();
  }
});