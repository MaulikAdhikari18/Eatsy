import 'dart:convert';
import 'package:dio/dio.dart';
import 'dart:io';
import '../config/app_config.dart';


class FatSecretService {
  static const String _clientId = AppConfig.fatSecretClientId;
  static const String _clientSecret = AppConfig.fatSecretClientSecret;
  static const String _baseUrl = 'https://platform.fatsecret.com/rest/server.api';
  static const String _authUrl = 'https://oauth.fatsecret.com/connect/token';

  final Dio _dio = Dio();
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Local fallback food database
  List<Map<String, dynamic>> _localSearch(String query) {
    final foods = [
      {'food_name': 'Chicken Breast (100g)', 'calories': 165.0, 'protein': 31.0, 'carbs': 0.0, 'fat': 3.6},
      {'food_name': 'Chicken Curry', 'calories': 150.0, 'protein': 12.0, 'carbs': 8.0, 'fat': 8.0},
      {'food_name': 'Boiled Egg', 'calories': 78.0, 'protein': 6.0, 'carbs': 0.6, 'fat': 5.0},
      {'food_name': 'Egg Omelette (2 eggs)', 'calories': 190.0, 'protein': 13.0, 'carbs': 1.0, 'fat': 15.0},
      {'food_name': 'White Rice (1 cup)', 'calories': 206.0, 'protein': 4.3, 'carbs': 44.5, 'fat': 0.4},
      {'food_name': 'Brown Rice (1 cup)', 'calories': 216.0, 'protein': 5.0, 'carbs': 45.0, 'fat': 1.8},
      {'food_name': 'Roti / Chapati (1 piece)', 'calories': 104.0, 'protein': 3.1, 'carbs': 18.0, 'fat': 2.5},
      {'food_name': 'Dal (1 cup)', 'calories': 230.0, 'protein': 18.0, 'carbs': 40.0, 'fat': 1.0},
      {'food_name': 'Dal Makhani (1 cup)', 'calories': 320.0, 'protein': 14.0, 'carbs': 38.0, 'fat': 12.0},
      {'food_name': 'Paneer (100g)', 'calories': 265.0, 'protein': 18.0, 'carbs': 3.4, 'fat': 20.0},
      {'food_name': 'Paneer Butter Masala (1 cup)', 'calories': 350.0, 'protein': 15.0, 'carbs': 18.0, 'fat': 25.0},
      {'food_name': 'Palak Paneer (1 cup)', 'calories': 280.0, 'protein': 14.0, 'carbs': 12.0, 'fat': 18.0},
      {'food_name': 'Whole Milk (1 cup)', 'calories': 149.0, 'protein': 8.0, 'carbs': 12.0, 'fat': 8.0},
      {'food_name': 'Curd / Yogurt (1 cup)', 'calories': 100.0, 'protein': 11.0, 'carbs': 7.0, 'fat': 2.5},
      {'food_name': 'Apple (medium)', 'calories': 95.0, 'protein': 0.5, 'carbs': 25.0, 'fat': 0.3},
      {'food_name': 'Banana (medium)', 'calories': 105.0, 'protein': 1.3, 'carbs': 27.0, 'fat': 0.4},
      {'food_name': 'Orange (medium)', 'calories': 62.0, 'protein': 1.2, 'carbs': 15.4, 'fat': 0.2},
      {'food_name': 'Mango (1 cup)', 'calories': 99.0, 'protein': 1.4, 'carbs': 25.0, 'fat': 0.6},
      {'food_name': 'Watermelon (1 cup)', 'calories': 46.0, 'protein': 0.9, 'carbs': 11.5, 'fat': 0.2},
      {'food_name': 'Grapes (1 cup)', 'calories': 62.0, 'protein': 0.6, 'carbs': 16.0, 'fat': 0.3},
      {'food_name': 'Oats (1 cup cooked)', 'calories': 166.0, 'protein': 5.9, 'carbs': 28.0, 'fat': 3.6},
      {'food_name': 'Poha (1 cup)', 'calories': 250.0, 'protein': 4.0, 'carbs': 45.0, 'fat': 6.0},
      {'food_name': 'Upma (1 cup)', 'calories': 200.0, 'protein': 4.5, 'carbs': 32.0, 'fat': 6.0},
      {'food_name': 'Idli (2 pieces)', 'calories': 130.0, 'protein': 4.0, 'carbs': 26.0, 'fat': 0.5},
      {'food_name': 'Dosa (1 plain)', 'calories': 133.0, 'protein': 3.5, 'carbs': 25.0, 'fat': 2.5},
      {'food_name': 'Sambar (1 cup)', 'calories': 100.0, 'protein': 5.0, 'carbs': 15.0, 'fat': 2.0},
      {'food_name': 'Aloo Paratha (1 piece)', 'calories': 300.0, 'protein': 7.0, 'carbs': 45.0, 'fat': 10.0},
      {'food_name': 'Biryani Chicken (1 cup)', 'calories': 290.0, 'protein': 18.0, 'carbs': 35.0, 'fat': 8.0},
      {'food_name': 'Rajma (1 cup)', 'calories': 225.0, 'protein': 15.0, 'carbs': 40.0, 'fat': 1.0},
      {'food_name': 'Chole (1 cup)', 'calories': 210.0, 'protein': 11.0, 'carbs': 35.0, 'fat': 4.0},
      {'food_name': 'Samosa (1 piece)', 'calories': 262.0, 'protein': 4.0, 'carbs': 32.0, 'fat': 13.0},
      {'food_name': 'Bread White (1 slice)', 'calories': 79.0, 'protein': 2.7, 'carbs': 15.0, 'fat': 1.0},
      {'food_name': 'Bread Brown (1 slice)', 'calories': 69.0, 'protein': 3.6, 'carbs': 11.5, 'fat': 1.1},
      {'food_name': 'Peanut Butter (1 tbsp)', 'calories': 94.0, 'protein': 4.0, 'carbs': 3.1, 'fat': 8.0},
      {'food_name': 'Almonds (28g)', 'calories': 164.0, 'protein': 6.0, 'carbs': 6.0, 'fat': 14.0},
      {'food_name': 'Walnuts (28g)', 'calories': 185.0, 'protein': 4.3, 'carbs': 3.9, 'fat': 18.5},
      {'food_name': 'Protein Shake (1 scoop)', 'calories': 120.0, 'protein': 24.0, 'carbs': 3.0, 'fat': 1.5},
      {'food_name': 'Whey Protein (1 scoop)', 'calories': 130.0, 'protein': 25.0, 'carbs': 4.0, 'fat': 2.0},
      {'food_name': 'Tuna (100g)', 'calories': 116.0, 'protein': 25.5, 'carbs': 0.0, 'fat': 1.0},
      {'food_name': 'Salmon (100g)', 'calories': 208.0, 'protein': 20.0, 'carbs': 0.0, 'fat': 13.0},
      {'food_name': 'Pizza (1 slice)', 'calories': 285.0, 'protein': 12.0, 'carbs': 36.0, 'fat': 10.0},
      {'food_name': 'Burger (1 medium)', 'calories': 354.0, 'protein': 20.0, 'carbs': 29.0, 'fat': 17.0},
      {'food_name': 'French Fries (medium)', 'calories': 365.0, 'protein': 4.0, 'carbs': 48.0, 'fat': 17.0},
      {'food_name': 'Pasta (1 cup cooked)', 'calories': 220.0, 'protein': 8.0, 'carbs': 43.0, 'fat': 1.3},
      {'food_name': 'Sweet Potato (medium)', 'calories': 103.0, 'protein': 2.3, 'carbs': 24.0, 'fat': 0.1},
      {'food_name': 'Broccoli (1 cup)', 'calories': 55.0, 'protein': 3.7, 'carbs': 11.0, 'fat': 0.6},
      {'food_name': 'Spinach (1 cup)', 'calories': 7.0, 'protein': 0.9, 'carbs': 1.1, 'fat': 0.1},
      {'food_name': 'Carrot (medium)', 'calories': 25.0, 'protein': 0.6, 'carbs': 6.0, 'fat': 0.1},
      {'food_name': 'Tomato (medium)', 'calories': 22.0, 'protein': 1.1, 'carbs': 4.8, 'fat': 0.2},
      {'food_name': 'Cucumber (medium)', 'calories': 16.0, 'protein': 0.7, 'carbs': 3.6, 'fat': 0.1},
      {'food_name': 'Avocado (half)', 'calories': 120.0, 'protein': 1.5, 'carbs': 6.4, 'fat': 11.0},
      {'food_name': 'Greek Yogurt (1 cup)', 'calories': 130.0, 'protein': 22.0, 'carbs': 9.0, 'fat': 0.7},
      {'food_name': 'Cottage Cheese (1 cup)', 'calories': 206.0, 'protein': 28.0, 'carbs': 6.0, 'fat': 9.0},
      {'food_name': 'Orange Juice (1 cup)', 'calories': 112.0, 'protein': 1.7, 'carbs': 26.0, 'fat': 0.5},
      {'food_name': 'Tea with Milk (1 cup)', 'calories': 45.0, 'protein': 1.5, 'carbs': 6.0, 'fat': 1.5},
      {'food_name': 'Coffee Black (1 cup)', 'calories': 5.0, 'protein': 0.3, 'carbs': 0.0, 'fat': 0.0},
      {'food_name': 'Masala Chai (1 cup)', 'calories': 60.0, 'protein': 2.0, 'carbs': 8.0, 'fat': 2.0},
    ];

    final q = query.toLowerCase();
    return foods
        .where((f) =>
        f['food_name'].toString().toLowerCase().contains(q))
        .toList();
  }

  Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    print('🔑 Getting FatSecret token...');

