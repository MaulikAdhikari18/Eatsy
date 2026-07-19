import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Single source of truth for Eatsy's legal document URLs. Both pages are
/// static HTML hosted via GitHub Pages from the docs/ folder of this repo
/// (see docs/privacy-policy.html, docs/terms-of-service.html) — these are
/// the same URLs that go into App Store Connect / Google Play Console's
/// privacy policy fields, so if the GitHub Pages source or repo ever
/// moves, this is the one place that needs updating.
class LegalLinks {
  LegalLinks._();

  static const String privacyPolicyUrl =
      'https://maulikadhikari18.github.io/Eatsy/privacy-policy.html';

  static const String termsOfServiceUrl =
      'https://maulikadhikari18.github.io/Eatsy/terms-of-service.html';

  /// Opens [url] in the system browser (not an in-app webview — there's
  /// no webview dependency in this project, and for a one-off legal-doc
  /// read, the system browser is simpler and gives the person their own
  /// browser's find-in-page/zoom/etc. for free).
  ///
  /// Shows a SnackBar instead of throwing if the platform can't handle
  /// the URL at all (e.g. no browser available) — this is a "nice to
  /// have" action, not something that should ever crash a screen.
  static Future<void> open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  static Future<void> openPrivacyPolicy(BuildContext context) =>
      open(context, privacyPolicyUrl);

  static Future<void> openTermsOfService(BuildContext context) =>
      open(context, termsOfServiceUrl);
}