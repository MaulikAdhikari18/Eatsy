package com.maulik.eatsy.eatsy;

import io.flutter.embedding.android.FlutterFragmentActivity;

// Changed from FlutterActivity to FlutterFragmentActivity — required by
// the health package (see pubspec.yaml) for Android 14's permission
// flow. The package uses registerForActivityResult when requesting
// Health Connect permissions, which needs to cast this Activity to
// ComponentActivity; only FlutterFragmentActivity supports that cast.
// This is the package's own documented requirement, not Eatsy-specific
// custom behavior — see https://pub.dev/packages/health#android-14.
public class MainActivity extends FlutterFragmentActivity {
}