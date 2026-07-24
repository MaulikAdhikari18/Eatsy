import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/food_data_service.dart';
import '../../../features/dashboard/controllers/dashboard_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/dotted_leader_row.dart';
import '../../../shared/widgets/serving_quantity_picker.dart';
import '../../../core/utils/serving_format.dart';
import '../../../core/utils/day_boundary.dart';

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
  // Open Food Facts allows only 10 search requests/min per IP and
  // explicitly says not to use it for search-as-you-type — this timer
  // waits for a pause in typing before actually firing a request,
  // instead of calling the API on every keystroke.
  Timer? _searchDebounce;
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTodaysLogs() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final startOfDay = DayBoundary.startOfLocalDay();
      final endOfDay = DayBoundary.endOfLocalDay();

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

  /// Called directly by the search field's onChanged. Cancels any
  /// pending search and schedules a new one 500ms out, so a request is
  /// only actually sent once the person pauses typing — respects Open
  /// Food Facts' 10 req/min limit instead of firing on every keystroke.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchFood(query);
    });
  }

  Future<void> _searchFood(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await foodDataService.searchFood(query);
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

  Future<void> _logFood(Map<String, dynamic> food, String servingSize,
      double quantity, String mealType) async {
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
        'serving_size': servingSize,
        'quantity': quantity,
        'meal_type': mealType,
        'logged_at': DayBoundary.nowUtcIso(),
      });

      // Trigger dashboard refresh
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food['food_name']} added to $mealType!'),
            backgroundColor: colors.accent,
          ),
        );
        _searchDebounce?.cancel();
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

  /// Opens the serving-size/quantity sheet for a search result. Meal
  /// type defaults to whatever chip is selected on the main screen, but
  /// can be changed inside the sheet without affecting that selection
  /// until "Add to Log" is actually tapped.
  void _showLogSheet(Map<String, dynamic> baseFood) {
    final colors = context.appColors;
    Map<String, dynamic> scaledFood = Map.from(baseFood);
    String servingSize = '1 serving';
    double quantity = 1.0;
    String sheetMealType = _selectedMealType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
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
                const SizedBox(height: 16),
                Text(
                  baseFood['food_name']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ServingQuantityPicker(
                  baseFood: baseFood,
                  onChanged: (scaled, serving, qty) {
                    scaledFood = scaled;
                    servingSize = serving;
                    quantity = qty;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Add to meal',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: colors.textPrimary),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _mealTypes.map((meal) {
                      final isSelected = sheetMealType == meal;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => sheetMealType = meal),
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
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _logFood(scaledFood, servingSize, quantity, sheetMealType);
                  },
                  child: const Text('Add to Log'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search for food...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchDebounce?.cancel();
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
                      backgroundColor: colors.accent.withValues(alpha: 0.15),
                      child: Icon(Icons.restaurant,
                          color: colors.accent, size: 20),
                    ),
                    title: Text(food['food_name'],
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${food['calories'].round()} kcal · P: ${food['protein']}g · C: ${food['carbs']}g · F: ${food['fat']}g',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.add_circle, color: colors.accent),
                      onPressed: () => _showLogSheet(food),
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
/// CARBS / FAT labels), a dotted-leader row per food item (with its
/// logged serving size/quantity as a small subtitle beneath, when
/// present), and a bold subtotal row.
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
          ...items.map((item) {
            final subtitle = servingSubtitle(item);
            return Dismissible(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DottedLeaderRow(
                      label: item['food_name']?.toString() ?? '',
                      value: '${((item['calories'] ?? 0) as num).round()}',
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          Divider(height: 18, color: colors.divider),
          DottedLeaderRow(
            label: 'Subtotal',
            value: '${subtotal.round()} kcal',
            labelFontWeight: FontWeight.w700,
            valueFontSize: 14,
          ),
        ],
      ),
    );
  }
}