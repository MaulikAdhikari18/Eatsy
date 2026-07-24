import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Replaces FatSecret as the backend for food search and barcode
/// lookup. Open Food Facts needs no API key, no OAuth token, and — the
/// actual reason for this swap — no IP whitelisting, so calls can be
/// made directly from the Flutter app. No Supabase Edge Function proxy
/// is needed for these two features anymore (unlike FatSecret, which
/// required one to keep its OAuth client secret off the client and to
/// obtain a server-side access token).
///
/// Photo-based food recognition (`recognizeFood`) is deliberately left
/// as a stub, same as before — that's being handled separately via
/// FatSecret Premier, not part of this swap.
///
/// Open Food Facts asks every client to send a descriptive User-Agent
/// identifying the app (see their API docs) so real usage doesn't get
/// mistaken for bot traffic and rate-limited. Update the contact info
/// below if it changes.
class FoodDataService {
  final Dio _dio = Dio();

  static const String _baseUrl = 'https://world.openfoodfacts.org';
  static const String _userAgent =
      'Eatsy-Flutter-App/1.0 (https://github.com/MaulikAdhikari18/Eatsy)';

  Options get _options => Options(
    headers: {'User-Agent': _userAgent},
    validateStatus: (status) => true,
  );

  /// Full-text search by food name (e.g. "chicken breast").
  ///
  /// Uses the legacy /cgi/search.pl endpoint on purpose: Open Food
  /// Facts' current v2/v3 REST API only supports *structured* search
  /// (by category/brand/nutrient tags), not free-text keyword search —
  /// their own docs say as much. Their newer Search-a-licious service
  /// (search.openfoodfacts.org) is meant to eventually replace this,
  /// but as of writing this is the endpoint that's actually documented
  /// and confirmed working for plain keyword search like FatSecret's
  /// foods.search did.
  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _dio.get(
        '$_baseUrl/cgi/search.pl',
        queryParameters: {
          'search_terms': query,
          'search_simple': 1,
          'action': 'process',
          'json': 1,
          'page_size': 20,
          'lc': 'en',
          'fields': 'product_name,product_name_en,nutriments,serving_size,brands',
        },
        options: _options,
      );

      final products = response.data['products'] as List?;
      if (products == null || products.isEmpty) return _localSearch(query);

      final q = query.toLowerCase();
      final results = products
      // requireEnglishName: true — search has many candidate
      // products, so it can afford to just skip any that don't
      // have an English name entered yet rather than show one in
      // Spanish/French/etc.
          .map((p) => _mapProduct(p as Map<String, dynamic>, requireEnglishName: true))
          .whereType<Map<String, dynamic>>()
      // The legacy search endpoint does loose/fuzzy matching, not
      // real relevance ranking — it can return products that don't
      // actually contain the search term at all (e.g. "salmon"
      // matching Spanish products containing "sal", the word for
      // salt, as a substring). Enforcing a real match on the
      // (now English) product name client-side is the only
      // reliable way to keep results actually relevant.
          .where((f) => f['food_name'].toString().toLowerCase().contains(q))
          .toList();

