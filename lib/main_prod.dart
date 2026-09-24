import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'core/di/dependency_injection.dart';
import 'features/cities/logic/cubit/city_picker_cubit.dart';
import 'core/localization/localization_manager.dart';
import 'core/widgets/error_screen.dart';
import 'hiyaza_finder_app.dart';

void main() {
  // Keep uncaught asynchronous failures visible without terminating the app.
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
  unawaited(getIt<CityPickerCubit>().initialize());
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
