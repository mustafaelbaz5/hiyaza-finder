import 'package:url_launcher/url_launcher.dart';

/// AppLauncher — reusable URL launcher utility
/// ─────────────────────────────────────────────
/// Use this anywhere in the app to open URLs, emails, phone calls.
///
/// Usage:
///   await AppLauncher.openUrl('https://example.com');
///   await AppLauncher.openEmail(to: 'hello@example.com', subject: 'Hi');
///   await AppLauncher.openPhone('+1234567890');

class AppLauncher {
  AppLauncher._();

  /// Opens any URL in external browser
  static Future<bool> openUrl(final String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Opens email client with optional subject and body
  static Future<bool> openEmail({
    required final String to,
    final String subject = '',
    final String body = '',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: [
        if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
        if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
      ].join('&'),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  /// Opens phone dialer
  static Future<bool> openPhone(final String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  /// Opens SMS
  static Future<bool> openSms(final String phone,
      {final String message = ''}) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      query: message.isNotEmpty ? 'body=${Uri.encodeComponent(message)}' : null,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  /// Opens App Store / Play Store
  static Future<bool> openStore({
    required final String androidUrl,
    required final String iosUrl,
    required final bool isIos,
  }) =>
      openUrl(isIos ? iosUrl : androidUrl);
}
