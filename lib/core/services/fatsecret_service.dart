import 'package:dio/dio.dart';
import '../config/app_config.dart';

class FatSecretService {
  final Dio _dio = Dio();

  // Your Supabase edge function URL
  static const String _proxyUrl =
      'https://ghobobiocpjfiwcrrfbr.supabase.co/functions/v1/fatsecret-proxy';

  Options get _options => Options(
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${AppConfig.supabaseKey}',
    },
    validateStatus: (status) => true,
  );

  Future<dynamic> _call(String method, Map<String, dynamic> params) async {
    final response = await _dio.post(
      _proxyUrl,
      options: _options,
      data: {'method': method, 'params': params},
    );
    print('📦 Proxy response [$method]: ${response.data}');
    return response.data;
  }

  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (query.isEmpty) return [];
    try {
      final data = await _call('foods.search', {
        'search_expression': query,
        'max_results': 10,
      });

      if (data['error'] != null) {
        print('❌ API error: ${data['error']}');
        return _localSearch(query);
      }

      final foods = data['foods']?['food'];
      if (foods == null) return _localSearch(query);

      final foodList = foods is List ? foods : [foods];
      return foodList.map<Map<String, dynamic>>((food) {
        final description = food['food_description'] ?? '';
        return {
          'food_id': food['food_id'],
          'food_name': food['food_name'],
          'calories': _parseNutrient(description, 'Calories', 'kcal'),
          'fat': _parseNutrient(description, 'Fat', 'g'),
          'carbs': _parseNutrient(description, 'Carbs', 'g'),
          'protein': _parseNutrient(description, 'Protein', 'g'),
        };
      }).toList();
    } catch (e) {
      print('❌ Search error: $e');
      return _localSearch(query);
    }
  }

  Future<Map<String, dynamic>?> getFoodByBarcode(String barcode) async {
    // Check local DB first for common Indian products
    final local = _localBarcodeSearch(barcode);
    if (local != null) return local;

    try {
      final data = await _call('food.find_id_for_barcode', {
        'barcode': barcode,
      });

      if (data['error'] != null) return null;

      final foodId = data['food_id']?['value'];
      if (foodId == null) return null;

      return await getFoodById(foodId);
    } catch (e) {
      print('❌ Barcode error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFoodById(String foodId) async {
    try {
      final data = await _call('food.get.v4', {'food_id': foodId});

      if (data['error'] != null) return null;

      final food = data['food'];
      if (food == null) return null;

      final serving = food['servings']?['serving'];
      final firstServing = serving is List ? serving[0] : serving;

      return {
        'food_name': food['food_name'],
        'calories': double.tryParse(
            firstServing?['calories']?.toString() ?? '0') ?? 0,
        'protein': double.tryParse(
            firstServing?['protein']?.toString() ?? '0') ?? 0,
        'carbs': double.tryParse(
            firstServing?['carbohydrate']?.toString() ?? '0') ?? 0,
        'fat': double.tryParse(
            firstServing?['fat']?.toString() ?? '0') ?? 0,
      };
    } catch (e) {
      print('❌ Food detail error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> recognizeFood(dynamic imageFile) async {
    return null; // Requires Premier API
  }

  double _parseNutrient(String desc, String nutrient, String unit) {
    try {
      final match = RegExp('$nutrient: ([0-9.]+)$unit').firstMatch(desc);
      return double.tryParse(match?.group(1) ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // Local barcode database
  Map<String, dynamic>? _localBarcodeSearch(String barcode) {
    final barcodes = {
      '8901058000512': {'food_name': 'Maggi 2-Minute Noodles', 'calories': 350.0, 'protein': 8.0, 'carbs': 54.0, 'fat': 12.0},
      '8901058852398': {'food_name': 'Maggi 2-Minute Noodles', 'calories': 350.0, 'protein': 8.0, 'carbs': 54.0, 'fat': 12.0},
      '8901719110719': {'food_name': 'Parle-G Biscuits (100g)', 'calories': 451.0, 'protein': 7.0, 'carbs': 72.0, 'fat': 15.0},
      '8901063018496': {'food_name': 'Amul Butter (100g)', 'calories': 720.0, 'protein': 0.5, 'carbs': 0.5, 'fat': 80.0},
      '8901237100031': {'food_name': 'Cadbury Dairy Milk (45g)', 'calories': 240.0, 'protein': 3.5, 'carbs': 28.0, 'fat': 13.0},
      '7622210449283': {'food_name': 'Cadbury Dairy Milk (45g)', 'calories': 240.0, 'protein': 3.5, 'carbs': 28.0, 'fat': 13.0},
      '8901725125521': {'food_name': 'Sunfeast Yippee Noodles', 'calories': 310.0, 'protein': 7.0, 'carbs': 48.0, 'fat': 10.0},
      '8906002780016': {'food_name': 'Haldiram Aloo Bhujia', 'calories': 536.0, 'protein': 10.0, 'carbs': 52.0, 'fat': 32.0},
      '5449000000996': {'food_name': 'Coca Cola (330ml)', 'calories': 139.0, 'protein': 0.0, 'carbs': 35.0, 'fat': 0.0},
      '8901063900139': {'food_name': 'Britannia Marie Gold', 'calories': 423.0, 'protein': 8.0, 'carbs': 75.0, 'fat': 9.0},
    };
    return barcodes[barcode];
  }

  // Local food search fallback
  List<Map<String, dynamic>> _localSearch(String query) {
    final foods = [
      {'food_name': 'Chicken Breast (100g)', 'calories': 165.0, 'protein': 31.0, 'carbs': 0.0, 'fat': 3.6},
      {'food_name': 'Chicken Curry', 'calories': 150.0, 'protein': 12.0, 'carbs': 8.0, 'fat': 8.0},
      {'food_name': 'Boiled Egg', 'calories': 78.0, 'protein': 6.0, 'carbs': 0.6, 'fat': 5.0},
      {'food_name': 'White Rice (1 cup)', 'calories': 206.0, 'protein': 4.3, 'carbs': 44.5, 'fat': 0.4},
      {'food_name': 'Roti / Chapati', 'calories': 104.0, 'protein': 3.1, 'carbs': 18.0, 'fat': 2.5},
      {'food_name': 'Dal (1 cup)', 'calories': 230.0, 'protein': 18.0, 'carbs': 40.0, 'fat': 1.0},
      {'food_name': 'Dal Makhani', 'calories': 320.0, 'protein': 14.0, 'carbs': 38.0, 'fat': 12.0},
      {'food_name': 'Paneer (100g)', 'calories': 265.0, 'protein': 18.0, 'carbs': 3.4, 'fat': 20.0},
      {'food_name': 'Paneer Butter Masala', 'calories': 350.0, 'protein': 15.0, 'carbs': 18.0, 'fat': 25.0},
      {'food_name': 'Apple (medium)', 'calories': 95.0, 'protein': 0.5, 'carbs': 25.0, 'fat': 0.3},
      {'food_name': 'Banana (medium)', 'calories': 105.0, 'protein': 1.3, 'carbs': 27.0, 'fat': 0.4},
      {'food_name': 'Oats (1 cup)', 'calories': 166.0, 'protein': 5.9, 'carbs': 28.0, 'fat': 3.6},
      {'food_name': 'Poha (1 cup)', 'calories': 250.0, 'protein': 4.0, 'carbs': 45.0, 'fat': 6.0},
      {'food_name': 'Idli (2 pieces)', 'calories': 130.0, 'protein': 4.0, 'carbs': 26.0, 'fat': 0.5},
      {'food_name': 'Aloo Paratha', 'calories': 300.0, 'protein': 7.0, 'carbs': 45.0, 'fat': 10.0},
      {'food_name': 'Biryani Chicken', 'calories': 290.0, 'protein': 18.0, 'carbs': 35.0, 'fat': 8.0},
      {'food_name': 'Rajma (1 cup)', 'calories': 225.0, 'protein': 15.0, 'carbs': 40.0, 'fat': 1.0},
      {'food_name': 'Samosa (1 piece)', 'calories': 262.0, 'protein': 4.0, 'carbs': 32.0, 'fat': 13.0},
      {'food_name': 'Maggi Noodles (1 pack)', 'calories': 350.0, 'protein': 8.0, 'carbs': 54.0, 'fat': 12.0},
      {'food_name': 'Greek Yogurt (1 cup)', 'calories': 130.0, 'protein': 22.0, 'carbs': 9.0, 'fat': 0.7},
      {'food_name': 'Protein Shake', 'calories': 120.0, 'protein': 24.0, 'carbs': 3.0, 'fat': 1.5},
      {'food_name': 'Almonds (28g)', 'calories': 164.0, 'protein': 6.0, 'carbs': 6.0, 'fat': 14.0},
      {'food_name': 'Masala Chai (1 cup)', 'calories': 60.0, 'protein': 2.0, 'carbs': 8.0, 'fat': 2.0},
    ];

    final q = query.toLowerCase();
    return foods
        .where((f) => f['food_name'].toString().toLowerCase().contains(q))
        .toList();
  }
}

final fatSecretService = FatSecretService();