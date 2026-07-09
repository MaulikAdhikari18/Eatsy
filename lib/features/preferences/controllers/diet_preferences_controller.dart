import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/diet_preferences.dart';

/// Loads the current user's diet preferences. Returns null if the user
/// hasn't set any preferences yet (first-time flow).
final dietPreferencesProvider =
FutureProvider.autoDispose<DietPreferences?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final row = await supabase
      .from('user_preferences')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  if (row == null) return null;
  return DietPreferences.fromMap(row);
});

class DietPreferencesController extends StateNotifier<AsyncValue<void>> {
  DietPreferencesController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> save(DietPreferences prefs) async {
    state = const AsyncValue.loading();
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in');

      await supabase
          .from('user_preferences')
          .upsert(prefs.toMap(userId), onConflict: 'user_id');

      state = const AsyncValue.data(null);
      _ref.invalidate(dietPreferencesProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final dietPreferencesControllerProvider = StateNotifierProvider<
    DietPreferencesController, AsyncValue<void>>((ref) {
  return DietPreferencesController(ref);
});