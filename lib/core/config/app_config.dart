import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Read-only REST endpoint the app downloads city/holdings data from —
  /// no writes ever go here. Public anon key only; never the service role.
  static const String supabaseUrl = 'https://YOUR_NEW_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';

  static const bool isDevelopment = kDebugMode;

  // App Info
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'HiyazaFinder Dev',
  );
  static const String appVersion = '1.1.5';
  static const String buildNumber = '14';

  // Developer Info
  static const String developerName = 'Mustafa Elbaz';
  static const String developerEmail = 'm9stafa05@gmail.com';
}
