import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Replaces FatSecret as the backend for food search and barcode
/// lookup. Open Food Facts needs no API key, no OAuth token, and — the
/// actual reason for this swap — no IP whitelisting, so calls can be
/// made directly from the Flutter app. No Supabase Edge Function proxy
/// is needed for Open Food Facts specifically (unlike FatSecret, which
/// required one to keep its OAuth client secret off the client and to
/// obtain a server-side access token).
///
/// Search is two-tier: Open Food Facts first, USDA FoodData Central
/// second, then the hardcoded local list as a final safety net. Open
/// Food Facts is a barcode/packaged-product database — it has strong
/// coverage for branded, scannable items but essentially none for
/// generic home-cooked dishes ("omelette," "fried rice") since those
/// have no barcode for anyone to have scanned. USDA FDC's Survey
/// (FNDDS) data specifically covers foods *as eaten* — composite,
/// prepared dishes — which is exactly the gap Open Food Facts leaves.
/// USDA calls go through the usda-proxy Edge Function rather than
/// directly from the client, the same reasoning as groq-proxy: keep
/// the API key server-side rather than shipped inside the compiled
/// app, even though this specific key is free and only rate-limits
/// rather than bills.
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
  static const String _usdaProxyUrl =
      'https://ghobobiocpjfiwcrrfbr.supabase.co/functions/v1/usda-proxy';

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
  ///
  /// Open Food Facts caps search specifically at 10 requests/minute per
  /// IP and explicitly warns against using it for search-as-you-type —
  /// _onSearchChanged's 500ms debounce (food_log_screen.dart) helps,
  /// but an active back-and-forth search session can still burn through
  /// that budget. _searchCache below exists specifically to avoid
  /// re-hitting the network for a query already fetched this session.
  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (query.isEmpty) return [];
    final cacheKey = query.trim().toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    List<Map<String, dynamic>> results = [];

    try {
      final response = await _dio.get(
        '$_baseUrl/cgi/search.pl',
        queryParameters: {
          'search_terms': query,
          'search_simple': 1,
          'action': 'process',
          'json': 1,
          'page_size': 50,
          'lc': 'en',
          'fields': 'product_name,product_name_en,nutriments,serving_size,brands',
        },
        options: _options,
      );

      final products = response.data['products'] as List?;
      if (products != null && products.isNotEmpty) {
        final q = query.toLowerCase();
        results = products
            .map((p) => _mapProduct(p as Map<String, dynamic>))
            .whereType<Map<String, dynamic>>()
        // The legacy search endpoint does loose/fuzzy matching, not
        // real relevance ranking — it can return products that don't
        // actually contain the search term at all (e.g. "salmon"
        // matching Spanish products containing "sal", the word for
        // salt, as a substring). Enforcing a real match on the
        // resolved display name client-side is the only reliable way
        // to keep results actually relevant. Matching against
        // whichever name _mapProduct actually resolved to (English if
        // available, otherwise the original) rather than requiring the
        // English name specifically — a non-English product whose
        // original name matches the query is still a real, relevant
        // result and shouldn't be discarded just for lacking an
        // English translation, which Open Food Facts' contributor
        // coverage is inconsistent about outside a few markets.
            .where((f) => f['food_name'].toString().toLowerCase().contains(q))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Open Food Facts search error: $e');
    }

    // Open Food Facts is a packaged-product database — it has close to
    // zero coverage of generic home-cooked dishes ("omelette," "fried
    // rice") since those were never scanned off any packaging. USDA's
    // Survey (FNDDS) data specifically covers foods *as eaten*, which
    // is exactly that gap. Only tried when OFF came back empty, to
    // avoid burning an extra request (and USDA's own rate limit) on
    // every search when OFF already had a good answer.
    if (results.isEmpty) {
      try {
        results = await _searchUsda(query);
      } catch (e) {
        debugPrint('❌ USDA search error: $e');
      }
    }

    if (results.isEmpty) return _localSearch(query);

    // Only successful, real network results are cached — a query that
    // failed everywhere (network error, both APIs rate-limited) is
    // deliberately left uncached so a later retry this same session can
    // still succeed once whatever caused the failure clears, rather
    // than being permanently stuck on the local fallback for the rest
    // of the session.
    _searchCache[cacheKey] = results;
    return results;
  }

  /// Calls USDA FoodData Central through the usda-proxy Edge Function
  /// — see the class doc comment for why this goes through a proxy
  /// rather than hitting USDA directly the way Open Food Facts calls
  /// do. Returns [] (never throws past this point) on any failure, so
  /// callers can treat "USDA had nothing" and "USDA errored" the same
  /// way: fall through to the local list.
  Future<List<Map<String, dynamic>>> _searchUsda(String query) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return [];

    final response = await _dio.post(
      _usdaProxyUrl,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        validateStatus: (status) => true,
      ),
      data: {'query': query},
    );

    if (response.statusCode != 200) return [];

    final foods = response.data['foods'] as List?;
    if (foods == null || foods.isEmpty) return [];

    final q = query.toLowerCase();
    return foods
        .map((f) => _mapUsdaFood(f as Map<String, dynamic>))
        .whereType<Map<String, dynamic>>()
        .where((f) => f['food_name'].toString().toLowerCase().contains(q))
        .toList();
  }

  // USDA's legacy nutrient numbers (stable since long before FoodData
  // Central existed — this is the original USDA Standard Reference
  // numbering, not something that changes between API versions).
  // Deliberately using nutrientNumber (a string like "208"), not
  // nutrientId — the /foods/search endpoint's inline foodNutrients
  // entries use a genuinely different, flatter shape than the
  // /food/{fdcId} detail endpoint's nested one (confirmed against a
  // real example response; this inconsistency is USDA's own, not a
  // guess), and nutrientNumber is the field that shape actually has.
  static const _usdaEnergyNumber = '208';
  static const _usdaProteinNumber = '203';
  static const _usdaFatNumber = '204';
  static const _usdaCarbsNumber = '205';

  /// Maps one entry from USDA's /foods/search response to Eatsy's
  /// internal shape. All USDA foodNutrients values are per 100g
  /// regardless of data type (Foundation/SR Legacy/Survey), so results
  /// get the same "(per 100g)" honesty suffix Open Food Facts' per-100g
  /// fallback path already uses — never claiming a serving-size
  /// quantity USDA didn't actually provide.
  Map<String, dynamic>? _mapUsdaFood(Map<String, dynamic> food) {
    final name = food['description']?.toString();
    if (name == null || name.isEmpty) return null;

    final nutrients = food['foodNutrients'] as List?;
    if (nutrients == null) return null;

    double? findNutrient(String number) {
      for (final n in nutrients) {
        final entry = n as Map<String, dynamic>;
        if (entry['nutrientNumber']?.toString() == number) {
          final value = entry['value'];
          return value is num ? value.toDouble() : null;
        }
      }
      return null;
    }

    final calories = findNutrient(_usdaEnergyNumber);
    // No usable calorie figure — same principle as _mapProduct: treat
    // as not found rather than showing a fake 0, which would look like
    // a real "this food has zero calories" answer.
    if (calories == null) return null;

    return {
      'food_name': '$name (per 100g)',
      'calories': calories,
      'protein': findNutrient(_usdaProteinNumber) ?? 0,
      'carbs': findNutrient(_usdaCarbsNumber) ?? 0,
      'fat': findNutrient(_usdaFatNumber) ?? 0,
      'base_grams': 100.0,
    };
  }

  // Session-only cache (cleared on app restart, since foodDataService
  // is a top-level singleton) — small map objects, no eviction/TTL
  // needed for what this is actually solving (avoiding redundant calls
  // within one active search session against rate limits), not meant
  // to be a long-lived or cross-session cache.
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};

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

      return _mapProduct(response.data['product'] as Map<String, dynamic>);
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
  /// prefers the English field when present, and falls back to the
  /// generic name otherwise — showing *a* real name, even in another
  /// language, is more useful than showing nothing. Search used to drop
  /// non-English-named products entirely on the reasoning that there
  /// were usually enough other English-named candidates to take their
  /// place; in practice, for markets Open Food Facts' contributors
  /// haven't translated as heavily, that discarded real, relevant
  /// results rather than truly-irrelevant ones — the search results
  /// filter below (matching against whichever name actually got
  /// resolved here) still keeps things relevant either way.
  ///
  /// Nutrient data is fundamentally "per 100g" unless a product also
  /// has a known serving_size *and* matching _serving nutrient fields.
  /// Rather than guess a serving conversion that could be silently
  /// wrong, this prefers real per-serving data when Open Food Facts
  /// actually has it, and otherwise falls back to per-100g with
  /// "(per 100g)" appended to the name — so what quantity the numbers
  /// refer to is never ambiguous to whoever's logging it.
  Map<String, dynamic>? _mapProduct(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] as Map<String, dynamic>?;
    if (nutriments == null) return null;

    final englishName = product['product_name_en']?.toString();
    final genericName = product['product_name']?.toString();

    String? name;
    if (englishName != null && englishName.isNotEmpty) {
      name = englishName;
    } else if (genericName != null && genericName.isNotEmpty) {
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
      // Hong Kong / Cantonese — same honesty caveat as the rest of
      // this list: typical-serving approximations, not measured values.
      {'food_name': 'Char Siu Rice (BBQ Pork Rice)', 'calories': 550.0, 'protein': 25.0, 'carbs': 70.0, 'fat': 18.0, 'base_grams': 350.0},
      {'food_name': 'Wonton Noodle Soup', 'calories': 380.0, 'protein': 18.0, 'carbs': 50.0, 'fat': 10.0, 'base_grams': 400.0},
      {'food_name': 'Congee (Plain Rice Porridge)', 'calories': 150.0, 'protein': 3.0, 'carbs': 32.0, 'fat': 0.5, 'base_grams': 300.0},
      {'food_name': 'Hong Kong Milk Tea', 'calories': 120.0, 'protein': 3.0, 'carbs': 18.0, 'fat': 4.0, 'base_grams': 240.0},
      {'food_name': 'Egg Tart (1 piece)', 'calories': 200.0, 'protein': 4.0, 'carbs': 20.0, 'fat': 12.0, 'base_grams': 70.0},
      {'food_name': 'Har Gow / Shrimp Dumplings (4 pieces)', 'calories': 140.0, 'protein': 8.0, 'carbs': 16.0, 'fat': 4.0, 'base_grams': 100.0},
      {'food_name': 'Siu Mai / Pork Dumplings (4 pieces)', 'calories': 180.0, 'protein': 9.0, 'carbs': 12.0, 'fat': 10.0, 'base_grams': 100.0},
      {'food_name': 'Fish Balls (skewer)', 'calories': 150.0, 'protein': 12.0, 'carbs': 10.0, 'fat': 6.0, 'base_grams': 100.0},
      {'food_name': 'Roast Duck Rice', 'calories': 600.0, 'protein': 28.0, 'carbs': 68.0, 'fat': 22.0, 'base_grams': 350.0},
      {'food_name': 'Beef Brisket Noodles', 'calories': 450.0, 'protein': 25.0, 'carbs': 55.0, 'fat': 14.0, 'base_grams': 450.0},
      {'food_name': 'Pineapple Bun (Bo Lo Bao)', 'calories': 340.0, 'protein': 7.0, 'carbs': 45.0, 'fat': 15.0, 'base_grams': 90.0},
      {'food_name': 'Egg Waffle (Gai Daan Jai)', 'calories': 380.0, 'protein': 8.0, 'carbs': 55.0, 'fat': 14.0, 'base_grams': 150.0},
    ];

    final q = query.toLowerCase();
    return foods
        .where((f) => f['food_name'].toString().toLowerCase().contains(q))
        .toList();
  }
}

final foodDataService = FoodDataService();