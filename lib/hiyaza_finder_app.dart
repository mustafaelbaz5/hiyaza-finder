import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/features/app_control/data/model/app_control.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/settings/cubit/app_settings_cubit.dart';
import 'core/settings/cubit/app_settings_state.dart';
import 'core/themes/theme_data/theme_data_dark.dart';
import 'core/themes/theme_data/theme_data_light.dart';
import 'features/app_control/logic/cubit/app_control_cubit.dart';
import 'features/app_control/ui/app_blocked_screen.dart';

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
    const Widget app = _AppBootstrap();
    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final bool useFrame =
            _isDesktop && constraints.maxWidth > _frameBreakpoint;

        if (!useFrame) return app;

        // Centre a phone-width column on desktop and clamp the MediaQuery
        // width so ScreenUtil scales to the frame, not the whole window.
        return ColoredBox(
          color: const Color(0xFF1F2228),
          child: Center(
            child: SizedBox(
              width: _desktopFrameWidth,
              height: constraints.maxHeight,
              child: const _ClampWidth(
                width: _desktopFrameWidth,
                child: app,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kept outside the desktop frame so a window resize changes only the frame,
/// not ScreenUtil, dependency providers, or MaterialApp itself.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final AppControlCubit _appControlCubit;

  @override
  void initState() {
    super.initState();
    _appControlCubit = getIt<AppControlCubit>();
    unawaited(_appControlCubit.initialize());
  }

  @override
  Widget build(final BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (final BuildContext context, final Widget? child) {
        return BlocProvider<AppSettingsCubit>(
          create: (final _) => AppSettingsCubit(),
          child: BlocProvider.value(
            value: _appControlCubit,
            child: const _AppMaterial(),
          ),
        );
      },
    );
  }
}

class _AppMaterial extends StatelessWidget {
  const _AppMaterial();

  @override
  Widget build(final BuildContext context) {
    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      buildWhen:
          (final AppSettingsState previous, final AppSettingsState current) =>
              previous.locale != current.locale ||
              previous.fontFamily != current.fontFamily ||
              previous.themeMode != current.themeMode,
      builder: (final BuildContext context, final AppSettingsState settings) {
        final ThemeData lightBase = getLightTheme();
        final ThemeData darkBase = getDarkTheme();
        return BlocBuilder<AppControlCubit, AppControl>(
          builder: (final BuildContext context, final AppControl control) =>
              MaterialApp(
            navigatorKey: HiyazaFinderApp.navigatorKey,
            scaffoldMessengerKey: HiyazaFinderApp.scaffoldMessengerKey,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: settings.locale,
            debugShowCheckedModeBanner: false,
            scrollBehavior: const _AppScrollBehavior(),
            initialRoute: Routes.home,
            builder: (final BuildContext context, final Widget? child) =>
                control.isBlocked
                    ? AppBlockedScreen(control: control)
                    : (child ?? const SizedBox.shrink()),
            onGenerateRoute: AppRouter.generateRoute,
            title: AppConfig.appName,
            theme: lightBase.copyWith(
              textTheme:
                  lightBase.textTheme.apply(fontFamily: settings.fontFamily),
            ),
            darkTheme: darkBase.copyWith(
              textTheme:
                  darkBase.textTheme.apply(fontFamily: settings.fontFamily),
            ),
            themeMode: settings.themeMode,
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
