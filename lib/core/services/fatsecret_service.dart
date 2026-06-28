import 'dart:convert';
import 'package:dio/dio.dart';

class FatSecretService {
  static const String _clientId = '0ef5041a77234d7c902e3a8dfff68d9b';
  static const String _clientSecret = '9d88939f38ac4a628298666e33c771e8';
  static const String _baseUrl = 'https://platform.fatsecret.com/rest/server.api';
  static const String _authUrl = 'https://oauth.fatsecret.com/connect/token';

  final Dio _dio = Dio();
  String? _accessToken;
  DateTime? _tokenExpiry;

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

    print('📦 Search response: ${response.data}');

    final foods = response.data['foods']?['food'];
    if (foods == null) return [];

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
}

final fatSecretService = FatSecretService();