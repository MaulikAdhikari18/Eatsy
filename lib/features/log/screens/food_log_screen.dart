import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
      // Placeholder — will connect to FatSecret API later
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _searchResults = [
          {
            'food_name': 'Apple',
            'calories': 95.0,
            'protein': 0.5,
            'carbs': 25.0,
            'fat': 0.3,
          },
          {
            'food_name': 'Banana',
            'calories': 105.0,
            'protein': 1.3,
            'carbs': 27.0,
            'fat': 0.4,
          },
          {
            'food_name': 'Chicken Breast (100g)',
            'calories': 165.0,
            'protein': 31.0,
            'carbs': 0.0,
            'fat': 3.6,
          },
          {
            'food_name': 'Brown Rice (1 cup)',
            'calories': 216.0,
            'protein': 5.0,
            'carbs': 45.0,
            'fat': 1.8,
          },
          {
            'food_name': 'Whole Milk (1 cup)',
            'calories': 149.0,
            'protein': 8.0,
            'carbs': 12.0,
            'fat': 8.0,
          },
        ].where((f) => f['food_name']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
            .toList();
      });
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
        title: const Text('Food Log'),
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
                    title: Text(food['food_name']),
                    subtitle: Text(
                      '${food['calories'].toInt()} kcal · P: ${food['protein']}g · C: ${food['carbs']}g · F: ${food['fat']}g',
                      style: const TextStyle(fontSize: 12),
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
                      size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No food logged today',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Search above to add meals',
                    style: TextStyle(
                        color: Colors.grey, fontSize: 12),
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
                          fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${(log['calories'] ?? 0).toInt()} kcal · ${log['meal_type']}',
                      style: const TextStyle(fontSize: 12),
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