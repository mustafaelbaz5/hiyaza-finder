import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cities/data/model/city_snapshot.dart';
import '../data/repo/holdings_repository.dart';
import '../logic/cubit/home_cubit.dart';
import '../logic/cubit/home_state.dart';
import 'widgets/basin_filter_sheet.dart';
import 'widgets/empty_body.dart';
import 'widgets/error_body.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/loading_body.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/settings/ui/settings_sheet.dart';
import '../../../core/utils/extensions/context_ext.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(final String query, final HomeCubit cubit) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      cubit.search(query);
    });
  }

  Future<void> _openBasinFilter(final HomeCubit cubit) async {
    final HomeState state = cubit.state;
    final String? selected = await showBasinFilterSheet(
      context,
      basins: state.availableBasins,
      selected: state.selectedBasin,
      holdingCounts: getIt<HoldingsRepository>().basinHoldingCounts,
    );
    if (selected != state.selectedBasin) {
      cubit.selectBasin(selected);
    }
  }

  Future<void> _openFileStatus(final HomeCubit cubit) async {
    await context.pushNamed(Routes.fileStatus);
    if (mounted) cubit.refreshData();
  }

  Future<void> _openCityPicker(final HomeCubit cubit) async {
    final CitySnapshot? snapshot =
        await context.pushNamed<CitySnapshot>(Routes.cityPicker);
    if (snapshot != null && mounted) {
      cubit.loadFromDownloadedCity(snapshot);
    }
  }

  /// Runs once right after a city finishes loading: opens the basin
  /// filter automatically if there's more than one basin to choose from.
  Future<void> _onCityLoaded(final HomeCubit cubit) async {
    if (cubit.state.availableBasins.length > 1) {
      await _openBasinFilter(cubit);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final HomeCubit cubit = context.read<HomeCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocConsumer<HomeCubit, HomeState>(
          listenWhen: (final HomeState previous, final HomeState current) =>
              current.status == HomeStatus.loaded &&
              previous.status != HomeStatus.loaded,
          listener: (final BuildContext context, final HomeState state) {
            _onCityLoaded(cubit);
          },
          builder: (final BuildContext context, final HomeState state) {
            return Column(
              children: <Widget>[
                HomeTopBar(
                  onSettings: () => showSettingsSheet(context),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey<HomeStatus>(state.status),
                      child: switch (state.status) {
                        HomeStatus.loading => const LoadingBody(),
                        HomeStatus.noFile => EmptyBody(
                            onPickFile: () => _openCityPicker(cubit),
                          ),
                        HomeStatus.error => ErrorBody(
                            state: state,
                            onPickFile: () => _openCityPicker(cubit),
                          ),
                        HomeStatus.loaded => LoadedBody(
                            state: state,
                            controller: _controller,
                            cubit: cubit,
                            onQueryChanged: (final String q) =>
                                _onQueryChanged(q, cubit),
                            onOpenBasinFilter: () => _openBasinFilter(cubit),
                            onOpenFileStatus: () => _openFileStatus(cubit),
                            onChangeCity: () => _openCityPicker(cubit),
                          ),
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}