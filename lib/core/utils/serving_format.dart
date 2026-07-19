/// Formats a quantity multiplier for display, stripping *all* trailing
/// zeros (not just one) so whole numbers read as "2" instead of "2.0",
/// while values like "1.5" or "2.25" still show their real precision.
///
/// Previously this exact logic (with a single-zero-strip bug — "2.0"
/// stayed "2.0" instead of becoming "2") was copy-pasted into three
/// places: serving_quantity_picker.dart's quantity display, and once
/// each inside a private `_servingSubtitle()` in food_log_screen.dart
/// and dashboard_screen.dart. One bug, three places to fix. This is
/// the one copy now; all three import it.
String formatQuantity(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// Builds the small "×2 · 1 cup" (or just "×2", or just "1 cup") line
/// shown under a logged food item, from its serving_size/quantity
/// columns. Returns null if the row has neither — e.g. it was logged
/// before this feature existed — so callers can simply omit the
/// subtitle rather than show something like "×null".
///
/// A quantity of exactly 1 isn't called out on its own ("×1" next to
/// every single-serving item would just be noise); it still shows if
/// paired with a real serving_size label, e.g. "1 cup" alone.
String? servingSubtitle(Map<String, dynamic> item) {
  final servingSizeRaw = item['serving_size']?.toString();
  final quantityRaw = item['quantity'];
  final quantity =
  quantityRaw == null ? null : (quantityRaw as num).toDouble();

  final hasServingSize = servingSizeRaw != null && servingSizeRaw.isNotEmpty;
  final hasMeaningfulQuantity = quantity != null && quantity != 1;

  if (!hasServingSize && !hasMeaningfulQuantity) return null;

  final qtyPart = hasMeaningfulQuantity ? '×${formatQuantity(quantity)}' : '';
  final sizePart = hasServingSize ? servingSizeRaw : '';

  if (qtyPart.isNotEmpty && sizePart.isNotEmpty) return '$qtyPart · $sizePart';
  return qtyPart.isNotEmpty ? qtyPart : sizePart;
}