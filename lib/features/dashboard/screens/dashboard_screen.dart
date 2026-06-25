import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../log/screens/food_log_screen.dart';
import '../../scan/screens/scan_screen.dart';
import '../../barcode/screens/barcode_screen.dart';
import '../../goals/screens/goals_screen.dart';
import '../controllers/dashboard_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _HomeTab(),
    const FoodLogScreen(),
    const ScanScreen(),
    const GoalsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            // Scan button — open scan screen as modal
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4CAF50),
                    radius: 22,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Calorie Ring Card
              summaryAsync.when(
                data: (summary) => _CalorieCard(summary: summary),
                loading: () => const _CalorieCardSkeleton(),
                error: (_, __) => const _CalorieCard(
                  summary: DashboardSummary(
                    consumed: 0,
                    goal: 2000,
                    protein: 0,
                    carbs: 0,
                    fat: 0,
                    proteinGoal: 150,
                    carbsGoal: 250,
                    fatGoal: 65,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Macros Row
              summaryAsync.when(
                data: (summary) => _MacrosRow(summary: summary),
                loading: () => const _MacrosSkeleton(),
                error: (_, __) => const SizedBox(),
              ),

              const SizedBox(height: 24),

              // Quick Add section
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
                      MaterialPageRoute(builder: (_) => const FoodLogScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _QuickAddButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Barcode',
                    color: const Color(0xFFFF7043),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BarcodeScreen()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Today's meals
              const Text(
                "Today's Meals",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              summaryAsync.when(
                data: (summary) => summary.consumed == 0
                    ? _EmptyMeals()
                    : _MealsList(),
                loading: () => const _MealsSkeleton(),
                error: (_, __) => _EmptyMeals(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
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
    final remaining = (summary.goal - summary.consumed).clamp(0, summary.goal);

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
          // Ring chart
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
                        value: progress,
                        color: const Color(0xFF4CAF50),
                        radius: 12,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 1 - progress,
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
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Stats
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
                color: color, fontWeight: FontWeight.w600, fontSize: 13)),
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
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
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
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// Quick Add Button
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

// Empty meals
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

class _MealsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Meals will appear here'));
  }
}

// Skeletons
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