      return results.isEmpty ? _localSearch(query) : results;
    } catch (e) {
      debugPrint('❌ Open Food Facts search error: $e');
      return _localSearch(query);
    }
  }

  /// Barcode lookup — one call returns full product + nutrition data,
  /// unlike FatSecret's two-step find-id-then-get-details flow, so
  /// there's no separate "get by id" step needed here anymore.
  Future<Map<String, dynamic>?> getFoodByBarcode(String barcode) async {
    // Check local DB first for common Indian products — kept exactly
    // as before, since Open Food Facts' regional coverage outside
    // Europe/US is inconsistent and this was already covering a real gap.
    final local = _localBarcodeSearch(barcode);
    if (local != null) return local;

    try {
      final response = await _dio.get(
        '$_baseUrl/api/v2/product/$barcode.json',
        queryParameters: {
          'fields': 'product_name,product_name_en,nutriments,serving_size,brands',
          'lc': 'en',
        },
        options: _options,
      );

      // status == 1 means "product found"; anything else (usually 0)
      // means the barcode isn't in the database.
      if (response.data['status'] != 1) return null;

      return _mapProduct(response.data['product'] as Map<String, dynamic>,
          requireEnglishName: false);
    } catch (e) {
      debugPrint('❌ Barcode error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> recognizeFood(dynamic imageFile) async {
    return null; // Requires FatSecret Premier — handled separately.
  }

  /// Maps an Open Food Facts product object to Eatsy's existing
  /// internal shape ({food_name, calories, protein, carbs, fat}) so
  /// nothing downstream (food_log_screen, scan_screen, barcode_screen)
  /// needs to change how it reads a result.
  ///
  /// Name resolution: Open Food Facts stores a generic `product_name`
  /// (whatever language the contributor typed it in) alongside
  /// optional per-language fields like `product_name_en`. This always
  /// prefers the English field when present.
  /// - requireEnglishName: true (search) — if there's no English name,
  ///   the product is dropped entirely. Search has many candidates, so
  ///   skipping an untranslated one just means a different result takes
  ///   its place instead of showing Spanish/French/etc.
  /// - requireEnglishName: false (barcode) — falls back to the generic
  ///   name if no English one exists, since a barcode scan has exactly
  ///   one product and no alternative to substitute; showing *a* name
  ///   is better than showing nothing for a product that's otherwise a
  ///   perfectly valid, confirmed match.
  ///
  /// Nutrient data is fundamentally "per 100g" unless a product also
  /// has a known serving_size *and* matching _serving nutrient fields.
  /// Rather than guess a serving conversion that could be silently
  /// wrong, this prefers real per-serving data when Open Food Facts
  /// actually has it, and otherwise falls back to per-100g with
  /// "(per 100g)" appended to the name — so what quantity the numbers
  /// refer to is never ambiguous to whoever's logging it.
  Map<String, dynamic>? _mapProduct(
      Map<String, dynamic> product, {
        required bool requireEnglishName,
      }) {
    final nutriments = product['nutriments'] as Map<String, dynamic>?;
    if (nutriments == null) return null;

    final englishName = product['product_name_en']?.toString();
    final genericName = product['product_name']?.toString();

    String? name;
    if (englishName != null && englishName.isNotEmpty) {
      name = englishName;
    } else if (!requireEnglishName &&
        genericName != null &&
        genericName.isNotEmpty) {
      name = genericName;
    }
    if (name == null) return null;

    final hasServingData = product['serving_size'] != null &&
        nutriments['energy-kcal_serving'] != null;

    final suffix = hasServingData ? '' : ' (per 100g)';
    final calKey = hasServingData ? 'energy-kcal_serving' : 'energy-kcal_100g';
    final proteinKey = hasServingData ? 'proteins_serving' : 'proteins_100g';
    final carbsKey =
    hasServingData ? 'carbohydrates_serving' : 'carbohydrates_100g';
    final fatKey = hasServingData ? 'fat_serving' : 'fat_100g';

    final calories = _toDouble(nutriments[calKey]);
    // No usable calorie figure at all — treat as not found rather than
    // showing a fake "0 kcal" entry.
    if (calories == null) return null;

    // How many grams the values above actually represent — needed so
    // the serving/quantity picker's Measure selector (grams, cup,
    // tablespoon, etc.) can convert accurately instead of guessing.
    // Per-100g path is exact by definition; per-serving path depends on
    // Open Food Facts' free-text serving_size ("30 g", "1 bar (40g)")
    // actually containing a parseable gram figure, which isn't
    // guaranteed — null here means the picker falls back to treating
    // quantity as a plain multiplier with no unit conversion.
    final baseGrams = hasServingData
        ? _parseGrams(product['serving_size']?.toString())
        : 100.0;

    return {
      'food_name': '$name$suffix',
      'calories': calories,
      'protein': _toDouble(nutriments[proteinKey]) ?? 0,
      'carbs': _toDouble(nutriments[carbsKey]) ?? 0,
      'fat': _toDouble(nutriments[fatKey]) ?? 0,
      'base_grams': baseGrams,
    };
  }

  /// Pulls a gram figure out of Open Food Facts' free-text serving_size
  /// field. Tries an anchored match first ("30 g", "30g" at the very
  /// start), then falls back to finding a `"<number> g"` pattern anywhere
  /// in the string (e.g. "1 bar (40 g)"). Returns null, not a guess,
  /// when nothing matches — a wrong silent guess here would be worse
  /// than the picker's honest "no unit conversion available" fallback.
  double? _parseGrams(String? servingSize) {
    if (servingSize == null || servingSize.isEmpty) return null;
    final anchored = RegExp(r'^([\d.]+)\s*g\b', caseSensitive: false);
    final anywhere = RegExp(r'([\d.]+)\s*g\b', caseSensitive: false);
    final match =
        anchored.firstMatch(servingSize) ?? anywhere.firstMatch(servingSize);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  // Local barcode database — unchanged from the FatSecret version,
  // except each entry now also carries an estimated base_grams so the
  // Measure picker works consistently here too, not just on Open Food
  // Facts results. These are common-knowledge/typical-pack-size
  // approximations, not measured values — same honesty caveat as the
  // Measure unit conversion table itself.
  Map<String, dynamic>? _localBarcodeSearch(String barcode) {
    final barcodes = {
      '8901058000512': {'food_name': 'Maggi 2-Minute Noodles', 'calories': 350.0, 'protein': 8.0, 'carbs': 54.0, 'fat': 12.0, 'base_grams': 70.0},
      '8901058852398': {'food_name': 'Maggi 2-Minute Noodles', 'calories': 350.0, 'protein': 8.0, 'carbs': 54.0, 'fat': 12.0, 'base_grams': 70.0},
      '8901719110719': {'food_name': 'Parle-G Biscuits (100g)', 'calories': 451.0, 'protein': 7.0, 'carbs': 72.0, 'fat': 15.0, 'base_grams': 100.0},
      '8901063018496': {'food_name': 'Amul Butter (100g)', 'calories': 720.0, 'protein': 0.5, 'carbs': 0.5, 'fat': 80.0, 'base_grams': 100.0},
      '8901237100031': {'food_name': 'Cadbury Dairy Milk (45g)', 'calories': 240.0, 'protein': 3.5, 'carbs': 28.0, 'fat': 13.0, 'base_grams': 45.0},
      '7622210449283': {'food_name': 'Cadbury Dairy Milk (45g)', 'calories': 240.0, 'protein': 3.5, 'carbs': 28.0, 'fat': 13.0, 'base_grams': 45.0},
      '8901725125521': {'food_name': 'Sunfeast Yippee Noodles', 'calories': 310.0, 'protein': 7.0, 'carbs': 48.0, 'fat': 10.0, 'base_grams': 75.0},
      '8906002780016': {'food_name': 'Haldiram Aloo Bhujia', 'calories': 536.0, 'protein': 10.0, 'carbs': 52.0, 'fat': 32.0, 'base_grams': 100.0},
      '5449000000996': {'food_name': 'Coca Cola (330ml)', 'calories': 139.0, 'protein': 0.0, 'carbs': 35.0, 'fat': 0.0, 'base_grams': 330.0},
      '8901063900139': {'food_name': 'Britannia Marie Gold', 'calories': 423.0, 'protein': 8.0, 'carbs': 75.0, 'fat': 9.0, 'base_grams': 100.0},
    };
    return barcodes[barcode];
  }

  // Local food search fallback — same base_grams caveat as above.
  List<Map<String, dynamic>> _localSearch(String query) {
    final foods = [
      {'food_name': 'Chicken Breast (100g)', 'calories': 165.0, 'protein': 31.0, 'carbs': 0.0, 'fat': 3.6, 'base_grams': 100.0},
      {'food_name': 'Chicken Curry', 'calories': 150.0, 'protein': 12.0, 'carbs': 8.0, 'fat': 8.0, 'base_grams': 200.0},
      {'food_name': 'Boiled Egg', 'calories': 78.0, 'protein': 6.0, 'carbs': 0.6, 'fat': 5.0, 'base_grams': 50.0},
      {'food_name': 'White Rice (1 cup)', 'calories': 206.0, 'protein': 4.3, 'carbs': 44.5, 'fat': 0.4, 'base_grams': 158.0},
      {'food_name': 'Roti / Chapati', 'calories': 104.0, 'protein': 3.1, 'carbs': 18.0, 'fat': 2.5, 'base_grams': 40.0},
      {'food_name': 'Dal (1 cup)', 'calories': 230.0, 'protein': 18.0, 'carbs': 40.0, 'fat': 1.0, 'base_grams': 198.0},
      {'food_name': 'Dal Makhani', 'calories': 320.0, 'protein': 14.0, 'carbs': 38.0, 'fat': 12.0, 'base_grams': 200.0},
      {'food_name': 'Paneer (100g)', 'calories': 265.0, 'protein': 18.0, 'carbs': 3.4, 'fat': 20.0, 'base_grams': 100.0},
      {'food_name': 'Paneer Butter Masala', 'calories': 350.0, 'protein': 15.0, 'carbs': 18.0, 'fat': 25.0, 'base_grams': 200.0},
      {'food_name': 'Apple (medium)', 'calories': 95.0, 'protein': 0.5, 'carbs': 25.0, 'fat': 0.3, 'base_grams': 182.0},
      {'food_name': 'Banana (medium)', 'calories': 105.0, 'protein': 1.3, 'carbs': 27.0, 'fat': 0.4, 'base_grams': 118.0},
      {'food_name': 'Oats (1 cup)', 'calories': 166.0, 'protein': 5.9, 'carbs': 28.0, 'fat': 3.6, 'base_grams': 80.0},
      {'food_name': 'Poha (1 cup)', 'calories': 250.0, 'protein': 4.0, 'carbs': 45.0, 'fat': 6.0, 'base_grams': 150.0},
      {'food_name': 'Idli (2 pieces)', 'calories': 130.0, 'protein': 4.0, 'carbs': 26.0, 'fat': 0.5, 'base_grams': 120.0},
      {'food_name': 'Aloo Paratha', 'calories': 300.0, 'protein': 7.0, 'carbs': 45.0, 'fat': 10.0, 'base_grams': 90.0},
      {'food_name': 'Biryani Chicken', 'calories': 290.0, 'protein': 18.0, 'carbs': 35.0, 'fat': 8.0, 'base_grams': 250.0},
      {'food_name': 'Rajma (1 cup)', 'calories': 225.0, 'protein': 15.0, 'carbs': 40.0, 'fat': 1.0, 'base_grams': 177.0},
      {'food_name': 'Samosa (1 piece)', 'calories': 262.0, 'protein': 4.0, 'carbs': 32.0, 'fat': 13.0, 'base_grams': 50.0},
      {'food_name': 'Maggi Noodles (1 pack)', 'calories': 350.0, 'protein': 8.0, 'carbs': 54.0, 'fat': 12.0, 'base_grams': 70.0},
      {'food_name': 'Greek Yogurt (1 cup)', 'calories': 130.0, 'protein': 22.0, 'carbs': 9.0, 'fat': 0.7, 'base_grams': 245.0},
      {'food_name': 'Protein Shake', 'calories': 120.0, 'protein': 24.0, 'carbs': 3.0, 'fat': 1.5, 'base_grams': 300.0},
      {'food_name': 'Almonds (28g)', 'calories': 164.0, 'protein': 6.0, 'carbs': 6.0, 'fat': 14.0, 'base_grams': 28.0},
      {'food_name': 'Masala Chai (1 cup)', 'calories': 60.0, 'protein': 2.0, 'carbs': 8.0, 'fat': 2.0, 'base_grams': 240.0},
    ];

    final q = query.toLowerCase();
    return foods
        .where((f) => f['food_name'].toString().toLowerCase().contains(q))
        .toList();
  }
}

final foodDataService = FoodDataService();