// ignore_for_file: always_specify_types

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/about/ui/about_screen.dart';
import 'package:hiyaza_finder/features/auth/presentation/screens/login_screen.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/logic/cubit/home_cubit.dart';
import 'package:hiyaza_finder/features/holdings/ui/screens/detail_screen.dart';
import 'package:hiyaza_finder/features/holdings/ui/screens/file_status_screen.dart';
import 'package:hiyaza_finder/features/holdings/ui/screens/history_screen.dart';
import 'package:hiyaza_finder/features/holdings/ui/screens/home_screen.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic>? generateRoute(final RouteSettings settings) {
    switch (settings.name) {
      case Routes.aboutScreen:
        return _buildRoute(const AboutScreen(), settings);
      case Routes.login:
        return _buildRoute(const LoginScreen(), settings);
      case Routes.home:
        return _buildRoute(
          BlocProvider<HomeCubit>(
            create: (final _) => HomeCubit(getIt<HoldingsRepository>())..init(),
            child: const HomeScreen(),
          ),
          settings,
        );
      case Routes.holdingDetail:
        final List<Parcel> parcels =
            (settings.arguments as List<Parcel>?) ?? const <Parcel>[];
        return _buildRoute(DetailScreen(parcels: parcels), settings);
      case Routes.fileHistory:
        return _buildRoute(const HistoryScreen(), settings);
      case Routes.fileStatus:
        return _buildRoute(const FileStatusScreen(), settings);
      default:
        return null;
    }
  }

  static PageRouteBuilder _buildRoute(
    final Widget page,
    final RouteSettings settings,
  ) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (final context, final animation, final secondaryAnimation) =>
          page,
      transitionsBuilder: (
        final context,
        final animation,
        final secondaryAnimation,
        final child,
      ) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
