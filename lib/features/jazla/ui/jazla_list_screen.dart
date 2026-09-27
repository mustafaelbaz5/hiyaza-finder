import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/jazla_list_view.dart';

import '../../../core/di/dependency_injection.dart';
import '../../parcel_catalog/data/repo/parcel_catalog_repository.dart';
import '../data/model/jazla.dart';
import '../data/repo/jazla_repo.dart';
import '../logic/cubit/jazla_list_cubit.dart';

/// Lists every [Jazla] for the active city — tap opens its detail screen,
/// long-press offers rename/delete, "+ جزلة جديدة" creates a new one.
class JazlaListScreen extends StatelessWidget {
  const JazlaListScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final String cityId = getIt<ParcelCatalogRepository>().activeCityId ?? '';
    return BlocProvider<JazlaListCubit>(
      create: (final _) => JazlaListCubit(getIt<JazlaRepo>(), cityId)..load(),
      child: const JazlaListView(),
    );
  }
}
