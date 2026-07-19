import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authControllerProvider =
StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController();
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController() : super(const AsyncValue.data(null));

  final _supabase = Supabase.instance.client;

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
        'created_at': DateTime.now().toIso8601String(),
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

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await Future.delayed(const Duration(milliseconds: 200));
  }
}