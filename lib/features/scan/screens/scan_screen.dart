import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

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
      // TODO: Replace with actual FatSecret Image Recognition API
      // when your mentor gives you the Client ID and Secret
      // For now using placeholder response

      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      // Placeholder result — replace with real API response later
      setState(() {
        _scanResult = {
          'food_name': 'Mixed Meal (Demo)',
          'calories': 450.0,
          'protein': 25.0,
          'carbs': 55.0,
          'fat': 15.0,
          'items': [
            {'name': 'Rice', 'calories': 200},
            {'name': 'Chicken', 'calories': 165},
            {'name': 'Vegetables', 'calories': 85},
          ],
        };
      });

      /* REAL API CALL — uncomment when you have FatSecret credentials:

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final dio = Dio();
      final response = await dio.post(
        'https://platform.fatsecret.com/rest/image-recognition/v1',
        options: Options(headers: {
          'Authorization': 'Bearer YOUR_ACCESS_TOKEN',
          'Content-Type': 'application/json',
        }),
        data: {
          'image_b64': base64Image,
          'include_food_data': true,
        },
      );

      setState(() => _scanResult = response.data);
      */
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
        'food_name': _scanResult!['food_name'],
        'calories': _scanResult!['calories'],
        'protein': _scanResult!['protein'],
        'carbs': _scanResult!['carbs'],
        'fat': _scanResult!['fat'],
        'meal_type': _selectedMealType,
        'logged_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal logged successfully!'),
            backgroundColor: Color(0xFF4CAF50),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Scan Food'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview or placeholder
            GestureDetector(
              onTap: () => _showImageSourceSheet(),
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 48,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tap to take a photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'or upload from gallery',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Camera / Gallery buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4CAF50)),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing your meal...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'AI is detecting food items',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),

            // Scan result
            if (_scanResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF4CAF50)),
                        const SizedBox(width: 8),
                        const Text(
                          'Food Detected!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      _scanResult!['food_name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nutrition grid
                    Row(
                      children: [
                        _NutritionTile(
                          label: 'Calories',
                          value:
                          '${(_scanResult!['calories'] as double).toInt()}',
                          unit: 'kcal',
                          color: const Color(0xFF4CAF50),
                        ),
                        _NutritionTile(
                          label: 'Protein',
                          value: '${_scanResult!['protein']}',
                          unit: 'g',
                          color: const Color(0xFFE53935),
                        ),
                        _NutritionTile(
                          label: 'Carbs',
                          value: '${_scanResult!['carbs']}',
                          unit: 'g',
                          color: const Color(0xFFFB8C00),
                        ),
                        _NutritionTile(
                          label: 'Fat',
                          value: '${_scanResult!['fat']}',
                          unit: 'g',
                          color: const Color(0xFF8E24AA),
                        ),
                      ],
                    ),

                    // Detected items
                    if (_scanResult!['items'] != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Detected Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(_scanResult!['items'] as List).map(
                            (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record,
                                      size: 8, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(item['name']),
                                ],
                              ),
                              Text(
                                '${item['calories']} kcal',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Meal type selector
              const Text(
                'Add to meal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
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
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4CAF50)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Text(
                          meal[0].toUpperCase() + meal.substring(1),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Log button
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
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Scan Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.camera_alt, color: Color(0xFF4CAF50)),
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child:
                Icon(Icons.photo_library, color: Color(0xFF2196F3)),
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

class _NutritionTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _NutritionTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}