    final response = await _dio.post(
      _authUrl,
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
      data: {
        'grant_type': 'client_credentials',
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'scope': 'basic',
      },
    );

    print('✅ Token received!');

    _accessToken = response.data['access_token'];
    _tokenExpiry = DateTime.now()
        .add(Duration(seconds: response.data['expires_in'] - 60));

    return _accessToken!;
  }

  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (query.isEmpty) return [];

    try {
      final token = await _getAccessToken();
      print('🔍 Searching: $query');

      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'method': 'foods.search',
          'search_expression': query,
          'format': 'json',
          'max_results': 10,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => true,
        ),
      );

      print('📦 Response: ${response.data}');

      // If API returns error — use local fallback
      if (response.data['error'] != null) {
        print('⚠️ API error — using local database');
        return _localSearch(query);
      }

      final foods = response.data['foods']?['food'];
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
      print('❌ Error — using local database: $e');
      return _localSearch(query);
    }
  }

  Future<Map<String, dynamic>?> getFoodByBarcode(String barcode) async {
    final token = await _getAccessToken();

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'method': 'food.find_id_for_barcode',
          'barcode': barcode,
          'format': 'json',
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => true,
        ),
      );

      print('📦 Barcode response: ${response.data}');

      final foodId = response.data['food_id']?['value'];
      if (foodId == null) return null;

      return await getFoodById(foodId);
    } catch (e) {
      print('❌ Barcode error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFoodById(String foodId) async {
    final token = await _getAccessToken();

    final response = await _dio.get(
      _baseUrl,
      queryParameters: {
        'method': 'food.get.v4',
        'food_id': foodId,
        'format': 'json',
      },
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        validateStatus: (status) => true,
      ),
    );

    print('📦 Food detail response: ${response.data}');

    final food = response.data['food'];
    if (food == null) return null;

    final serving = food['servings']?['serving'];
    final firstServing = serving is List ? serving[0] : serving;

    return {
      'food_name': food['food_name'],
      'calories':
      double.tryParse(firstServing?['calories']?.toString() ?? '0') ?? 0,
      'protein':
      double.tryParse(firstServing?['protein']?.toString() ?? '0') ?? 0,
      'carbs': double.tryParse(
          firstServing?['carbohydrate']?.toString() ?? '0') ??
          0,
      'fat': double.tryParse(firstServing?['fat']?.toString() ?? '0') ?? 0,
    };
  }

  double _parseNutrient(String description, String nutrient, String unit) {
    try {
      final pattern = '$nutrient: ([0-9.]+)$unit';
      final match = RegExp(pattern).firstMatch(description);
      return double.tryParse(match?.group(1) ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }
  Future<Map<String, dynamic>?> recognizeFood(File imageFile) async {
    final token = await _getAccessToken();

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      print('🔍 Sending image to FatSecret...');

      final response = await _dio.post(
        'https://platform.fatsecret.com/rest/image-recognition/v1',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        ),
        data: {
          'image_b64': base64Image,
          'include_food_data': true,
          'region': 'India',
          'language': 'en',
        },
      );

      print('📦 Image recognition response: ${response.data}');

      if (response.statusCode != 200) {
        print('❌ Error: ${response.data}');
        return null;
      }

      final foodItems = response.data['food_response'];
      if (foodItems == null || foodItems.isEmpty) return null;

      // Build result from top detected food
      final topFood = foodItems[0];
      final serving = topFood['food']?['servings']?['serving'];
      final firstServing = serving is List ? serving[0] : serving;

      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;
      List<Map<String, dynamic>> detectedItems = [];

      for (final item in foodItems) {
        final itemServing = item['food']?['servings']?['serving'];
        final s = itemServing is List ? itemServing[0] : itemServing;
        final cal =
            double.tryParse(s?['calories']?.toString() ?? '0') ?? 0;
        totalCalories += cal;
        totalProtein +=
            double.tryParse(s?['protein']?.toString() ?? '0') ?? 0;
        totalCarbs +=
            double.tryParse(s?['carbohydrate']?.toString() ?? '0') ?? 0;
        totalFat +=
            double.tryParse(s?['fat']?.toString() ?? '0') ?? 0;

        detectedItems.add({
          'name': item['food']?['food_name'] ?? 'Unknown',
          'calories': cal.toInt(),
        });
      }

      return {
        'food_name': foodItems.length == 1
            ? topFood['food']?['food_name'] ?? 'Detected Meal'
            : 'Mixed Meal (${foodItems.length} items)'
        'calories': totalCalories,
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fat': totalFat,
        'items': detectedItems,
      };
    } catch (e) {
      print('❌ Image recognition error: $e');
      return null;
    }
  }
}

final fatSecretService = FatSecretService();