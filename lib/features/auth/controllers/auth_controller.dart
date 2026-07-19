import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/day_boundary.dart';

final authControllerProvider =
StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController();
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController() : super(const AsyncValue.data(null));

  final _supabase = Supabase.instance.client;

  // Same proxy pattern as the Groq calls in meal_plan_screen.dart —
  // this one runs the account-deletion Edge Function, which is the
  // only place the service-role key needed to delete an auth user
  // ever exists (see supabase/functions/delete-account/index.ts).
  static const String _deleteAccountUrl =
      'https://ghobobiocpjfiwcrrfbr.supabase.co/functions/v1/delete-account';

  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmail(String email, String password, String fullName) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    // Auto-create profile row
    if (response.user != null) {
      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'full_name': fullName,
        'created_at': DayBoundary.nowUtcIso(),
      });
    }
  }

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(OAuthProvider.google);
  }

  /// Triggers Supabase's built-in "reset password" email. The link in
  /// that email opens the app via `redirectTo` and establishes a
  /// short-lived recovery session — completing the actual reset (i.e.
  /// setting a new password) happens in `updatePasswordAfterReset`
  /// below, on ResetPasswordScreen, once that session exists.
  ///
  /// IMPORTANT — this redirect URL has to match, in two more places,
  /// or the emailed link will fail to open the app at all:
  /// 1. Supabase Dashboard → Authentication → URL Configuration →
  ///    Redirect URLs must have this exact URL added to the allow-list
  ///    (Supabase rejects redirects to anything not explicitly listed).
  /// 2. The app itself needs to actually register as the handler for
  ///    this scheme — an intent-filter in
  ///    android/app/src/main/AndroidManifest.xml, and a URL Type in
  ///    ios/Runner/Info.plist. That's native platform config, not
  ///    something achievable from Dart code alone — flagging it here
  ///    rather than silently assuming it's already done.
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.eatsy.app://reset-password',
    );
  }

  /// Called from ResetPasswordScreen once the person has followed the
  /// emailed link and typed a new password. Relies on supabase_flutter
  /// having already turned that deep link into an active recovery
  /// session (see the AuthChangeEvent.passwordRecovery listener this
  /// needs in main.dart/app_router.dart) — if no such session exists,
  /// this throws, same as any other unauthenticated Supabase call.
  Future<void> updatePasswordAfterReset(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Permanently deletes the signed-in user's account: every row they
  /// own across every app table, plus the login itself. Irreversible —
  /// DeleteAccountScreen is responsible for getting explicit,
  /// unambiguous confirmation before this is ever called.
  ///
  /// This can't be done with a plain `_supabase.from(...).delete()` /
  /// `_supabase.auth` call the way everything else in this file is,
  /// because removing the actual login (`auth.admin.deleteUser`) is an
  /// admin-only operation that requires the service-role key — a key
  /// that must never exist inside the compiled app. So this calls the
  /// delete-account Edge Function instead, which holds that key
  /// server-side and does the deletion on the app's behalf, the same
  /// way meal_plan_screen.dart calls the groq-proxy function rather
  /// than talking to Groq directly.
  ///
  /// On success, signs the (now-deleted) session out locally so the
  /// app's own auth state clears immediately rather than waiting on
  /// the next API call to fail with a stale/invalid session.
  Future<void> deleteAccount() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('Not signed in — please log in again.');
    }

    final dio = Dio();
    final response = await dio.post(
      _deleteAccountUrl,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        validateStatus: (status) => true,
      ),
    );

    if (response.statusCode != 200) {
      final message = response.data is Map
          ? (response.data['error']?.toString() ?? 'Account deletion failed.')
          : 'Account deletion failed.';
      throw Exception(message);
    }

    // The auth user no longer exists server-side at this point — this
    // just clears the local session so the app's UI reflects that
    // immediately instead of surfacing a confusing error on whatever
    // the next authenticated call happens to be.
    await _supabase.auth.signOut();
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await Future.delayed(const Duration(milliseconds: 200));
  }
}