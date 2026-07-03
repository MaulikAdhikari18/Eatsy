import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../../../core/services/fatsecret_service.dart';
import 'dart:convert';
import '../../../core/config/app_config.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  bool _isGenerating = false;
  Map<String, dynamic>? _mealPlan;
  String _selectedDay = 'Today';

  final List<String> _days = [
    'Today',
    'Tomorrow',
    'Day 3',
    'Day 4',
    'Day 5',
    'Day 6',
    'Day 7',
  ];

  Future<Map<String, dynamic>> _getUserData() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    // Get goals
    final goals = await supabase
        .from('goals')
        .select()
        .eq('user_id', userId!)
        .maybeSingle();

    // Get last 7 days food logs
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final logs = await supabase
        .from('food_logs')
        .select()
        .eq('user_id', userId)
        .gte('logged_at', weekAgo.toIso8601String())
        .order('logged_at', ascending: false);

    // Get latest weight
    final weightLogs = await supabase
        .from('weight_logs')
        .select()
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .limit(1);

    return {
      'goals': goals,
      'logs': logs,
      'weight': weightLogs.isNotEmpty ? weightLogs[0]['weight'] : null,
    };
  }

  String _buildPrompt(Map<String, dynamic> userData) {
    final goals = userData['goals'];
    final logs = userData['logs'] as List;
    final weight = userData['weight'];

    final foodCounts = <String, int>{};
    for (final log in logs) {
      final name = log['food_name']?.toString() ?? '';
      foodCounts[name] = (foodCounts[name] ?? 0) + 1;
    }
    final topFoods = foodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFoodNames =
    topFoods.take(5).map((e) => e.key).join(', ');

    final dailyCalories = goals?['daily_calories'] ?? 2000;
    final proteinGoal = goals?['protein_goal'] ?? 150;
    final carbsGoal = goals?['carbs_goal'] ?? 250;
    final fatGoal = goals?['fat_goal'] ?? 65;
    final weightGoal = goals?['weight_goal'] ?? 'not set';

    return '''
Create a 7-day personalized meal plan for this user:
- Current weight: ${weight ?? 'unknown'} kg
- Target weight: $weightGoal kg  
- Daily calorie goal: $dailyCalories kcal
- Protein goal: ${proteinGoal}g, Carbs: ${carbsGoal}g, Fat: ${fatGoal}g
- Foods they like: $topFoodNames

Return ONLY this JSON, no other text:
{
  "days": [
    {
      "day": "Day 1",
      "total_calories": $dailyCalories,
      "meals": {
        "breakfast": {"name": "meal name", "calories": 400, "protein": 15, "carbs": 60, "fat": 8},
        "lunch": {"name": "meal name", "calories": 600, "protein": 35, "carbs": 65, "fat": 15},
        "dinner": {"name": "meal name", "calories": 550, "protein": 30, "carbs": 60, "fat": 12},
        "snack": {"name": "meal name", "calories": 200, "protein": 8, "carbs": 25, "fat": 6}
      }
    },
    ... repeat for all 7 days
  ]
}
''';
  }

  Future<void> _generateMealPlan() async {
    setState(() {
      _isGenerating = true;
      _mealPlan = null;
    });

    try {
      final userData = await _getUserData();
      final prompt = _buildPrompt(userData);

      final dio = Dio();
      final response = await dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.groqApiKey}',
          },
          validateStatus: (status) => true,
        ),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'max_tokens': 2000,
          'messages': [
            {
              'role': 'system',
              'content':
              'You are a professional nutritionist. Always respond with valid JSON only. No markdown, no explanation, just the JSON object.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        },
      );

      print('📦 Groq status: ${response.statusCode}');
      print('📦 Groq response: ${response.data}');

      if (response.statusCode == 200) {
        final content =
        response.data['choices'][0]['message']['content'] as String;
        print('🤖 AI content: $content');

        final cleanJson = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final parsed =
        jsonDecode(cleanJson) as Map<String, dynamic>;
        setState(() => _mealPlan = parsed);
      } else {
        print('❌ Groq error: ${response.data}');
        final userData2 = await _getUserData();
        setState(() => _mealPlan = _getFallbackPlan(userData2));
      }
    } catch (e) {
      print('❌ Error: $e');
      final userData = await _getUserData();
      setState(() => _mealPlan = _getFallbackPlan(userData));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Map<String, dynamic> _parseJson(String jsonStr) {
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('❌ JSON parse error: $e');
      return _getFallbackPlan({});
    }
  }

  Map<String, dynamic> _getFallbackPlan(Map<String, dynamic> userData) {
    final goals = userData['goals'];
    final calories = goals?['daily_calories'] ?? 2000;

    return {
      'days': List.generate(7, (i) {
        return {
          'day': i == 0 ? 'Today' : 'Day ${i + 1}',
          'total_calories': calories,
          'meals': {
            'breakfast': {
              'name': i % 3 == 0
                  ? 'Oats with banana & milk'
                  : i % 3 == 1
                  ? 'Poha with peanuts'
                  : 'Idli with sambar',
              'calories': (calories * 0.25).round(),
              'protein': 12,
              'carbs': 45,
              'fat': 6,
            },
            'lunch': {
              'name': i % 3 == 0
                  ? 'Dal rice with sabzi'
                  : i % 3 == 1
                  ? 'Chicken curry with roti'
                  : 'Rajma chawal',
              'calories': (calories * 0.35).round(),
              'protein': 25,
              'carbs': 55,
              'fat': 10,
            },
            'dinner': {
              'name': i % 3 == 0
                  ? 'Paneer sabzi with roti'
                  : i % 3 == 1
                  ? 'Grilled chicken with salad'
                  : 'Dal tadka with brown rice',
              'calories': (calories * 0.30).round(),
              'protein': 22,
              'carbs': 40,
              'fat': 8,
            },
            'snack': {
              'name': i % 3 == 0
                  ? 'Mixed nuts & fruit'
                  : i % 3 == 1
                  ? 'Greek yogurt'
                  : 'Protein shake',
              'calories': (calories * 0.10).round(),
              'protein': 8,
              'carbs': 15,
              'fat': 5,
            },
          },
        };
      }),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Meal Plan'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🥗 AI Meal Planner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Get a personalized 7-day meal plan based on your goals and food preferences.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isGenerating ? null : _generateMealPlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isGenerating
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4CAF50),
                      ),
                    )
                        : const Text(
                      '✨ Generate My Plan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_isGenerating) ...[
              const Center(
                child: Column(
                  children: [
                    SizedBox(height: 40),
                    CircularProgressIndicator(color: Color(0xFF4CAF50)),
                    SizedBox(height: 16),
                    Text(
                      'AI is creating your personalized\nmeal plan...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_mealPlan != null) ...[
              // Day selector
              const Text(
                'Your 7-Day Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: (_mealPlan!['days'] as List)
                      .asMap()
                      .entries
                      .map((entry) {
                    final day = entry.value as Map<String, dynamic>;
                    final isSelected =
                        _selectedDay == day['day'].toString();
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedDay = day['day'].toString()),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4CAF50)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Text(
                          day['day'].toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Selected day meals
              ...(_mealPlan!['days'] as List).map((dayData) {
                if (dayData['day'].toString() != _selectedDay) {
                  return const SizedBox();
                }
                final meals =
                dayData['meals'] as Map<String, dynamic>;
                final totalCals = dayData['total_calories'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total calories
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                          const Color(0xFF4CAF50).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: Color(0xFF4CAF50)),
                          const SizedBox(width: 8),
                          Text(
                            'Total: $totalCals kcal',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Meal cards
                    ...['breakfast', 'lunch', 'dinner', 'snack']
                        .map((mealType) {
                      final meal =
                      meals[mealType] as Map<String, dynamic>?;
                      if (meal == null) return const SizedBox();
                      return _MealPlanCard(
                        mealType: mealType,
                        meal: meal,
                        onLog: () => _logMeal(mealType, meal),
                      );
                    }),
                  ],
                );
              }),
            ],

            if (_mealPlan == null && !_isGenerating) ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No meal plan yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Generate My Plan" to get started',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _logMeal(
      String mealType, Map<String, dynamic> meal) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('food_logs').insert({
        'user_id': userId,
        'food_name': meal['name'],
        'calories': (meal['calories'] as num).toDouble(),
        'protein': (meal['protein'] as num).toDouble(),
        'carbs': (meal['carbs'] as num).toDouble(),
        'fat': (meal['fat'] as num).toDouble(),
        'meal_type': mealType,
        'logged_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${meal['name']} logged to $mealType!'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging meal: $e')),
        );
      }
    }
  }
}

class _MealPlanCard extends StatelessWidget {
  final String mealType;
  final Map<String, dynamic> meal;
  final VoidCallback onLog;

  const _MealPlanCard({
    required this.mealType,
    required this.meal,
    required this.onLog,
  });

  IconData get _icon {
    switch (mealType) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.light_mode_outlined;
      case 'dinner':
        return Icons.nights_stay_outlined;
      case 'snack':
        return Icons.cookie_outlined;
      default:
        return Icons.restaurant;
    }
  }

  Color get _color {
    switch (mealType) {
      case 'breakfast':
        return const Color(0xFFFB8C00);
      case 'lunch':
        return const Color(0xFF4CAF50);
      case 'dinner':
        return const Color(0xFF3F51B5);
      case 'snack':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(_icon, color: _color, size: 18),
                const SizedBox(width: 8),
                Text(
                  mealType[0].toUpperCase() + mealType.substring(1),
                  style: TextStyle(
                    color: _color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal['name']?.toString() ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _NutriBadge(
                      label: 'Cal',
                      value: '${meal['calories']}',
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 8),
                    _NutriBadge(
                      label: 'P',
                      value: '${meal['protein']}g',
                      color: const Color(0xFFE53935),
                    ),
                    const SizedBox(width: 8),
                    _NutriBadge(
                      label: 'C',
                      value: '${meal['carbs']}g',
                      color: const Color(0xFFFB8C00),
                    ),
                    const SizedBox(width: 8),
                    _NutriBadge(
                      label: 'F',
                      value: '${meal['fat']}g',
                      color: const Color(0xFF8E24AA),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onLog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+ Log',
                          style: TextStyle(
                            color: _color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutriBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NutriBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}