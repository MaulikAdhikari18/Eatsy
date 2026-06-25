import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardSummary {
  final double consumed;
  final int goal;
  final double protein;
  final double carbs;
  final double fat;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;

  const DashboardSummary({
    required this.consumed,
    required this.goal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
  });
}

final dashboardSummaryProvider =
FutureProvider<DashboardSummary>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    return const DashboardSummary(
      consumed: 0,
      goal: 2000,
      protein: 0,
      carbs: 0,
      fat: 0,
      proteinGoal: 150,
      carbsGoal: 250,
      fatGoal: 65,
    );
  }

  // Get today's date range
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  // Fetch today's food logs
  final logs = await supabase
      .from('food_logs')
      .select()
      .eq('user_id', userId)
      .gte('logged_at', startOfDay.toIso8601String())
      .lt('logged_at', endOfDay.toIso8601String());

  double totalCalories = 0;
  double totalProtein = 0;
  double totalCarbs = 0;
  double totalFat = 0;

  for (final log in logs) {
    totalCalories += (log['calories'] ?? 0).toDouble();
    totalProtein += (log['protein'] ?? 0).toDouble();
    totalCarbs += (log['carbs'] ?? 0).toDouble();
    totalFat += (log['fat'] ?? 0).toDouble();
  }

  // Fetch user goals
  final goalsData = await supabase
      .from('goals')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  return DashboardSummary(
    consumed: totalCalories,
    goal: goalsData?['daily_calories'] ?? 2000,
    protein: totalProtein,
    carbs: totalCarbs,
    fat: totalFat,
    proteinGoal: (goalsData?['protein_goal'] ?? 150).toDouble(),
    carbsGoal: (goalsData?['carbs_goal'] ?? 250).toDouble(),
    fatGoal: (goalsData?['fat_goal'] ?? 65).toDouble(),
  );
});