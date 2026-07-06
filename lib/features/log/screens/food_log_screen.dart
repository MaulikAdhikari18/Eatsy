import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/services/fatsecret_service.dart';
import '../../../features/dashboard/controllers/dashboard_controller.dart';

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
      print('🔍 Searching for: $query');
      final results = await fatSecretService.searchFood(query);
      print('✅ Results: ${results.length}');
      setState(() => _searchResults = results);
    } catch (e, stack) {
      print('❌ Search error: $e');
      print('Stack: $stack');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food['food_name']} added to $_selectedMealType!'),
            backgroundColor: const Color(0xFF4CAF50),
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
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('food_logs').delete().eq('id', id);
      _loadTodaysLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting log: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Food Log', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
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
                // Meal type selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _mealTypes.map((meal) {
                      final isSelected = _selectedMealType == meal;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedMealType = meal),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            meal[0].toUpperCase() + meal.substring(1),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
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

          // Search results
          if (_searchResults.isNotEmpty)
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  const Divider(height: 1),
                  ..._searchResults.map((food) => ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.restaurant,
                          color: Color(0xFF4CAF50), size: 20),
                    ),
                    title: Text(food['food_name'], style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${food['calories'].toInt()} kcal · P: ${food['protein']}g · C: ${food['carbs']}g · F: ${food['fat']}g',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: Color(0xFF4CAF50)),
                      onPressed: () => _logFood(food),
                    ),
                  )),
                ],
              ),
            )
          else if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            ),

          // Today's logs
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4CAF50)))
                : _todaysLogs.isEmpty
                ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.no_meals,
                      size: 48, color: const Color(0xFF9E9E9E)),
                  SizedBox(height: 12),
                  Text(
                    'No food logged today',
                    style: const TextStyle(color: Color(0xFF757575)),
                  ),
                  Text(
                    'Search above to add meals',
                    style: const TextStyle(
                        color: Color(0xFF757575), fontSize: 12),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _todaysLogs.length,
              itemBuilder: (context, index) {
                final log = _todaysLogs[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.restaurant,
                          color: Color(0xFF4CAF50), size: 20),
                    ),
                    title: Text(
                      log['food_name'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                    ),
                    subtitle: Text(
                      '${(log['calories'] ?? 0).toInt()} kcal · ${log['meal_type']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () =>
                          _deleteLog(log['id'].toString()),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}