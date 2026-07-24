import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../log/screens/food_log_screen.dart';
import '../../scan/screens/scan_screen.dart';
import '../../barcode/screens/barcode_screen.dart';
import '../../goals/screens/goals_screen.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/water_controller.dart';
import '../controllers/tip_controller.dart';
import '../controllers/weekly_trends_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../mealplan/screens/meal_plan_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/settings/unit_preferences_provider.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/utils/serving_format.dart';
import '../../../core/utils/legal_links.dart';
import '../../../shared/widgets/dotted_leader_row.dart';
import '../../../shared/widgets/receipt_decorations.dart';
import '../../../shared/widgets/unit_dropdown.dart';

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
            // NOTE: the old "Units" section (Weight kg/lb pills, Water
            // ml/L pills) that used to live here has been removed on
            // purpose. Units are now controlled inline, right next to
            // the fields they affect — Target Weight, Log Today's
            // Weight, and Weight History all get a dropdown next to
            // them on the Goals screen; the water card below gets one
            // next to its total. Every one of those dropdowns reads and
            // writes the exact same weightUnitProvider / waterUnitProvider
            // as before, so there's still a single source of truth for
            // "what unit is this app in right now" — it's just exposed
            // where it's actually used instead of buried in a separate
            // settings sheet, and a per-field toggle here would have
            // been a second, redundant control for the same state.
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
              leading: Icon(Icons.privacy_tip_outlined, color: colors.textSecondary),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.pop(sheetContext);
                LegalLinks.openPrivacyPolicy(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: colors.textSecondary),
              title: const Text('Terms of Service'),
              onTap: () {
                Navigator.pop(sheetContext);
                LegalLinks.openTermsOfService(context);
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
            Divider(height: 24, color: colors.divider),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              subtitle: Text('Permanently erase your data',
                  style: TextStyle(color: colors.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/delete-account');
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
    final trendsAsync = ref.watch(weeklyTrendsProvider);
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.accent,
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(waterSummaryProvider);
            ref.invalidate(weeklyTrendsProvider);
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
                      // going negative.
                      final amount =
                      ml > summary.consumedMl ? summary.consumedMl : ml;
                      if (amount <= 0) return;
                      try {
                        await removeWaterMl(amount);
                        ref.read(waterRefreshProvider.notifier).state++;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating water: $e')),
                          );
                        }
                      }
                    },
                  ),
                  loading: () => _WaterCardSkeleton(colors: colors),
                  error: (_, __) => _WaterCardSkeleton(colors: colors),
                ),

                const SizedBox(height: 24),

                const _TipCard(),

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

                const SizedBox(height: 24),

                trendsAsync.when(
                  data: (summary) => _WeeklyTrendsCard(summary: summary),
                  loading: () => _WeeklyTrendsSkeleton(colors: colors),
                  error: (_, __) => const SizedBox.shrink(),
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
            color: selected ? colors.accent.withValues(alpha: 0.18) : colors.surfaceVariant,
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
                                  '${summary.consumed.round()}',
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
              _MacroStat(label: 'PROTEIN', value: '${summary.protein.round()}g', color: colors.protein),
              _MacroStat(label: 'CARBS', value: '${summary.carbs.round()}g', color: colors.carbs),
              _MacroStat(label: 'FAT', value: '${summary.fat.round()}g', color: colors.fat),
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
/// correcting an accidental tap. Now supports all four WaterUnit values
/// (ml / L / fl oz / glasses) via an inline dropdown next to the total,
/// instead of relying on the old Settings-only ml/L toggle.
class _WaterCard extends ConsumerWidget {
  final WaterSummary summary;
  final void Function(int ml) onAdd;
  final void Function(int ml) onRemove;
  const _WaterCard({required this.summary, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final unit = ref.watch(waterUnitProvider);
    final progress = summary.goalMl > 0
        ? (summary.consumedMl / summary.goalMl).clamp(0.0, 1.0)
        : 0.0;

    String totalLabel(int ml) => switch (unit) {
      WaterUnit.liter => UnitConverter.mlToL(ml).toStringAsFixed(2),
      WaterUnit.flOz => UnitConverter.mlToFlOz(ml).toStringAsFixed(0),
      WaterUnit.glasses => UnitConverter.mlToGlasses(ml).round().toString(),
      WaterUnit.ml => ml.toString(),
    };

    String unitSuffix() => switch (unit) {
      WaterUnit.liter => 'L',
      WaterUnit.flOz => 'fl oz',
      WaterUnit.glasses => 'glasses',
      WaterUnit.ml => 'ml',
    };

    String pillLabel(int ml, {required bool isAdd}) {
      final sign = isAdd ? '+' : '-';
      switch (unit) {
        case WaterUnit.glasses:
          final g = (ml / UnitConverter.mlPerGlass).round();
          return '$sign$g glass${g == 1 ? '' : 'es'}';
        case WaterUnit.liter:
          if (ml == 1000) return '${sign}1L';
          return '$sign${UnitConverter.mlToL(ml).toStringAsFixed(2)}L';
        case WaterUnit.flOz:
          return '$sign${UnitConverter.mlToFlOz(ml).toStringAsFixed(0)}fl oz';
        case WaterUnit.ml:
          return '$sign${ml}ml';
      }
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${totalLabel(summary.consumedMl)} / ${totalLabel(summary.goalMl)} ${unitSuffix()}',
                    style: AppFonts.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  UnitDropdown<WaterUnit>(
                    value: unit,
                    options: waterUnitOptions,
                    color: colors.water,
                    onChanged: (u) => ref.read(waterUnitProvider.notifier).setUnit(u),
                  ),
                ],
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
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
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

/// "AI Tip of the Day" — see tip_controller.dart for the rule
/// evaluation. Category drives both the icon and the accent color,
/// reusing existing semantic colors (protein/carbs/water/accent)
/// rather than introducing new ones just for this card.
class _TipCard extends ConsumerWidget {
  const _TipCard();

  Color _colorFor(TipCategory category, AppColors colors) {
    switch (category) {
      case TipCategory.engagement:
        return colors.accent;
      case TipCategory.nutrition:
        return colors.carbs;
      case TipCategory.hydration:
        return colors.water;
      case TipCategory.general:
        return colors.textSecondary;
    }
  }

  IconData _iconFor(TipCategory category) {
    switch (category) {
      case TipCategory.engagement:
        return Icons.notifications_active_outlined;
      case TipCategory.nutrition:
        return Icons.restaurant_outlined;
      case TipCategory.hydration:
        return Icons.water_drop_outlined;
      case TipCategory.general:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final dismissed = ref.watch(tipDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    final tipAsync = ref.watch(dailyTipProvider);

    return tipAsync.when(
      data: (tip) {
        final color = _colorFor(tip.category, colors);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(tip.category), size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIP OF THE DAY',
                      style: AppFonts.mono(
                        fontSize: 10,
                        color: color,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ref.read(tipDismissedProvider.notifier).state = true,
                child: Icon(Icons.close, size: 16, color: colors.textMuted),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 76,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.divider),
        ),
      ),
      // If the tip genuinely fails to load, just don't show the card
      // rather than showing an error state for something this low-stakes.
      error: (_, __) => const SizedBox.shrink(),
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
              ...meals.take(6).map((m) {
                final subtitle = servingSubtitle(m);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DottedLeaderRow(
                        label: m['food_name']?.toString() ?? '',
                        value: '${((m['calories'] ?? 0) as num).round()}',
                        valueColor: colors.mealTypeColor(m['meal_type']?.toString() ?? ''),
                      ),
                      // Same rule as Food Log: rows logged before this
                      // feature existed have no serving_size/quantity,
                      // so they simply show no subtitle at all.
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppFonts.mono(fontSize: 10, color: colors.textMuted),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              Divider(color: colors.divider, height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DottedLeaderRow(
                  label: 'Subtotal',
                  value: '${total.round()} kcal',
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

const _monthLabels = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

String _weekRangeLabel(DateTime start, DateTime end) {
  final startLabel = '${_monthLabels[start.month - 1]} ${start.day}';
  if (start.month == end.month) return '$startLabel–${end.day}';
  return '$startLabel – ${_monthLabels[end.month - 1]} ${end.day}';
}

/// Always Mon–Sun, never a rolling 7-day window — see
/// weekly_trends_controller.dart. Tapping a bar swaps the detail panel
/// below the chart to that day; the currently-selected bar gets an
/// outline, and today's bar is filled in the dark ink color instead of
/// accent so it reads as "today" at a glance, same convention as the
/// day selector on Meal Plan.
class _WeeklyTrendsCard extends ConsumerStatefulWidget {
  final WeeklyTrendsSummary summary;
  const _WeeklyTrendsCard({required this.summary});

  @override
  ConsumerState<_WeeklyTrendsCard> createState() => _WeeklyTrendsCardState();
}

class _WeeklyTrendsCardState extends ConsumerState<_WeeklyTrendsCard> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = (DateTime.now().weekday - 1).clamp(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final days = widget.summary.days;
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    final selected = days[_selectedIndex];

    final tallestDay =
    days.map((d) => d.calories).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = tallestDay > widget.summary.goalCalories
        ? tallestDay
        : widget.summary.goalCalories.toDouble();

    const chartHeight = 110.0;
    // A dashed line would need a CustomPainter — a thin muted solid
    // line conveys "this is the goal" just as clearly at a fraction of
    // the code, so that's what this is instead of a literal dashed rule.
    final goalLineFromBottom = chartMax > 0
        ? chartHeight * (widget.summary.goalCalories / chartMax).clamp(0.0, 1.0)
        : 0.0;

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
              Text(
                'WEEKLY TRENDS',
                style: AppFonts.mono(
                    fontSize: 11, color: colors.textSecondary, letterSpacing: 1),
              ),
              Text(
                _weekRangeLabel(days.first.date, days.last.date),
                style: AppFonts.mono(fontSize: 10, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: goalLineFromBottom,
                  child: Container(height: 1.5, color: colors.textMuted.withValues(alpha: 0.4)),
                ),
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final d = days[i];
                      final h = chartMax > 0
                          ? (d.calories / chartMax).clamp(0.0, 1.0)
                          : 0.0;
                      final isToday = i == todayIndex;
                      final isSelected = i == _selectedIndex;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIndex = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Container(
                              height: chartHeight * h,
                              decoration: BoxDecoration(
                                color: isToday ? colors.labelCard : colors.accent,
                                borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(4)),
                                border: isSelected
                                    ? Border.all(color: colors.textPrimary, width: 2)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Row(
            children: List.generate(7, (i) {
              final isToday = i == todayIndex;
              return Expanded(
                child: Text(
                  days[i].label,
                  textAlign: TextAlign.center,
                  style: AppFonts.mono(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: selected.mealCount == 0
                ? Text(
              '${selected.label} — nothing logged',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selected.label,
                      style: AppFonts.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary),
                    ),
                    Text(
                      '${selected.calories.round()} kcal',
                      style: AppFonts.mono(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _TrendMacro(
                        label: 'PROTEIN',
                        value: '${selected.protein.round()}g',
                        color: colors.protein),
                    _TrendMacro(
                        label: 'CARBS',
                        value: '${selected.carbs.round()}g',
                        color: colors.carbs),
                    _TrendMacro(
                        label: 'FAT',
                        value: '${selected.fat.round()}g',
                        color: colors.fat),
                    const Spacer(),
                    Text(
                      '${selected.mealCount} meal${selected.mealCount == 1 ? '' : 's'}',
                      style: AppFonts.mono(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AVG / DAY',
                        style: AppFonts.mono(
                            fontSize: 9, color: colors.textMuted, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.summary.avgCaloriesPerDay.round()} kcal',
                      style: AppFonts.mono(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WEIGHT THIS WEEK',
                        style: AppFonts.mono(
                            fontSize: 9, color: colors.textMuted, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(
                      widget.summary.weightChangeKg == null
                          ? 'Not enough data'
                          : '${widget.summary.weightChangeKg! >= 0 ? '+' : ''}'
                          '${widget.summary.weightChangeKg!.toStringAsFixed(1)} kg',
                      style: AppFonts.mono(
                        fontSize: widget.summary.weightChangeKg == null ? 12 : 16,
                        fontWeight: FontWeight.w600,
                        color: widget.summary.weightChangeKg == null
                            ? colors.textMuted
                            : colors.protein,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendMacro extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TrendMacro({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.mono(fontSize: 9, color: color, letterSpacing: 0.3)),
          Text(value,
              style: AppFonts.mono(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _WeeklyTrendsSkeleton extends StatelessWidget {
  final AppColors colors;
  const _WeeklyTrendsSkeleton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
    );
  }
}