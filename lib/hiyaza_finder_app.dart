import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/settings/cubit/app_settings_cubit.dart';
import 'core/settings/cubit/app_settings_state.dart';
import 'core/themes/theme_data/theme_data_dark.dart';
import 'core/themes/theme_data/theme_data_light.dart';

class HiyazaFinderApp extends StatelessWidget {
  const HiyazaFinderApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Root-level `ScaffoldMessenger` key — lets a snackbar be shown/kept
  /// alive independent of whichever `Scaffold`/route is currently on
  /// screen. Needed for the parcel "Finish" undo snackbar (5s window),
  /// which must survive `DetailScreen` popping back to search.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Width of the centred app column on desktop. Kept phone-like so the
  /// phone-first (375dp) layout and its ScreenUtil scaling stay natural
  /// instead of stretching across a wide monitor.
  static const double _desktopFrameWidth = 500;

  /// Below this window width we drop the frame and use the full-width
  /// phone layout (also covers narrow/resized desktop windows).
  static const double _frameBreakpoint = 640;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Widget build(final BuildContext context) {
    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final bool useFrame =
            _isDesktop && constraints.maxWidth > _frameBreakpoint;

        if (!useFrame) return _buildApp();

        // Centre a phone-width column on desktop and clamp the MediaQuery
        // width so ScreenUtil scales to the frame, not the whole window.
        return ColoredBox(
          color: const Color(0xFF1F2228),
          child: Center(
            child: SizedBox(
              width: _desktopFrameWidth,
              height: constraints.maxHeight,
              child: _ClampWidth(
                width: _desktopFrameWidth,
                child: _buildApp(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildApp() {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (final BuildContext context, final Widget? child) {
        return BlocProvider(
          create: (final _) => AppSettingsCubit(),
          child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
            builder: (
              final BuildContext context,
              final AppSettingsState settings,
            ) {
              return MaterialApp(
                navigatorKey: navigatorKey,
                scaffoldMessengerKey: scaffoldMessengerKey,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: settings.locale, // driven by cubit
                debugShowCheckedModeBanner: false,
                scrollBehavior: const _AppScrollBehavior(),
                initialRoute: Routes.home,
                onGenerateRoute: AppRouter.generateRoute,
                title: AppConfig.appName,
                // font family injected into both themes
                theme: getLightTheme().copyWith(
                  textTheme: getLightTheme().textTheme.apply(
                        fontFamily: settings.fontFamily,
                      ),
                ),
                darkTheme: getDarkTheme().copyWith(
                  textTheme: getDarkTheme().textTheme.apply(
                        fontFamily: settings.fontFamily,
                      ),
                ),
                themeMode: settings.themeMode,
              );
            },
          ),
        );
      },
    );
  }
}

/// Overrides the ambient [MediaQuery] width so descendants (ScreenUtil,
/// layout) size themselves to the desktop frame rather than the full window.
class _ClampWidth extends StatelessWidget {
  const _ClampWidth({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(final BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(size: Size(width, mq.size.height)),
      child: child,
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
