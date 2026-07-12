import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../log/screens/food_log_screen.dart';
import '../../scan/screens/scan_screen.dart';
import '../../barcode/screens/barcode_screen.dart';
import '../../goals/screens/goals_screen.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/water_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../mealplan/screens/meal_plan_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/settings/unit_preferences_provider.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../shared/widgets/dotted_leader_row.dart';
import '../../../shared/widgets/receipt_decorations.dart';

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
      const MealPlanScreen(),
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
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Plan',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  void _showProfileMenu(BuildContext context, WidgetRef ref) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final colors = context.appColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
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
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.accent,
                  radius: 24,
                  child: Icon(Icons.person, color: colors.accentOnColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Appearance',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final currentMode = ref.watch(themeModeProvider);
                return Row(
                  children: [
                    _ThemeOption(
                      icon: Icons.light_mode_outlined,
                      label: 'Light',
                      selected: currentMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                    const SizedBox(width: 10),
                    _ThemeOption(
                      icon: Icons.dark_mode_outlined,
                      label: 'Dark',
                      selected: currentMode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark),
                    ),
                    const SizedBox(width: 10),
                    _ThemeOption(
                      icon: Icons.settings_suggest_outlined,
                      label: 'System',
                      selected: currentMode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Units',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final weightUnit = ref.watch(weightUnitProvider);
                return Row(
                  children: [
                    _ThemeOption(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Weight: kg',
                      selected: weightUnit == WeightUnit.kg,
                      onTap: () => ref
                          .read(weightUnitProvider.notifier)
                          .setUnit(WeightUnit.kg),
                    ),
                    const SizedBox(width: 10),
                    _ThemeOption(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Weight: lb',
                      selected: weightUnit == WeightUnit.lb,
                      onTap: () => ref
                          .read(weightUnitProvider.notifier)
                          .setUnit(WeightUnit.lb),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final waterUnit = ref.watch(waterUnitProvider);
                return Row(
                  children: [
                    _ThemeOption(
                      icon: Icons.water_drop_outlined,
                      label: 'Water: ml',
                      selected: waterUnit == WaterUnit.ml,
                      onTap: () => ref
                          .read(waterUnitProvider.notifier)
                          .setUnit(WaterUnit.ml),
                    ),
                    const SizedBox(width: 10),
                    _ThemeOption(
                      icon: Icons.water_drop_outlined,
                      label: 'Water: L',
                      selected: waterUnit == WaterUnit.liter,
                      onTap: () => ref
                          .read(waterUnitProvider.notifier)
                          .setUnit(WaterUnit.liter),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.flag_outlined, color: colors.textSecondary),
              title: const Text('Goals & Targets'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await Supabase.instance.client.auth.signOut();
                } catch (_) {}
                if (context.mounted) context.go('/');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('EEE MMM d').format(DateTime.now()).toUpperCase();
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final waterAsync = ref.watch(waterSummaryProvider);
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.accent,
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(waterSummaryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          today,
                          style: AppFonts.mono(
                            fontSize: 11,
                            color: colors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hey there',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _showProfileMenu(context, ref),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.person, color: colors.accentOnColor, size: 18),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                summaryAsync.when(
                  data: (summary) => _NutritionLabelCard(summary: summary),
                  loading: () => _NutritionLabelSkeleton(colors: colors),
                  error: (e, __) {
                    debugPrint('Dashboard error: $e');
                    return _NutritionLabelCard(
                      summary: DashboardSummary(
                        consumed: 0, goal: 2000, protein: 0, carbs: 0, fat: 0,
                        proteinGoal: 150, carbsGoal: 250, fatGoal: 65,
                        todaysMeals: const [],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.camera_alt,
                        label: 'Scan',
                        filled: true,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ScanScreen())),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.search,
                        label: 'Search',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const FoodLogScreen())),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.qr_code_scanner,
                        label: 'Code',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const BarcodeScreen())),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                waterAsync.when(
                  data: (summary) => _WaterCard(
                    summary: summary,
                    onAdd: (ml) async {
                      try {
                        await logWaterMl(ml);
                        ref.read(waterRefreshProvider.notifier).state++;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error logging water: $e')),
                          );
                        }
                      }
                    },
                    onRemove: (ml) async {
                      // Clamp so a removal can never push today's total
                      // below zero — e.g. tapping "-1L" after only
                      // logging 250ml just zeroes it out instead of
                      // going negative. Synchronous math on `summary`,
                      // so it stays outside the try — can't throw.
                      final amount =
                      ml > summary.consumedMl ? summary.consumedMl : ml;
                      if (amount <= 0) return;
                      try {
                        await removeWaterMl(amount);
                        ref.read(waterRefreshProvider.notifier).state++;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error removing water: $e')),
                          );
                        }
                      }
                    },
                  ),
                  loading: () => _WaterCardSkeleton(colors: colors),
                  error: (_, __) => _WaterCardSkeleton(colors: colors),
                ),

                const SizedBox(height: 24),

                summaryAsync.when(
                  data: (summary) {
                    if (summary.todaysMeals.isEmpty) {
                      return _EmptyReceipt(colors: colors);
                    }
                    return _ReceiptCard(meals: summary.todaysMeals);
                  },
                  loading: () => Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  error: (_, __) => _EmptyReceipt(colors: colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.accent.withOpacity(0.18) : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.accent : colors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? colors.textPrimary : colors.textSecondary),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? colors.textPrimary : colors.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// The signature dashboard element: a dark "nutrition label" card with
/// a decorative barcode strip, big mono calorie total, a torn/zigzag
/// bottom edge, and a color-coded macro strip below it.
class _NutritionLabelCard extends StatelessWidget {
  final DashboardSummary summary;
  const _NutritionLabelCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final remaining = (summary.goal - summary.consumed).clamp(0, summary.goal);

    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Container(
            color: colors.labelCard,
            child: Column(
              children: [
                const SizedBox(height: 12),
                BarcodeStrip(color: colors.accent),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NUTRITION FACTS · TODAY',
                              style: AppFonts.mono(
                                fontSize: 10,
                                color: colors.accent,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${summary.consumed.toInt()}',
                                  style: AppFonts.mono(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  ' / ${summary.goal} kcal',
                                  style: AppFonts.mono(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '-$remaining kcal',
                          style: AppFonts.mono(
                            fontSize: 11,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        ZigzagEdge(color: colors.labelCard),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.divider),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(
            children: [
              _MacroStat(label: 'PROTEIN', value: '${summary.protein.toInt()}g', color: colors.protein),
              _MacroStat(label: 'CARBS', value: '${summary.carbs.toInt()}g', color: colors.carbs),
              _MacroStat(label: 'FAT', value: '${summary.fat.toInt()}g', color: colors.fat),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.mono(fontSize: 9, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value, style: AppFonts.mono(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Water tracking card: today's total against a daily goal, a thin
/// progress bar, quick-add pills, and a mirrored quick-remove row for
/// correcting an accidental tap — same visual weight as the macro strip
/// on the nutrition label card above it, just its own dedicated "water"
/// blue instead of a macro color. A ConsumerWidget (not Stateless) so
/// it can watch `waterUnitProvider` and format ml vs. L on its own.
class _WaterCard extends ConsumerWidget {
  final WaterSummary summary;
  final void Function(int ml) onAdd;
  final void Function(int ml) onRemove;
  const _WaterCard({required this.summary, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final unit = ref.watch(waterUnitProvider);
    final isLiter = unit == WaterUnit.liter;
    final progress = summary.goalMl > 0
        ? (summary.consumedMl / summary.goalMl).clamp(0.0, 1.0)
        : 0.0;

    String totalLabel(int ml) => isLiter
        ? UnitConverter.mlToL(ml).toStringAsFixed(2)
        : ml.toString();
    // "+1L" reads better than "+1000ml" even in ml mode, so only the
    // 250/500 pills change wording between units — 1000 stays "1L"
    // either way.
    String pillLabel(int ml, {required bool isAdd}) {
      final sign = isAdd ? '+' : '-';
      if (ml == 1000) return '$sign${'1L'}';
      final text = isLiter ? UnitConverter.mlToL(ml).toStringAsFixed(2) : '$ml';
      final suffix = isLiter ? 'L' : 'ml';
      return '$sign$text$suffix';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop, size: 15, color: colors.water),
                  const SizedBox(width: 6),
                  Text(
                    'WATER',
                    style: AppFonts.mono(
                      fontSize: 11,
                      color: colors.water,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Text(
                '${totalLabel(summary.consumedMl)} / ${totalLabel(summary.goalMl)} ${isLiter ? 'L' : 'ml'}',
                style: AppFonts.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(colors.water),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _WaterPillButton(
                label: pillLabel(250, isAdd: true),
                color: colors.water,
                onTap: () => onAdd(250),
              ),
              const SizedBox(width: 8),
              _WaterPillButton(
                label: pillLabel(500, isAdd: true),
                color: colors.water,
                onTap: () => onAdd(500),
              ),
              const SizedBox(width: 8),
              _WaterPillButton(
                label: pillLabel(1000, isAdd: true),
                color: colors.water,
                onTap: () => onAdd(1000),
              ),
            ],
          ),
          // Only show a remove row once there's actually something
          // logged today — nothing to correct otherwise, and it keeps
          // the card compact for the common "haven't drunk anything
          // yet" state.
          if (summary.consumedMl > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _WaterPillButton(
                  label: pillLabel(250, isAdd: false),
                  color: colors.fat,
                  onTap: () => onRemove(250),
                ),
                const SizedBox(width: 8),
                _WaterPillButton(
                  label: pillLabel(500, isAdd: false),
                  color: colors.fat,
                  onTap: () => onRemove(500),
                ),
                const SizedBox(width: 8),
                _WaterPillButton(
                  label: pillLabel(1000, isAdd: false),
                  color: colors.fat,
                  onTap: () => onRemove(1000),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WaterPillButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _WaterPillButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ),
    );
  }
}

class _WaterCardSkeleton extends StatelessWidget {
  final AppColors colors;
  const _WaterCardSkeleton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
    );
  }
}

class _NutritionLabelSkeleton extends StatelessWidget {
  final AppColors colors;
  const _NutritionLabelSkeleton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colors.labelCard,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: colors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: filled ? colors.accentOnColor : colors.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? colors.accentOnColor : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final List<Map<String, dynamic>> meals;
  const _ReceiptCard({required this.meals});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final total = meals.fold<double>(
        0, (sum, m) => sum + ((m['calories'] ?? 0) as num).toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Receipt',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            Text('${meals.length} ITEMS',
                style: AppFonts.mono(fontSize: 10, color: colors.textMuted, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              ...meals.take(6).map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: DottedLeaderRow(
                  label: m['food_name']?.toString() ?? '',
                  value: '${((m['calories'] ?? 0) as num).toInt()}',
                  valueColor: colors.mealTypeColor(m['meal_type']?.toString() ?? ''),
                ),
              )),
              Divider(color: colors.divider, height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DottedLeaderRow(
                  label: 'Subtotal',
                  value: '${total.toInt()} kcal',
                  labelFontWeight: FontWeight.w700,
                  valueFontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyReceipt extends StatelessWidget {
  final AppColors colors;
  const _EmptyReceipt({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: colors.textMuted),
          const SizedBox(height: 10),
          Text('No meals logged yet',
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('Tap Scan or Search to add your first meal',
              style: TextStyle(color: colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}