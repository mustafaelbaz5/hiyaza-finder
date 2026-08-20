import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Read-only REST endpoint the app downloads city/holdings data from —
  /// no writes ever go here. Public anon key only; never the service role.
  static const String supabaseUrl = 'https://bbahuyqjptojlighriyy.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJiYWh1eXFqcHRvamxpZ2hyaXl5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU0NzAwMTIsImV4cCI6MjEwMTA0NjAxMn0.iKxHrx9PMHrAnE9wX5RD9i6H2_1g2117yQ04nB54Rtw';

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
