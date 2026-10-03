import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'widgets/jazla_list_view.dart';

import '../../../core/di/dependency_injection.dart';
import '../../parcel_catalog/data/repo/parcel_catalog_repository.dart';
import '../../jazla_transfer/data/repo/jazla_transfer_repository.dart';
import '../../jazla_transfer/logic/cubit/jazla_import_cubit.dart';
import '../data/model/jazla.dart';
import '../data/repo/jazla_repo.dart';
import '../logic/cubit/jazla_list_cubit.dart';

/// Lists every [Jazla] for the active city.
class JazlaListScreen extends StatelessWidget {
  const JazlaListScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final String cityId = getIt<ParcelCatalogRepository>().activeCityId ?? '';
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<JazlaListCubit>(
          create: (final _) =>
              JazlaListCubit(getIt<JazlaRepo>(), cityId)..load(),
        ),
        BlocProvider<JazlaImportCubit>(
          create: (final _) => JazlaImportCubit(
            getIt<JazlaTransferRepository>(),
            getIt<ParcelCatalogRepository>(),
            getIt<JazlaRepo>(),
          ),
        ),
      ],
      child: const JazlaListView(),
    );
  }
}
