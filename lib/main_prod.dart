import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'core/di/dependency_injection.dart';
import 'core/localization/localization_manager.dart';
import 'core/widgets/error_screen.dart';
import 'hiyaza_finder_app.dart';

void main() {
  // Catches any async error that escapes every other handler — most
  // notably supabase_flutter's own background token-refresh timer, which
  // runs unsupervised by this app's code and previously dumped a raw
  // "Unhandled Exception" to the console (with no crash, since Dart async
  // errors don't tear down the isolate) whenever it failed offline. Logging
  // instead of leaving it unhandled makes the failure visible without the
  // scary uncaught-exception framing for something that isn't fatal.
  runZonedGuarded(_bootstrap, (final Object error, final StackTrace stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  ErrorWidget.builder = (final details) => const ErrorScreen();
  await EasyLocalization.ensureInitialized();
  await ScreenUtil.ensureScreenSize();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory((await getTemporaryDirectory()).path),
  );
  await setUpDependencies();
  runApp(
    EasyLocalization(
      supportedLocales: LocalizationManager.supportedLocales,
      path: LocalizationManager.translationsPath,
      fallbackLocale: LocalizationManager.fallbackLocale,
      startLocale: const Locale('ar'),
      child: const HiyazaFinderApp(),
    ),
  );
}
