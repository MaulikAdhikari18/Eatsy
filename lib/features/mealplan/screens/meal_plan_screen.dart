import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../../../core/services/fatsecret_service.dart';
import 'dart:convert';
import '../../../core/config/app_config.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../preferences/controllers/diet_preferences_controller.dart';
import '../../preferences/models/diet_preferences.dart';
import '../cuisine_reference.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  bool _isGenerating = false;
  Map<String, dynamic>? _mealPlan;
  String _selectedDay = 'Day 1';

  // Note: PDF export always renders on a white page — that's standard for
  // printable documents and intentionally does NOT follow the app's theme.
  Future<void> _exportToPdf() async {
    if (_mealPlan == null) return;

    final pdf = pw.Document();
    final days = _mealPlan!['days'] as List;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🥗 Eatsy — 7-Day Meal Plan',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Days
            ...days.map((dayData) {
              final meals = dayData['meals'] as Map<String, dynamic>;
              final totalCals = dayData['total_calories'] ?? 0;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Day header
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          dayData['day'].toString(),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.green900,
                          ),
                        ),
                        pw.Text(
                          'Total: $totalCals kcal',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Meals table
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey300,
                      width: 0.5,
                    ),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(70),
                      1: const pw.FlexColumnWidth(),
                      2: const pw.FixedColumnWidth(50),
                      3: const pw.FixedColumnWidth(40),
                      4: const pw.FixedColumnWidth(40),
                      5: const pw.FixedColumnWidth(40),
                    },
                    children: [
                      // Table header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200),
                        children: [
                          'Meal', 'Food', 'Cal', 'P(g)', 'C(g)', 'F(g)'
                        ]
                            .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                              color: PdfColors.black,
                            ),
                          ),
                        ))
                            .toList(),
                      ),
                      // Meal rows
                      ...['breakfast', 'lunch', 'dinner', 'snack']
                          .map((mealType) {
                        final meal = meals[mealType]
                        as Map<String, dynamic>?;
                        if (meal == null) return pw.TableRow(children: []);
                        return pw.TableRow(
                          children: [
                            mealType[0].toUpperCase() +
                                mealType.substring(1),
                            meal['name']?.toString() ?? '',
                            '${meal['calories']}',
                            '${meal['protein']}',
                            '${meal['carbs']}',
                            '${meal['fat']}',
                          ]
                              .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              cell,
                              style:
                              const pw.TextStyle(fontSize: 9),
                            ),
                          ))
                              .toList(),
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                ],
              );
            }),

            // Footer
            pw.Divider(),
            pw.Text(
              'Generated by Eatsy — Your AI Nutrition Companion',
              style: const pw.TextStyle(
                color: PdfColors.grey,
                fontSize: 10,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Eatsy_7Day_Meal_Plan.pdf',
    );
  }

  Future<Map<String, dynamic>> _getUserData() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    // Get goals (now includes age/gender/height/activity_level too,
    // but we only need the calorie/macro targets here — those are
    // computed by the BMR/TDEE calculator on the Goals screen).
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

  /// Builds the AI prompt following the exact template in Section 4.3
  /// of the implementation guide, now parameterized with real diet
  /// preferences (cuisine, allergies, diet type, medical conditions)
  /// instead of a generic one-size-fits-all prompt.
  String _buildPrompt(
      Map<String, dynamic> userData, DietPreferences prefs) {
    final goals = userData['goals'];
    final logs = userData['logs'] as List;

    final foodCounts = <String, int>{};
    for (final log in logs) {
      final name = log['food_name']?.toString() ?? '';
      foodCounts[name] = (foodCounts[name] ?? 0) + 1;
    }
    final topFoods = foodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFoodNames =
    topFoods.take(5).map((e) => e.key).join(', ');

    final calorieTarget = goals?['daily_calories'] ?? 2000;
    final proteinG = goals?['protein_goal'] ?? 150;
    final carbsG = goals?['carbs_goal'] ?? 250;
    final fatG = goals?['fat_goal'] ?? 65;

    final cuisineList =
    prefs.cuisines.isEmpty ? 'Mixed' : prefs.cuisines.join(', ');
    final allergyList =
    prefs.allergies.isEmpty ? 'None' : prefs.allergies.join(', ');
    final conditionList = prefs.medicalConditions.isEmpty
        ? 'None'
        : prefs.medicalConditions.join(', ');
    final dietTypeLabel = DietPreferenceOptions.dietTypes.firstWhere(
          (d) => d['key'] == prefs.dietType,
      orElse: () => {'label': 'No Restriction'},
    )['label'];

    final referenceDishes =
    CuisineReference.referenceBlockFor(prefs.cuisines);

    return '''
You are a certified nutritionist and dietitian. Generate a 7-day meal plan with BREAKFAST, LUNCH, DINNER, and SNACK for each day.

Rules:
(1) Calorie target: $calorieTarget kcal/day ± 50kcal.
(2) Macros: Protein ${proteinG}g / Carbs ${carbsG}g / Fat ${fatG}g.
(3) Cuisine: $cuisineList — use authentic dishes from these cuisines. Reference dishes to draw from (stay close to real, recognizable dishes rather than inventing unfamiliar ones):
$referenceDishes
(4) Exclude entirely, in every meal: $allergyList.
(5) Diet type: $dietTypeLabel — every meal must comply.
(6) Medical considerations: $conditionList — e.g. diabetic = low glycemic index focus, hypertension = low sodium. Annotate affected meals with a short note if relevant.
(7) User's recently logged foods (avoid excessive repetition, but familiarity is fine): $topFoodNames
(8) Each meal must include: dish name, portion size, calories, protein g, carbs g, fat g.
(9) Include simple prep instructions (max 3 steps) as a "prep" field — array of up to 3 short strings.
(10) Output strictly as JSON, no extra text, no markdown fences.

JSON format (ALL 7 days, ALL 4 meals per day):
{"days":[{"day":"Day 1","total_calories":$calorieTarget,"meals":{"breakfast":{"name":"meal","calories":350,"protein":15,"carbs":50,"fat":8,"prep":["step 1","step 2"]},"lunch":{"name":"meal","calories":550,"protein":35,"carbs":60,"fat":14,"prep":["step 1","step 2"]},"dinner":{"name":"meal","calories":500,"protein":30,"carbs":55,"fat":12,"prep":["step 1","step 2"]},"snack":{"name":"meal","calories":200,"protein":10,"carbs":25,"fat":6,"prep":["step 1"]}}}]}

Generate all 7 days following this exact structure. Replace all placeholder values with real personalized meals. Keep each day's total close to $calorieTarget kcal.
''';
  }

  Future<void> _generateMealPlan() async {
    setState(() {
      _isGenerating = true;
      _mealPlan = null;
    });

    try {
      final userData = await _getUserData();
      final prefs =
          await ref.read(dietPreferencesProvider.future) ??
              const DietPreferences();
      final prompt = _buildPrompt(userData, prefs);

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
          'max_tokens': 4000,
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

      if (response.statusCode == 200) {
        final content =
        response.data['choices'][0]['message']['content'] as String;

        final cleanJson = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final parsed =
        jsonDecode(cleanJson) as Map<String, dynamic>;
        final firstDay = (parsed['days'] as List).first;
        setState(() {
          _mealPlan = parsed;
          _selectedDay = firstDay['day'].toString();
        });
      } else {
        debugPrint('❌ Groq error: ${response.data}');
        final fallback = _getFallbackPlan(userData);
        setState(() {
          _mealPlan = fallback;
          _selectedDay = (fallback['days'] as List).first['day'].toString();
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      final userData = await _getUserData();
      final fallback = _getFallbackPlan(userData);
      setState(() {
        _mealPlan = fallback;
        _selectedDay = (fallback['days'] as List).first['day'].toString();
      });
    } finally {
      if (mounted) setState(() => _isGenerating = false);
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
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Meal Plan',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card — keeps its green gradient in both themes; it's a
            // branded hero card, not a content surface, so it stays as-is.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
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
                    'Get a personalized 7-day meal plan based on your goals, cuisine, and dietary needs.',
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
                      foregroundColor: AppTheme.primary,
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
                        color: AppTheme.primary,
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
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(color: AppTheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'AI is creating your personalized\nmeal plan...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_mealPlan != null) ...[
              // Day selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your 7-Day Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _exportToPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text(
                        'Save PDF',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
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
                              ? AppTheme.primary
                              : colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : colors.divider,
                          ),
                        ),
                        child: Text(
                          day['day'].toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : colors.textSecondary,
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
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Total: $totalCals kcal',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary,
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
                      color: colors.divider,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No meal plan yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Generate My Plan" to get started',
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
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
            backgroundColor: AppTheme.primary,
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
        return AppTheme.primary;
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
    final colors = context.appColors;
    final prep = meal['prep'];
    final prepSteps = prep is List ? prep.cast<String>() : const <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
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
              color: _color.withOpacity(0.08),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _NutriBadge(
                      label: 'Cal',
                      value: '${meal['calories']}',
                      color: AppTheme.primary,
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
                if (prepSteps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: colors.divider),
                  const SizedBox(height: 10),
                  ...prepSteps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  )),
                ],
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