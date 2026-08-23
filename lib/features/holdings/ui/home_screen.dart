import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cities/data/model/city_snapshot.dart';
import '../logic/cubit/home_cubit.dart';
import '../logic/cubit/home_state.dart';
import 'widgets/empty_body.dart';
import 'widgets/error_body.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/loading_body.dart';

import '../../../core/router/routes.dart';
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

  Future<void> _openCityPicker(final HomeCubit cubit) async {
    final CitySnapshot? snapshot =
        await context.pushNamed<CitySnapshot>(Routes.cityPicker);
    if (snapshot != null && mounted) {
      cubit.loadFromDownloadedCity(snapshot);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final HomeCubit cubit = context.read<HomeCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (final BuildContext context, final HomeState state) {
            return Column(
              children: <Widget>[
                HomeTopBar(
                  onChangeCity: () => _openCityPicker(cubit),
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
