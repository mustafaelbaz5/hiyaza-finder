import '../../../core/config/app_config.dart';

/// AboutConstants — single source of truth for the About screen
/// ─────────────────────────────────────────────────────────────
/// When starting a new project, update AppConfig and these store URLs.
/// Everything else is pulled from AppConfig automatically.

class AboutConstants {
  AboutConstants._();

  // ── Store URLs ──────────────────────────────────────────────
  // TODO: Replace with your actual store URLs before release
  static const String androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.example.app';
  static const String iosStoreUrl = 'https://apps.apple.com/app/id000000000';

  // ── Legal URLs ──────────────────────────────────────────────
  // TODO: Replace with your actual policy URLs
  static const String privacyPolicyUrl = 'https://example.com/privacy';
  static const String termsOfServiceUrl = 'https://example.com/terms';

  // ── Support ─────────────────────────────────────────────────
  static String get bugReportSubject =>
      '[${AppConfig.appName}] Bug Report - V${AppConfig.appVersion}';

  static String get bugReportBody =>
      'App Version: V${AppConfig.appVersion} (${AppConfig.buildNumber})\n'
      'Platform: ${AppConfig.appName}\n\n'
      'Describe the bug:\n';

  static String get contactSubject => '[${AppConfig.appName}] Hello';
}
