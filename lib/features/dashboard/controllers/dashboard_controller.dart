import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/day_boundary.dart';

class DashboardSummary {
  final double consumed;
  final int goal;
  final double protein;
  final double carbs;
  final double fat;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final List<Map<String, dynamic>> _todaysMeals;

  List<Map<String, dynamic>> get todaysMeals => _todaysMeals;

  DashboardSummary({
    required this.consumed,
    required this.goal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    List<Map<String, dynamic>>? todaysMeals,
  }) : _todaysMeals = todaysMeals ?? [];
}

final dashboardRefreshProvider = StateProvider<int>((ref) => 0);

final dashboardSummaryProvider =
FutureProvider<DashboardSummary>((ref) async {
  ref.watch(dashboardRefreshProvider);

  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    return DashboardSummary(
      consumed: 0,
      goal: 2000,
      protein: 0,
      carbs: 0,
      fat: 0,
      proteinGoal: 150,
      carbsGoal: 250,
      fatGoal: 65,
      todaysMeals: [],
    );
  }

  try {
    final startOfDay = DayBoundary.startOfLocalDay();
    final endOfDay = DayBoundary.endOfLocalDay();

    final logsResponse = await supabase
        .from('food_logs')
        .select()
        .eq('user_id', userId)
        .gte('logged_at', startOfDay.toIso8601String())
        .lt('logged_at', endOfDay.toIso8601String())
        .order('logged_at', ascending: false);

    final List<Map<String, dynamic>> logs = [];
    if (logsResponse != null) {
      for (final item in logsResponse) {
        logs.add(Map<String, dynamic>.from(item));
      }
    }

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final log in logs) {
      totalCalories += ((log['calories'] ?? 0) as num).toDouble();
      totalProtein += ((log['protein'] ?? 0) as num).toDouble();
      totalCarbs += ((log['carbs'] ?? 0) as num).toDouble();
      totalFat += ((log['fat'] ?? 0) as num).toDouble();
    }

    final goalsResponse = await supabase
        .from('goals')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return DashboardSummary(
      consumed: totalCalories,
      goal: ((goalsResponse?['daily_calories'] ?? 2000) as num).toInt(),
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      proteinGoal:
      ((goalsResponse?['protein_goal'] ?? 150) as num).toDouble(),
      carbsGoal:
      ((goalsResponse?['carbs_goal'] ?? 250) as num).toDouble(),
      fatGoal: ((goalsResponse?['fat_goal'] ?? 65) as num).toDouble(),
      todaysMeals: logs,
    );
  } catch (e) {
    print('Dashboard error: $e');
    return DashboardSummary(
      consumed: 0,
      goal: 2000,
      protein: 0,
      carbs: 0,
      fat: 0,
      proteinGoal: 150,
      carbsGoal: 250,
      fatGoal: 65,
      todaysMeals: [],
    );
  }
});