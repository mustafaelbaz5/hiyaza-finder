import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Read-only REST endpoint the app downloads city/holdings data from —
  /// no writes ever go here. Public anon key only; never the service role.
  static const String supabaseUrl = 'https://lrxpokqhudpjyjoujnva.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyeHBva3FodWRwanlqb3VqbnZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMzA3MzEsImV4cCI6MjEwMjcwNjczMX0.ypJA1q_RuZp9hnPSIySEMspSB_2xrO-EvyLeOTicpYY';

  static const bool isDevelopment = kDebugMode;

  // App Info
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'HiyazaFinder Dev',
  );
  static const String appVersion = '1.1.7';
  static const String buildNumber = '16';

  // Developer Info
  static const String developerName = 'Mustafa Elbaz';
  static const String developerEmail = 'm9stafa05@gmail.com';
}
