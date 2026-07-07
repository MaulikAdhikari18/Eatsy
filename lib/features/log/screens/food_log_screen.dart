import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/fatsecret_service.dart';
import '../../../features/dashboard/controllers/dashboard_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/dotted_leader_row.dart';

// AppTheme is only used here for AppFonts.mono. Every color below comes
// from context.appColors (colors.*) — same as the Dashboard. There is
// no AppTheme.primary anywhere in this file; that's a hardcoded,
// non-theme-aware color left over from the pre-AppColors screens.

class FoodLogScreen extends ConsumerStatefulWidget {
  const FoodLogScreen({super.key});

  @override
  ConsumerState<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends ConsumerState<FoodLogScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _todaysLogs = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String _selectedMealType = 'breakfast';

  // Order drives the stacking order of the meal-group cards below,
  // matching the Design Preview PDF (Breakfast → Lunch → Dinner → Snack).
  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void initState() {
    super.initState();
    _loadTodaysLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTodaysLogs() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final logs = await supabase
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .lt('logged_at', endOfDay.toIso8601String())
          .order('logged_at', ascending: false);

      setState(() => _todaysLogs = List<Map<String, dynamic>>.from(logs));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchFood(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await fatSecretService.searchFood(query);
      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _logFood(Map<String, dynamic> food) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('food_logs').insert({
        'user_id': userId,
        'food_name': food['food_name'],
        'calories': food['calories'],
        'protein': food['protein'],
        'carbs': food['carbs'],
        'fat': food['fat'],
        'meal_type': _selectedMealType,
        'logged_at': DateTime.now().toIso8601String(),
      });

      // Trigger dashboard refresh
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food['food_name']} added to $_selectedMealType!'),
            backgroundColor: colors.accent,
          ),
        );
        _searchController.clear();
        setState(() => _searchResults = []);
        _loadTodaysLogs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging food: $e')),
        );
      }
    }
  }

  Future<void> _deleteLog(String id) async {
    // Optimistic removal so the swipe-to-delete feels instant, then
    // reconcile with the server; _loadTodaysLogs() will correct state
    // if the delete actually failed.
    setState(() => _todaysLogs.removeWhere((l) => l['id'].toString() == id));
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('food_logs').delete().eq('id', id);
      ref.invalidate(dashboardSummaryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting log: $e')),
        );
      }
      _loadTodaysLogs();
    }
  }

  /// Buckets today's logs by meal_type, preserving the fixed
  /// breakfast → lunch → dinner → snack order regardless of insertion
  /// order, and dropping meal types with nothing logged yet.
  List<MapEntry<String, List<Map<String, dynamic>>>> _groupedLogs() {
    final Map<String, List<Map<String, dynamic>>> grouped = {
      for (final m in _mealTypes) m: <Map<String, dynamic>>[],
    };
    for (final log in _todaysLogs) {
      final type = log['meal_type']?.toString() ?? 'snack';
      (grouped[type] ??= <Map<String, dynamic>>[]).add(log);
    }
    return grouped.entries.where((e) => e.value.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final groups = _groupedLogs();

    return Scaffold(
      backgroundColor: colors.background,
      // AppBar restored: this screen is reached two ways — as a bottom-nav
      // tab (not poppable, so no back arrow shows) AND pushed via the
      // Dashboard's "Search" quick action (poppable, so it does). A bare
      // AppBar with just a title lets Flutter handle that automatically —
      // same convention as Goals / Diet Preferences / Barcode.
      appBar: AppBar(
        title: const Text('Food Log'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search + meal-type selector — fixed header block.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _searchFood,
                    decoration: InputDecoration(
                      hintText: 'Search for food...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _mealTypes.map((meal) {
                        final isSelected = _selectedMealType == meal;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMealType = meal),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.labelCard
                                  : colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              meal[0].toUpperCase() + meal.substring(1),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : colors.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Search results — a floating card of matches, tap "+" to log
            // into whichever meal type chip is currently selected above.
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.divider),
                ),
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  children: _searchResults.map((food) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.accent.withOpacity(0.15),
                      child: Icon(Icons.restaurant,
                          color: colors.accent, size: 20),
                    ),
                    title: Text(food['food_name'],
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${food['calories'].toInt()} kcal · P: ${food['protein']}g · C: ${food['carbs']}g · F: ${food['fat']}g',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.add_circle, color: colors.accent),
                      onPressed: () => _logFood(food),
                    ),
                  )).toList(),
                ),
              )
            else if (_isSearching)
              Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: colors.accent),
              ),

            if (_searchResults.isNotEmpty || _isSearching)
              const SizedBox(height: 12),

            // Today's logged meals — one nutrition-label style card per
            // meal type, each with a colored left border and a dotted
            // leader row per item, exactly mirroring the Design Preview.
            Expanded(
              child: _isLoading
                  ? Center(
                  child: CircularProgressIndicator(color: colors.accent))
                  : groups.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.no_meals, size: 48, color: colors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No food logged today',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    Text(
                      'Search above to add meals',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: groups
                    .map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MealGroupCard(
                    mealType: entry.key,
                    items: entry.value,
                    onDelete: _deleteLog,
                  ),
                ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One meal-type card: colored left border matching `mealTypeColor`,
/// an uppercase mono label (same treatment as the Dashboard's PROTEIN /
/// CARBS / FAT labels), a dotted-leader row per food item, and a bold
/// subtotal row — the exact pattern from the Food Log page of the
/// Design Preview PDF.
class _MealGroupCard extends StatelessWidget {
  final String mealType;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String id) onDelete;

  const _MealGroupCard({
    required this.mealType,
    required this.items,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = colors.mealTypeColor(mealType);
    final subtotal = items.fold<double>(
        0, (sum, m) => sum + ((m['calories'] ?? 0) as num).toDouble());

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 10),
          ...items.map((item) => Dismissible(
            key: ValueKey(item['id'].toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 4),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
            onDismissed: (_) => onDelete(item['id'].toString()),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: DottedLeaderRow(
                label: item['food_name']?.toString() ?? '',
                value: '${((item['calories'] ?? 0) as num).toInt()}',
              ),
            ),
          )),
          Divider(height: 18, color: colors.divider),
          DottedLeaderRow(
            label: 'Subtotal',
            value: '${subtotal.toInt()} kcal',
            labelFontWeight: FontWeight.w700,
            valueFontSize: 14,
          ),
        ],
      ),
    );
  }
}