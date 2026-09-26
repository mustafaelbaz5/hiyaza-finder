// ignore_for_file: always_specify_types

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/about/presentation/about_screen.dart';
import 'package:hiyaza_finder/features/basins/logic/cubit/basins_cubit.dart';
import 'package:hiyaza_finder/features/basins/logic/cubit/basin_holdings_cubit.dart';
import 'package:hiyaza_finder/features/basins/ui/basin_screen.dart';
import 'package:hiyaza_finder/features/basins/ui/basins_page.dart';
import 'package:hiyaza_finder/features/cities/data/model/city_snapshot.dart';
import 'package:hiyaza_finder/features/cities/data/repo/city_repo.dart';
import 'package:hiyaza_finder/features/cities/logic/cubit/city_picker_cubit.dart';
import 'package:hiyaza_finder/features/cities/ui/city_picker_screen.dart';
import 'package:hiyaza_finder/features/cities/ui/city_tools_screen.dart';
import 'package:hiyaza_finder/features/cities/ui/helper_tools_screen.dart';
import 'package:hiyaza_finder/features/cities/ui/manage_cities_screen.dart';
import 'package:hiyaza_finder/features/crop_type/ui/crop_type_settings_screen.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/holdings_reader.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/parcel_catalog_session.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/parcel_detail_actions.dart';
import 'package:hiyaza_finder/features/home/logic/cubit/home_cubit.dart';
import 'package:hiyaza_finder/features/parcel_search/logic/cubit/parcel_search_cubit.dart';
import 'package:hiyaza_finder/features/parcel_editor/logic/cubit/parcel_editor_cubit.dart';
import 'package:hiyaza_finder/features/parcel_add/ui/add_record_screen.dart';
import 'package:hiyaza_finder/features/parcel_add/data/model/add_record_args.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/parcel_catalog_repository.dart';
import 'package:hiyaza_finder/features/parcel_details/ui/detail_screen.dart';
import 'package:hiyaza_finder/features/parcel_export/ui/export_screen.dart';
import 'package:hiyaza_finder/features/parcel_review/ui/file_status_screen.dart';
import 'package:hiyaza_finder/features/home/ui/home_screen.dart';
import 'package:hiyaza_finder/features/parcel_review/ui/missing_holding_id_screen.dart';
import 'package:hiyaza_finder/features/jazla/ui/jazla_detail_screen.dart';
import 'package:hiyaza_finder/features/jazla/ui/jazla_list_screen.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic>? generateRoute(final RouteSettings settings) {
    switch (settings.name) {
      case Routes.aboutScreen:
        return _buildRoute(const AboutScreen(), settings);
      case Routes.cityPicker:
        return _buildRoute<CitySnapshot>(
          // CityPickerCubit is registered as a LazySingleton because it
          // owns the in-memory city catalog across picker screen visits.
          // Using `create` here would make BlocProvider close that singleton
          // when this route is popped, so the next visit would receive a
          // closed Cubit and downloads would return immediately.
          BlocProvider<CityPickerCubit>.value(
            value: getIt<CityPickerCubit>(),
            child: const CityPickerScreen(),
          ),
          settings,
        );
      case Routes.home:
        return _buildRoute(
          MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<HomeCubit>(
                create: (final _) => HomeCubit(
                  getIt<ParcelCatalogSession>(),
                  getIt<ParcelCatalogReader>(),
                  getIt<CityRepo>(),
                )..init(),
              ),
              BlocProvider<ParcelSearchCubit>(
                create: (final _) =>
                    ParcelSearchCubit(getIt<ParcelCatalogReader>()),
              ),
            ],
            child:
                HomeScreen(readerFactory: () => getIt<ParcelCatalogReader>()),
          ),
          settings,
        );
      case Routes.basins:
        return _buildRoute(
          BlocProvider<BasinsCubit>(
            create: (final _) => BasinsCubit(getIt<ParcelCatalogReader>()),
            child: const BasinsPage(),
          ),
          settings,
        );
      case Routes.basin:
        final String basinName = settings.arguments as String? ?? '';
        return _buildRoute(
          BlocProvider<BasinHoldingsCubit>(
            create: (final _) => BasinHoldingsCubit(
              getIt<ParcelCatalogReader>(),
              basinName: basinName,
            ),
            child: BasinScreen(basinName: basinName),
          ),
          settings,
        );
      case Routes.holdingDetail:
        final List<Parcel> parcels =
            (settings.arguments as List<Parcel>?) ?? const <Parcel>[];
        return _buildRoute(
          BlocProvider<ParcelEditorCubit>(
            create: (final _) => getIt<ParcelEditorCubit>(),
            child: DetailScreen(
              parcels: parcels,
              reader: getIt<ParcelCatalogReader>(),
              actions: getIt<ParcelDetailActions>(),
            ),
          ),
          settings,
        );
      case Routes.addRecord:
        final AddRecordArgs args = (settings.arguments as AddRecordArgs?) ??
            const AddRecordArgs(initialParcel: Parcel(holdingId: ''));
        return _buildRoute<Parcel?>(
          AddRecordScreen(
            initialParcel: args.initialParcel,
            repository: getIt<ParcelCatalogRepository>(),
            parentHoldingId: args.parentHoldingId,
          ),
          settings,
        );
      case Routes.fileStatus:
        return _buildRoute(const FileStatusScreen(), settings);
      case Routes.manageCities:
        return _buildRoute(const ManageCitiesScreen(), settings);
      case Routes.cityTools:
        return _buildRoute(const CityToolsScreen(), settings);
      case Routes.helperTools:
        return _buildRoute(const HelperToolsScreen(), settings);
      case Routes.missingHoldingId:
        return _buildRoute(const MissingHoldingIdScreen(), settings);
      case Routes.cropTypeSettings:
        return _buildRoute(const CropTypeSettingsScreen(), settings);
      case Routes.export:
        return _buildRoute(const ExportScreen(), settings);
      case Routes.jazlaList:
        return _buildRoute(const JazlaListScreen(), settings);
      case Routes.jazlaDetail:
        final String jazlaId = settings.arguments as String? ?? '';
        return _buildRoute(JazlaDetailScreen(jazlaId: jazlaId), settings);
      default:
        return null;
    }
  }

  static PageRouteBuilder<T> _buildRoute<T>(
    final Widget page,
    final RouteSettings settings,
  ) {
    return PageRouteBuilder<T>(
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
