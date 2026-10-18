import 'package:url_launcher/url_launcher.dart';

/// Public legal documents served from the Qallariy websites stack
/// (`<private-ops-repo>/samay/`). These URLs are also the ones registered in the
/// App Store / Play Store listings, so they must stay available.
class LegalLinks {
  const LegalLinks._();

  static const String privacyUrl = 'https://samay.qallariy.lat/privacy.html';
  static const String termsUrl = 'https://samay.qallariy.lat/terms.html';
  static const String supportUrl = 'https://samay.qallariy.lat/support.html';

  /// Opens [url] in the system browser. Returns false when no handler is
  /// available (the caller surfaces a generic error).
  static Future<bool> open(String url) {
    return launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
}
