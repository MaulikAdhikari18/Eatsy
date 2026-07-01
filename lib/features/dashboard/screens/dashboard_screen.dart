import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../log/screens/food_log_screen.dart';
import '../../scan/screens/scan_screen.dart';
import '../../barcode/screens/barcode_screen.dart';
import '../../goals/screens/goals_screen.dart';
import '../controllers/dashboard_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../auth/controllers/auth_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _HomeTab(),
      const FoodLogScreen(),
      const ScanScreen(),
      const GoalsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanScreen()),
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Goals',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  void _showProfileMenu(BuildContext context, WidgetRef ref) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF4CAF50),
                  radius: 24,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.grey),
              title: const Text('Goals & Targets'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF4CAF50),
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good ${_greeting()}! 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          today,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _showProfileMenu(context, ref),
                      child: const CircleAvatar(
                        backgroundColor: Color(0xFF4CAF50),
                        radius: 22,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Calorie Ring Card
                summaryAsync.when(
                  data: (summary) => _CalorieCard(summary: summary),
                  loading: () => const _CalorieCardSkeleton(),
                  error: (e, __) {
                    print('Dashboard error: $e');
                    return _CalorieCard(
                      summary: DashboardSummary(
                        consumed: 0,
                        goal: 2000,
                        protein: 0,
                        carbs: 0,
                        fat: 0,
                        proteinGoal: 150,
                        carbsGoal: 250,
                        fatGoal: 65,
                        todaysMeals: const [],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Macros Row
                summaryAsync.when(
                  data: (summary) => _MacrosRow(summary: summary),
                  loading: () => const _MacrosSkeleton(),
                  error: (_, __) => const SizedBox(),
                ),

                const SizedBox(height: 24),

                // Quick Add
                const Text(
                  'Quick Add',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _QuickAddButton(
                      icon: Icons.camera_alt,
                      label: 'Scan Food',
                      color: const Color(0xFF4CAF50),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScanScreen()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _QuickAddButton(
                      icon: Icons.search,
                      label: 'Search Food',
                      color: const Color(0xFF2196F3),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FoodLogScreen()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _QuickAddButton(
                      icon: Icons.qr_code_scanner,
                      label: 'Barcode',
                      color: const Color(0xFFFF7043),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BarcodeScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Today's Meals
                const Text(
                  "Today's Meals",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                summaryAsync.when(
                  data: (summary) {
                    final meals = summary.todaysMeals;
                    if (meals.isEmpty) return _EmptyMeals();

                    final Map<String, List<Map<String, dynamic>>> grouped = {
                      'breakfast': [],
                      'lunch': [],
                      'dinner': [],
                      'snack': [],
                    };
                    for (final meal in meals) {
                      final type = meal['meal_type']?.toString() ?? 'snack';
                      grouped[type]?.add(meal);
                    }

                    return Column(
                      children: grouped.entries
                          .where((e) => e.value.isNotEmpty)
                          .map((e) => _MealSection(
                        mealType: e.key,
                        meals: e.value,
                      ))
                          .toList(),
                    );
                  },
                  loading: () => const _MealsSkeleton(),
                  error: (_, __) => _EmptyMeals(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Calorie Ring Card
class _CalorieCard extends StatelessWidget {
  final DashboardSummary summary;
  const _CalorieCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final progress = summary.goal > 0
        ? (summary.consumed / summary.goal).clamp(0.0, 1.0)
        : 0.0;
    final remaining =
    (summary.goal - summary.consumed).clamp(0, summary.goal);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 0,
                    centerSpaceRadius: 45,
                    sections: [
                      PieChartSectionData(
                        value: progress > 0 ? progress : 0.001,
                        color: const Color(0xFF4CAF50),
                        radius: 12,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: progress < 1 ? 1 - progress : 0.001,
                        color: const Color(0xFFF0F0F0),
                        radius: 12,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.consumed.toInt()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'kcal',
                      style:
                      TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatRow(
                  label: 'Goal',
                  value: '${summary.goal} kcal',
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                _StatRow(
                  label: 'Consumed',
                  value: '${summary.consumed.toInt()} kcal',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 8),
                _StatRow(
                  label: 'Remaining',
                  value: '$remaining kcal',
                  color: const Color(0xFF2196F3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }
}

// Macros Row
class _MacrosRow extends StatelessWidget {
  final DashboardSummary summary;
  const _MacrosRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MacroCard(
            label: 'Protein',
            consumed: summary.protein,
            goal: summary.proteinGoal,
            color: const Color(0xFFE53935),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MacroCard(
            label: 'Carbs',
            consumed: summary.carbs,
            goal: summary.carbsGoal,
            color: const Color(0xFFFB8C00),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MacroCard(
            label: 'Fat',
            consumed: summary.fat,
            goal: summary.fatGoal,
            color: const Color(0xFF8E24AA),
          ),
        ),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double consumed;
  final double goal;
  final Color color;
  const _MacroCard({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
    goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${consumed.toInt()}g',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of ${goal.toInt()}g',
            style:
            const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAddButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No meals logged yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap Scan or Search to add your first meal',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CalorieCardSkeleton extends StatelessWidget {
  const _CalorieCardSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _MacrosSkeleton extends StatelessWidget {
  const _MacrosSkeleton();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
            (_) => Expanded(
          child: Container(
            height: 90,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _MealsSkeleton extends StatelessWidget {
  const _MealsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _MealSection extends StatefulWidget {
  final String mealType;
  final List<Map<String, dynamic>> meals;

  const _MealSection({
    required this.mealType,
    required this.meals,
  });

  @override
  State<_MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<_MealSection> {
  bool _isExpanded = true;

  IconData get _mealIcon {
    switch (widget.mealType) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.light_mode_outlined;
      case 'dinner':
        return Icons.nights_stay_outlined;
      case 'snack':
        return Icons.cookie_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  Color get _mealColor {
    switch (widget.mealType) {
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

  double get _totalCalories => widget.meals
      .fold(0, (sum, m) => sum + ((m['calories'] ?? 0) as num).toDouble());

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
          // Meal type header
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _mealColor.withOpacity(0.05),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(16),
                  bottom: _isExpanded
                      ? Radius.zero
                      : const Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _mealColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_mealIcon, color: _mealColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.mealType[0].toUpperCase() +
                              widget.mealType.substring(1),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _mealColor,
                          ),
                        ),
                        Text(
                          '${widget.meals.length} item${widget.meals.length > 1 ? 's' : ''} · ${_totalCalories.toInt()} kcal',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Food items
          if (_isExpanded)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.meals.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final log = widget.meals[index];
                final calories = ((log['calories'] ?? 0) as num).toInt();
                final protein = ((log['protein'] ?? 0) as num).toInt();
                final carbs = ((log['carbs'] ?? 0) as num).toInt();
                final fat = ((log['fat'] ?? 0) as num).toInt();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _mealColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.restaurant,
                          color: _mealColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['food_name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'P: ${protein}g · C: ${carbs}g · F: ${fat}g',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$calories kcal',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _mealColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}