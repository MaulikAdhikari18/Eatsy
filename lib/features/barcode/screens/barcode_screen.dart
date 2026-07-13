import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/food_data_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/receipt_decorations.dart';
import '../../../shared/widgets/serving_quantity_picker.dart';

// Every color below comes from context.appColors (colors.*), same as
// Dashboard / Scan / Food Log. AppTheme is only imported for AppFonts.mono
// — there is no AppTheme.primary anywhere in this file.

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;
  bool _isLoading = false;
  String _selectedMealType = 'breakfast';

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndScan() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      final result = await cameraController.analyzeImage(image.path);
      if (result != null && result.barcodes.isNotEmpty) {
        final barcode = result.barcodes.first;
        if (barcode.rawValue != null) {
          await _onBarcodeDetected(BarcodeCapture(barcodes: [barcode]));
        } else {
          _showWarningSnack('No barcode found in image. Try another photo.');
        }
      } else {
        _showWarningSnack('No barcode found in image. Try another photo.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning image: $e')),
        );
      }
    }
  }

  void _showWarningSnack(String message) {
    if (!mounted) return;
    final colors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: colors.carbs,
      ),
    );
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isScanned = true);
    final code = barcode!.rawValue!;

    try {
      final food = await foodDataService.getFoodByBarcode(code);
      if (food != null && mounted) {
        _showFoodResult(food);
      } else {
        _showWarningSnack('Product not found in database');
        if (mounted) setState(() => _isScanned = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isScanned = false);
      }
    }
  }

  void _showFoodResult(Map<String, dynamic> food) {
    final colors = context.appColors;
    Map<String, dynamic> scaledFood = Map.from(food);
    String servingSize = '1 serving';
    double quantity = 1.0;

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
                // Handle bar
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

                // Product card — same dark "nutrition facts" header
                // treatment (barcode strip, mono eyebrow, zigzag tear,
                // macro chip footer) as the Scan screen's result card,
                // since this is the same moment — a product just got
                // identified — via a different input method. This
                // stays showing the product's base (1×) values; the
                // picker below is what actually gets logged.
                _ProductResultCard(food: food),

                const SizedBox(height: 20),

                // Serving size / quantity — the adjusted total here,
                // not the card above, is what gets written to
                // food_logs when "Add to Log" is tapped.
                ServingQuantityPicker(
                  baseFood: food,
                  onChanged: (scaled, serving, qty) {
                    scaledFood = scaled;
                    servingSize = serving;
                    quantity = qty;
                  },
                ),

                const SizedBox(height: 20),

                // Meal type selector
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
                      final isSelected = _selectedMealType == meal;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => _selectedMealType = meal),
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

                // Log button — inherits accent fill / accentOnColor text
                // from ElevatedButtonThemeData.
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _logFood(scaledFood, servingSize, quantity),
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: colors.accentOnColor,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Add to Log'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    setState(() => _isScanned = false);
                  },
                  child: const Text('Scan Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => setState(() => _isScanned = false));
  }

  Future<void> _logFood(
      Map<String, dynamic> food, String servingSize, double quantity) async {
    setState(() => _isLoading = true);
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
        'meal_type': _selectedMealType,
        'logged_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        final colors = context.appColors;
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food['food_name']} added!',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: colors.labelCard,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Intentionally kept black regardless of theme — this is a camera
    // viewfinder screen, not a content screen, and a black background
    // is standard/expected UX for scanner overlays in both light and
    // dark mode. Only the accent (viewfinder frame) is theme-aware.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scan Barcode',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white),
            onPressed: _pickImageAndScan,
            tooltip: 'Upload from gallery',
          ),
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => cameraController.toggleTorch(),
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: _onBarcodeDetected,
          ),

          // Overlay
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colors.accent,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Point camera at a barcode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImageAndScan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Upload from Gallery',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors the Scan screen's `_ScanResultCard`: dark label-card header
/// with a decorative barcode strip, mono eyebrow, product name and
/// calorie total, a zigzag torn edge, then a light footer with
/// per-macro mono stats. Keeping this identical to Scan's result card
/// (rather than a bespoke design) is deliberate — barcode and camera
/// scanning are the same "product identified" moment for the user.
class _ProductResultCard extends StatelessWidget {
  final Map<String, dynamic> food;
  const _ProductResultCard({required this.food});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final calories = ((food['calories'] ?? 0) as num).toDouble();

    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Container(
            color: colors.labelCard,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BarcodeStrip(color: colors.accent),
                const SizedBox(height: 12),
                Text(
                  'PRODUCT SCANNED',
                  style: AppFonts.mono(
                    fontSize: 10,
                    color: colors.accent,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  food['food_name']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${calories.toInt()} kcal',
                  style: AppFonts.mono(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        ZigzagEdge(color: colors.labelCard),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.divider),
            borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(
            children: [
              _MacroChip(
                label: 'PROTEIN',
                value: '${((food['protein'] ?? 0) as num).toInt()}g',
                color: colors.protein,
              ),
              _MacroChip(
                label: 'CARBS',
                value: '${((food['carbs'] ?? 0) as num).toInt()}g',
                color: colors.carbs,
              ),
              _MacroChip(
                label: 'FAT',
                value: '${((food['fat'] ?? 0) as num).toInt()}g',
                color: colors.fat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppFonts.mono(
                  fontSize: 9, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value,
              style: AppFonts.mono(
                  fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}