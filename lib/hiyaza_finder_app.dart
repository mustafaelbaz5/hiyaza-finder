import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/config/app_config.dart';
import 'core/di/dependency_injection.dart';
import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/settings/cubit/app_settings_cubit.dart';
import 'core/settings/cubit/app_settings_state.dart';
import 'core/themes/theme_data/theme_data_dark.dart';
import 'core/themes/theme_data/theme_data_light.dart';
import 'features/auth/presentation/cubit/session_cubit.dart';
import 'features/auth/presentation/cubit/session_state.dart';
import 'features/sync/presentation/cubit/sync_status_cubit.dart';

class HiyazaFinderApp extends StatelessWidget {
  const HiyazaFinderApp({super.key});

  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Width of the centred app column on desktop. Kept phone-like so the
  /// phone-first (375dp) layout and its ScreenUtil scaling stay natural
  /// instead of stretching across a wide monitor.
  static const double _desktopFrameWidth = 500;

  /// Below this window width we drop the frame and use the full-width
  /// phone layout (also covers narrow/resized desktop windows).
  static const double _frameBreakpoint = 640;

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Widget build(final BuildContext context) {
    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final bool useFrame = _isDesktop && constraints.maxWidth > _frameBreakpoint;

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
          child: BlocProvider<SessionCubit>.value(
            value: getIt<SessionCubit>(),
            child: BlocProvider<SyncStatusCubit>.value(
              value: getIt<SyncStatusCubit>(),
              child: BlocListener<SessionCubit, SessionState>(
                listenWhen: (final SessionState previous, final SessionState current) =>
                    previous.status != SessionStatus.unauthenticated &&
                    current.status == SessionStatus.unauthenticated,
                // Catches a session that becomes invalid while the user is
                // already past login (e.g. an expired/revoked refresh
                // token) and bounces them back rather than leaving screens
                // silently calling an API that will now reject them.
                listener: (final BuildContext context, final SessionState _) {
                  _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                    Routes.login,
                    (final _) => false,
                  );
                },
                child: _AppLifecycleSyncTrigger(
                  child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
                    builder: (
                      final BuildContext context,
                      final AppSettingsState settings,
                    ) {
                      return MaterialApp(
                        navigatorKey: _navigatorKey,
                        localizationsDelegates: context.localizationDelegates,
                        supportedLocales: context.supportedLocales,
                        locale: settings.locale, // driven by cubit
                        debugShowCheckedModeBanner: false,
                        scrollBehavior: const _AppScrollBehavior(),
                        initialRoute: getIt<SessionCubit>().state.isAuthenticated
                            ? Routes.home
                            : Routes.login,
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Triggers a sync flush whenever the app comes back to the foreground —
/// one of the three flush triggers alongside connectivity-regained
/// (wired inside `SyncStatusCubit`) and the manual badge tap.
class _AppLifecycleSyncTrigger extends StatefulWidget {
  const _AppLifecycleSyncTrigger({required this.child});

  final Widget child;

  @override
  State<_AppLifecycleSyncTrigger> createState() => _AppLifecycleSyncTriggerState();
}

class _AppLifecycleSyncTriggerState extends State<_AppLifecycleSyncTrigger>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      getIt<SyncStatusCubit>().flushNow();
    }
  }

  @override
  Widget build(final BuildContext context) => widget.child;
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

/// Lets desktop/web users drag-scroll with the mouse (touch is enabled by
/// default), so scrollable lists feel right with a trackpad or mouse.
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
