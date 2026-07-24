import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/food_data_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/dotted_leader_row.dart';
import '../../../shared/widgets/receipt_decorations.dart';
import '../../../shared/widgets/serving_quantity_picker.dart';
import '../../../core/utils/day_boundary.dart';

// Every color below comes from context.appColors (colors.*), same as
// the Dashboard and Food Log. AppTheme is only imported for
// AppFonts.mono — there is no AppTheme.primary anywhere in this file.

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _scanResult;
  String _selectedMealType = 'breakfast';
  final ImagePicker _picker = ImagePicker();

  // Set by ServingQuantityPicker's onChanged; starts as the raw
  // detected result until the picker fires its first callback, same
  // pattern as Food Log and Barcode.
  Map<String, dynamic> _scaledResult = {};
  String _servingSize = '1 serving';
  double _quantity = 1.0;

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _scanResult = null;
      });

      await _analyzeImage(_selectedImage!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _analyzeImage(File image) async {
    setState(() => _isAnalyzing = true);
    try {
      final result = await foodDataService.recognizeFood(image);

      if (result != null) {
        setState(() {
          _scanResult = result;
          _scaledResult = Map.from(result);
          _servingSize = '1 serving';
          _quantity = 1.0;
        });
      } else {
        if (mounted) {
          final colors = context.appColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not detect food. Try a clearer photo!',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: colors.carbs,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _logFood() async {
    if (_scanResult == null) return;
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('food_logs').insert({
        'user_id': userId,
        'food_name': _scaledResult['food_name'] ?? _scanResult!['food_name'],
        'calories': _scaledResult['calories'] ?? _scanResult!['calories'],
        'protein': _scaledResult['protein'] ?? _scanResult!['protein'],
        'carbs': _scaledResult['carbs'] ?? _scanResult!['carbs'],
        'fat': _scaledResult['fat'] ?? _scanResult!['fat'],
        'serving_size': _servingSize,
        'quantity': _quantity,
        'meal_type': _selectedMealType,
        'logged_at': DayBoundary.nowUtcIso(),
      });

      if (mounted) {
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meal logged successfully!'),
            backgroundColor: colors.accent,
          ),
        );
        setState(() {
          _selectedImage = null;
          _scanResult = null;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging meal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      // AppBar restored: unlike Meal Plan (tab-only), this screen is
      // ALWAYS reached via Navigator.push — the bottom-nav "Scan" tap and
      // the Dashboard's "Scan" quick action both push it rather than
      // switching tabs. Without an AppBar there's no back button at all.
      // Same bare-title convention as Goals / Diet Preferences / Barcode.
      appBar: AppBar(
        title: const Text('Scan Food'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),

              // Image preview or placeholder
              GestureDetector(
                onTap: () => _showImageSourceSheet(),
                child: Container(
                  width: double.infinity,
                  height: 260,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt,
                            size: 48, color: colors.accent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to take a photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'or upload from gallery',
                        style: TextStyle(fontSize: 13, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Camera / Gallery buttons — inherit border/text color
              // from OutlinedButtonThemeData (already theme-aware).
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Analyzing indicator
              if (_isAnalyzing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: colors.accent),
                      const SizedBox(height: 16),
                      Text(
                        'Analyzing your meal...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI is detecting food items',
                        style: TextStyle(color: colors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              // Scan result — same dark "nutrition facts" card treatment
              // as the Dashboard's hero card: barcode strip, mono
              // calorie total, zigzag tear, macro strip footer.
              if (_scanResult != null) ...[
                _ScanResultCard(result: _scanResult!),

                const SizedBox(height: 20),

                // Serving size / quantity — same picker as Food Log and
                // Barcode. The card above keeps showing the raw detected
                // 1× values; this is what actually gets logged.
                ServingQuantityPicker(
                  baseFood: _scanResult!,
                  onChanged: (scaled, serving, qty) {
                    setState(() {
                      _scaledResult = scaled;
                      _servingSize = serving;
                      _quantity = qty;
                    });
                  },
                ),

                const SizedBox(height: 20),

                Text(
                  'Add to meal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
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
                            horizontal: 20,
                            vertical: 10,
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
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // Log button — inherits accent fill from
                // ElevatedButtonThemeData, same as every other screen.
                ElevatedButton(
                  onPressed: _logFood,
                  child: const Text('Add to Food Log'),
                ),

                const SizedBox(height: 8),

                OutlinedButton(
                  onPressed: () => setState(() {
                    _selectedImage = null;
                    _scanResult = null;
                  }),
                  child: const Text('Scan Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImageSourceSheet() {
    final colors = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.accent.withValues(alpha: 0.15),
                child: Icon(Icons.camera_alt, color: colors.accent),
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.dinner.withValues(alpha: 0.15),
                child: Icon(Icons.photo_library, color: colors.dinner),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors the Dashboard's `_NutritionLabelCard`: dark label-card header
/// with a decorative barcode strip and big mono calorie total, a
/// zigzag torn edge, then a light footer with per-macro mono stats.
/// Detected sub-items (if the model returns them) use the same
/// `DottedLeaderRow` as the Food Log's meal-group cards.
class _ScanResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ScanResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final calories = ((result['calories'] ?? 0) as num).toDouble();
    final items = result['items'] as List?;

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
                  'FOOD DETECTED',
                  style: AppFonts.mono(
                    fontSize: 10,
                    color: colors.accent,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result['food_name']?.toString() ?? '',
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
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // FIX: was `'${result['protein']}g'` etc — if this value
                  // ever comes back as a double (e.g. 15.0 from a real
                  // vision API instead of the current stub), it would
                  // render as "15.0g" instead of "15g". Casting through
                  // num.toInt() first guarantees a clean integer string
                  // regardless of whether the source value is an int or
                  // a double.
                  _MacroChip(
                    label: 'PROTEIN',
                    value: '${((result['protein'] ?? 0) as num).toInt()}g',
                    color: colors.protein,
                  ),
                  _MacroChip(
                    label: 'CARBS',
                    value: '${((result['carbs'] ?? 0) as num).toInt()}g',
                    color: colors.carbs,
                  ),
                  _MacroChip(
                    label: 'FAT',
                    value: '${((result['fat'] ?? 0) as num).toInt()}g',
                    color: colors.fat,
                  ),
                ],
              ),
              if (items != null && items.isNotEmpty) ...[
                Divider(height: 24, color: colors.divider),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: DottedLeaderRow(
                    label: item['name']?.toString() ?? '',
                    value: '${item['calories']}',
                  ),
                )),
              ],
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
  const _MacroChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.mono(fontSize: 9, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value, style: AppFonts.mono(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}