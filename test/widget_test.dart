// A real smoke test for Eatsy, replacing the default Flutter counter-app
// test that shipped with this project template. The old version pumped
// `MyApp` (a class that has never existed here — this app's root widget
// is `EatsyApp`) and asserted counter-increment behavior that has nothing
// to do with this app, which is why `flutter test`/`flutter analyze` was
// failing outright.
//
// This deliberately does NOT pump `EatsyApp` itself, because EatsyApp's
// widget tree depends on things a plain widget test can't provide without
// substantial setup: an initialized Supabase client (main.dart calls
// Supabase.initialize before runApp), a working SharedPreferences instance
// (read by ThemeModeController and the router's onboarding-check), and a
// live GoRouter configuration. Faking all of that just to satisfy a smoke
// test would make the test brittle and coupled to unrelated bootstrapping
// concerns rather than actually verifying UI behavior.
//
// Instead, this tests LoginScreen directly — the first screen a
// signed-out user sees — since its build() method has no dependency on
// Supabase or SharedPreferences (those are only touched inside async
// button handlers, which this test never triggers). It only needs a
// ProviderScope (LoginScreen is a ConsumerStatefulWidget) and AppTheme
// applied (LoginScreen reads context.appColors, which requires the
// AppColors ThemeExtension to be registered).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eatsy/core/theme/app_theme.dart';
import 'package:eatsy/features/auth/screens/login_screen.dart';

void main() {
  // LoginScreen uses AppFonts.mono(), which wraps GoogleFonts.ibmPlexMono().
  // By default google_fonts tries to fetch font files over the network at
  // runtime if they're not bundled as assets, which makes tests flaky or
  // slow to hang depending on network availability in whatever environment
  // `flutter test` runs in (including CI). Disabling runtime fetching here
  // makes the widget fall back to a system font instead — irrelevant for
  // what this test actually checks (that the right text and controls
  // render), and makes the test reliable regardless of network access.
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'LoginScreen renders the Eatsy brand header and sign-in controls',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      // Brand header
      expect(find.text('EATSY'), findsOneWidget);

      // Core sign-in controls are present
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);

      // Email and password fields
      expect(find.byType(TextField), findsNWidgets(2));
    },
  );
}