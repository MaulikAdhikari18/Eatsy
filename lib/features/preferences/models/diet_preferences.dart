import '../../../core/utils/day_boundary.dart';

/// A user's dietary profile — cuisine preferences, allergies, diet type,
/// and known medical conditions. Used to personalize AI-generated meal
/// plans (see Section 4 of the implementation guide).
class DietPreferences {
  final List<String> cuisines;
  final List<String> allergies;
  final String dietType;
  final List<String> medicalConditions;

  const DietPreferences({
    this.cuisines = const [],
    this.allergies = const [],
    this.dietType = 'no_restriction',
    this.medicalConditions = const [],
  });

  factory DietPreferences.fromMap(Map<String, dynamic> map) {
    return DietPreferences(
      cuisines: List<String>.from(map['cuisine_preference'] ?? const []),
      allergies: List<String>.from(map['allergies'] ?? const []),
      dietType: map['diet_type']?.toString() ?? 'no_restriction',
      medicalConditions:
      List<String>.from(map['medical_conditions'] ?? const []),
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'cuisine_preference': cuisines,
      'allergies': allergies,
      'diet_type': dietType,
      'medical_conditions': medicalConditions,
      'updated_at': DayBoundary.nowUtcIso(),
    };
  }

  DietPreferences copyWith({
    List<String>? cuisines,
    List<String>? allergies,
    String? dietType,
    List<String>? medicalConditions,
  }) {
    return DietPreferences(
      cuisines: cuisines ?? this.cuisines,
      allergies: allergies ?? this.allergies,
      dietType: dietType ?? this.dietType,
      medicalConditions: medicalConditions ?? this.medicalConditions,
    );
  }

  /// True if the user hasn't set any real preferences yet —
  /// used to prompt them to fill this in before generating a meal plan.
  bool get isEmpty =>
      cuisines.isEmpty && dietType == 'no_restriction' &&
          allergies.isEmpty && medicalConditions.isEmpty;
}

/// Static option lists sourced from the implementation guide (Section 4.2).
class DietPreferenceOptions {
  static const cuisines = [
    'Indian',
    'Chinese',
    'Malaysian',
    'Mexican',
    'Middle Eastern',
    'Western',
    'Japanese',
    'Vietnamese',
  ];

  static const allergies = [
    'Gluten',
    'Lactose',
    'Nuts',
    'Shellfish',
    'Soy',
  ];

  static const dietTypes = [
    {'key': 'no_restriction', 'label': 'No Restriction'},
    {'key': 'vegetarian', 'label': 'Vegetarian'},
    {'key': 'vegan', 'label': 'Vegan'},
    {'key': 'halal', 'label': 'Halal'},
    {'key': 'kosher', 'label': 'Kosher'},
    {'key': 'keto', 'label': 'Keto'},
    {'key': 'intermittent_fasting', 'label': 'Intermittent Fasting'},
  ];

  static const medicalConditions = [
    'Diabetes',
    'Hypertension',
    'High Cholesterol',
    'Thyroid',
    'PCOS',
  ];
}