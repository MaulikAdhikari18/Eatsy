import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../../../core/config/app_config.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/dotted_leader_row.dart';
import '../../../shared/widgets/receipt_decorations.dart';
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
  bool _isLoadingSaved = true;
  Map<String, dynamic>? _mealPlan;
  String _selectedDay = 'Day 1';

  // Tracks which individual meal cards are mid-swap, keyed as
  // "$day|$mealType", so only that one card shows a spinner instead of
  // blocking the whole screen for a single-meal regeneration.
  final Set<String> _swappingKeys = {};

  @override
  void initState() {
    super.initState();
    _loadSavedPlan();
  }

  /// Loads the most recently generated plan for this user, if one
  /// exists, so the screen doesn't come up empty every time it's
  /// reopened — this is the persistence half of the feature.
  Future<void> _loadSavedPlan() async {
    setState(() => _isLoadingSaved = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final row = await supabase
          .from('diet_plans')
          .select()
          .eq('user_id', userId)
          .order('generated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row != null && mounted) {
        final plan = row['plan_json'] is String
            ? jsonDecode(row['plan_json'] as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(row['plan_json'] as Map);
        final firstDay = (plan['days'] as List).first;
        setState(() {
          _mealPlan = plan;
          _selectedDay = firstDay['day'].toString();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading saved plan: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSaved = false);
    }
  }

  /// Saves (or updates) the current plan to Supabase so it survives
  /// closing the app. Called after a full generation and after every
  /// single-meal swap so the persisted copy never goes stale.
  Future<void> _persistPlan(Map<String, dynamic> plan, DietPreferences prefs) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final firstDay = (plan['days'] as List).first as Map<String, dynamic>;

      await supabase.from('diet_plans').insert({
        'user_id': userId,
        'week_start_date':
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}',
        'cuisine': prefs.cuisines.isEmpty ? 'Mixed' : prefs.cuisines.join(', '),
        'calorie_target': firstDay['total_calories'],
        'plan_json': plan,
      });
    } catch (e) {
      debugPrint('❌ Error persisting plan: $e');
      // Non-fatal — the plan still works locally for this session even
      // if the save fails, so we don't interrupt the user with an error.
    }
  }

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
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            ...days.map((dayData) {
              final meals = dayData['meals'] as Map<String, dynamic>;
              final totalCals = dayData['total_calories'] ?? 0;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(70),
                      1: const pw.FlexColumnWidth(),
                      2: const pw.FixedColumnWidth(50),
                      3: const pw.FixedColumnWidth(40),
                      4: const pw.FixedColumnWidth(40),
                      5: const pw.FixedColumnWidth(40),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: ['Meal', 'Food', 'Cal', 'P(g)', 'C(g)', 'F(g)']
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
                      ...['breakfast', 'lunch', 'dinner', 'snack'].map((mealType) {
                        final meal = meals[mealType] as Map<String, dynamic>?;
                        if (meal == null) return pw.TableRow(children: []);
                        return pw.TableRow(
                          children: [
                            mealType[0].toUpperCase() + mealType.substring(1),
                            meal['name']?.toString() ?? '',
                            '${meal['calories']}',
                            '${meal['protein']}',
                            '${meal['carbs']}',
                            '${meal['fat']}',
                          ]
                              .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
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
            pw.Divider(),
            pw.Text(
              'Generated by Eatsy — Your AI Nutrition Companion',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
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

    final goals = await supabase
        .from('goals')
        .select()
        .eq('user_id', userId!)
        .maybeSingle();

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final logs = await supabase
        .from('food_logs')
        .select()
        .eq('user_id', userId)
        .gte('logged_at', weekAgo.toIso8601String())
        .order('logged_at', ascending: false);

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

  String _buildPrompt(Map<String, dynamic> userData, DietPreferences prefs) {
    final goals = userData['goals'];
    final logs = userData['logs'] as List;

    final foodCounts = <String, int>{};
    for (final log in logs) {
      final name = log['food_name']?.toString() ?? '';
      foodCounts[name] = (foodCounts[name] ?? 0) + 1;
    }
    final topFoods = foodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFoodNames = topFoods.take(5).map((e) => e.key).join(', ');

    final calorieTarget = goals?['daily_calories'] ?? 2000;
    final proteinG = goals?['protein_goal'] ?? 150;
    final carbsG = goals?['carbs_goal'] ?? 250;
    final fatG = goals?['fat_goal'] ?? 65;

    final cuisineList = prefs.cuisines.isEmpty ? 'Mixed' : prefs.cuisines.join(', ');
    final allergyList = prefs.allergies.isEmpty ? 'None' : prefs.allergies.join(', ');
    final conditionList =
    prefs.medicalConditions.isEmpty ? 'None' : prefs.medicalConditions.join(', ');
    final dietTypeLabel = DietPreferenceOptions.dietTypes.firstWhere(
          (d) => d['key'] == prefs.dietType,
      orElse: () => {'label': 'No Restriction'},
    )['label'];

    final referenceDishes = CuisineReference.referenceBlockFor(prefs.cuisines);

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

  /// Builds a much smaller prompt asking for exactly ONE replacement
  /// meal, targeting the same calorie/macro footprint as the meal
  /// being swapped out, so the day's total doesn't drift.
  String _buildSwapPrompt(
      Map<String, dynamic> currentMeal,
      String mealType,
      DietPreferences prefs,
      ) {
    final cuisineList = prefs.cuisines.isEmpty ? 'Mixed' : prefs.cuisines.join(', ');
    final allergyList = prefs.allergies.isEmpty ? 'None' : prefs.allergies.join(', ');
    final conditionList =
    prefs.medicalConditions.isEmpty ? 'None' : prefs.medicalConditions.join(', ');
    final dietTypeLabel = DietPreferenceOptions.dietTypes.firstWhere(
          (d) => d['key'] == prefs.dietType,
      orElse: () => {'label': 'No Restriction'},
    )['label'];
    final referenceDishes = CuisineReference.referenceBlockFor(prefs.cuisines);

    return '''
Suggest ONE alternative $mealType dish to replace "${currentMeal['name']}".

Rules:
(1) Target roughly the same nutrition: ~${currentMeal['calories']} kcal, protein ${currentMeal['protein']}g, carbs ${currentMeal['carbs']}g, fat ${currentMeal['fat']}g (±15% is fine).
(2) Cuisine: $cuisineList. Reference dishes: $referenceDishes
(3) Exclude entirely: $allergyList.
(4) Diet type: $dietTypeLabel.
(5) Medical considerations: $conditionList.
(6) Must be a genuinely different dish from "${currentMeal['name']}" — not a trivial rename.
(7) Include up to 3 short prep steps.
(8) Output strictly as JSON, no extra text, no markdown fences:
{"name":"dish name","calories":123,"protein":12,"carbs":34,"fat":5,"prep":["step 1","step 2"]}
''';
  }

  Future<void> _generateMealPlan() async {
    setState(() {
      _isGenerating = true;
      _mealPlan = null;
    });

    final prefs =
        await ref.read(dietPreferencesProvider.future) ?? const DietPreferences();

    try {
      final userData = await _getUserData();
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
            {'role': 'user', 'content': prompt}
          ],
        },
      );

      Map<String, dynamic> plan;
      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'] as String;
        final cleanJson = content.replaceAll('```json', '').replaceAll('```', '').trim();
        plan = jsonDecode(cleanJson) as Map<String, dynamic>;
      } else {
        debugPrint('❌ Groq error: ${response.data}');
        plan = _getFallbackPlan(userData);
      }

      final firstDay = (plan['days'] as List).first;
      setState(() {
        _mealPlan = plan;
        _selectedDay = firstDay['day'].toString();
      });

      await _persistPlan(plan, prefs);
    } catch (e) {
      debugPrint('❌ Error: $e');
      final userData = await _getUserData();
      final fallback = _getFallbackPlan(userData);
      setState(() {
        _mealPlan = fallback;
        _selectedDay = (fallback['days'] as List).first['day'].toString();
      });
      await _persistPlan(fallback, prefs);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// Regenerates just one meal (e.g. user doesn't like Tuesday's lunch)
  /// instead of the whole week, then persists the updated plan.
  Future<void> _swapMeal(String day, String mealType) async {
    if (_mealPlan == null) return;
    final key = '$day|$mealType';
    setState(() => _swappingKeys.add(key));

    try {
      final days = _mealPlan!['days'] as List;
      final dayData = days.firstWhere((d) => d['day'].toString() == day)
      as Map<String, dynamic>;
      final meals = dayData['meals'] as Map<String, dynamic>;
      final currentMeal = meals[mealType] as Map<String, dynamic>;

      final prefs =
          await ref.read(dietPreferencesProvider.future) ?? const DietPreferences();
      final prompt = _buildSwapPrompt(currentMeal, mealType, prefs);

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
          'max_tokens': 800,
          'messages': [
            {
              'role': 'system',
              'content':
              'You are a professional nutritionist. Always respond with valid JSON only. No markdown, no explanation, just the JSON object.',
            },
            {'role': 'user', 'content': prompt}
          ],
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Groq error: ${response.data}');
      }

      final content = response.data['choices'][0]['message']['content'] as String;
      final cleanJson = content.replaceAll('```json', '').replaceAll('```', '').trim();
      final newMeal = jsonDecode(cleanJson) as Map<String, dynamic>;

      setState(() {
        meals[mealType] = newMeal;
      });

      await _persistPlan(_mealPlan!, prefs);

      if (mounted) {
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Swapped in ${newMeal['name']}'),
            backgroundColor: colors.accent,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Swap error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not swap meal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _swappingKeys.remove(key));
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

  Future<void> _logMeal(String mealType, Map<String, dynamic> meal) async {
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
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${meal['name']} logged to $mealType!'),
            backgroundColor: colors.accent,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Meal Plan')),
      body: SafeArea(
        child: _isLoadingSaved
            ? Center(child: CircularProgressIndicator(color: colors.accent))
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_mealPlan != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: DashedButton(
                    icon: Icons.file_download_outlined,
                    label: 'PDF',
                    color: colors.textPrimary,
                    onTap: _exportToPdf,
                  ),
                ),

              if (_mealPlan != null) const SizedBox(height: 12),

              if (_mealPlan == null && !_isGenerating)
                _EmptyPlanCard(onGenerate: _generateMealPlan),

              if (_isGenerating)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      CircularProgressIndicator(color: colors.accent),
                      const SizedBox(height: 16),
                      Text(
                        'AI is creating your personalized\nmeal plan...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),

              if (_mealPlan != null) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: (_mealPlan!['days'] as List).map((dayData) {
                      final day = dayData as Map<String, dynamic>;
                      final isSelected = _selectedDay == day['day'].toString();
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDay = day['day'].toString()),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.labelCard : colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            day['day'].toString().toUpperCase(),
                            style: AppFonts.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : colors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                ...(_mealPlan!['days'] as List).map((dayData) {
                  if (dayData['day'].toString() != _selectedDay) return const SizedBox();
                  final meals = dayData['meals'] as Map<String, dynamic>;
                  final totalCals = dayData['total_calories'] ?? 0;
                  final day = dayData['day'].toString();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: colors.labelCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total for today',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$totalCals kcal',
                              style: AppFonts.mono(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      ...['breakfast', 'lunch', 'dinner', 'snack'].map((mealType) {
                        final meal = meals[mealType] as Map<String, dynamic>?;
                        if (meal == null) return const SizedBox();
                        final key = '$day|$mealType';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MealPlanCard(
                            mealType: mealType,
                            meal: meal,
                            isSwapping: _swappingKeys.contains(key),
                            onLog: () => _logMeal(mealType, meal),
                            onSwap: () => _swapMeal(day, mealType),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isGenerating ? null : _generateMealPlan,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Regenerate whole week'),
                      ),
                    ],
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlanCard extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyPlanCard({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Container(
            width: double.infinity,
            color: colors.labelCard,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                BarcodeStrip(color: colors.accent),
                const SizedBox(height: 16),
                Icon(Icons.restaurant_menu, size: 40, color: colors.accent),
                const SizedBox(height: 12),
                const Text(
                  'No meal plan yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'PERSONALIZED TO YOUR GOALS & CUISINE',
                  style: AppFonts.mono(fontSize: 10, color: colors.accent, letterSpacing: 1),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        ZigzagEdge(color: colors.labelCard),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.divider),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: ElevatedButton(
            onPressed: onGenerate,
            child: const Text('✨ Generate My Plan'),
          ),
        ),
      ],
    );
  }
}

/// One meal card for the selected day. Adds a swap (refresh) icon next
/// to "+ Log" — tapping it regenerates just this meal via AI while
/// keeping the rest of the day's plan untouched, and shows a small
/// inline spinner on this card only while the swap is in flight.
class _MealPlanCard extends StatelessWidget {
  final String mealType;
  final Map<String, dynamic> meal;
  final bool isSwapping;
  final VoidCallback onLog;
  final VoidCallback onSwap;

  const _MealPlanCard({
    required this.mealType,
    required this.meal,
    required this.isSwapping,
    required this.onLog,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = colors.mealTypeColor(mealType);
    final prep = meal['prep'];
    final prepSteps = prep is List ? prep.cast<String>() : const <String>[];

    return Opacity(
      opacity: isSwapping ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(color: colors.cardShadow, blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mealType.toUpperCase(),
                  style: AppFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
                GestureDetector(
                  onTap: isSwapping ? null : onSwap,
                  child: isSwapping
                      ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                      : Icon(Icons.swap_horiz, size: 16, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DottedLeaderRow(
              label: meal['name']?.toString() ?? '',
              value: '${meal['calories']}',
              labelFontSize: 14,
              labelFontWeight: FontWeight.w600,
              valueFontSize: 14,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniMacro(label: 'P', value: '${meal['protein']}g', color: colors.protein),
                const SizedBox(width: 12),
                _MiniMacro(label: 'C', value: '${meal['carbs']}g', color: colors.carbs),
                const SizedBox(width: 12),
                _MiniMacro(label: 'F', value: '${meal['fat']}g', color: colors.fat),
                const Spacer(),
                GestureDetector(
                  onTap: isSwapping ? null : onLog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ Log',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (prepSteps.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: colors.divider),
              const SizedBox(height: 8),
              ...prepSteps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${e.key + 1}. ${e.value}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniMacro extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniMacro({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: AppFonts.mono(fontSize: 11, color: color.withOpacity(0.7)),
          ),
          TextSpan(
            text: value,
            style: AppFonts.mono(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}