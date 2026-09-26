import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/router/routes.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/custom_text_form_.dart';
import '../../cities/data/model/city_snapshot.dart';
import '../../parcel_catalog/data/repo/holdings_reader.dart';
import '../logic/cubit/home_cubit.dart';
import '../logic/cubit/home_state.dart';
import 'package:hiyaza_finder/features/parcel_search/logic/cubit/parcel_search_cubit.dart';
import 'package:hiyaza_finder/features/parcel_search/logic/cubit/parcel_search_state.dart';
import 'widgets/app_identity_header.dart';
import 'widgets/empty_body.dart';
import 'widgets/error_body.dart';
import 'widgets/home_main_card.dart';
import 'widgets/loading_body.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.readerFactory});

  final ParcelCatalogReader Function() readerFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      // The footer badge should stay pinned in place rather than being
      // shoved up by the on-screen keyboard when the search field is
      // focused — the search results area is what should shrink instead.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (final BuildContext context, final HomeState state) {
            return Column(
              children: <Widget>[
                const AppIdentityHeader(),
                if (state.status == HomeStatus.loaded) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(rw(16), rh(4), rw(16), rh(12)),
                    child: HomeMainCard(
                      onChangeCity: () => _openCityPicker(cubit),
                      cityName: state.cityName,
                      associationType: state.associationType,
                      parcelCount: state.parcels.length,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(12)),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (final BuildContext context,
                          final TextEditingValue value, final Widget? child) {
                        return CustomTextForm(
                          hintText: 'holdings.search.hint'.tr(),
                          controller: _controller,
                          isRTL: true,
                          borderColor: colors.border,
                          focusedBorderColor: AppColors.primary200,
                          backgroundColor: colors.surface,
                          borderRadius: 16,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: colors.iconSecondary),
                          suffixIcon: value.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: colors.iconSecondary),
                                  tooltip: 'holdings.search.clear'.tr(),
                                  onPressed: () {
                                    _controller.clear();
                                    context.read<ParcelSearchCubit>().clear();
                                  },
                                ),
                          onChanged:
                              context.read<ParcelSearchCubit>().updateQuery,
                        );
                      },
                    ),
                  ),
                ],
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
                        HomeStatus.loaded =>
                          LoadedBody(reader: widget.readerFactory()),
                      },
                    ),
                  ),
                ),
                BlocSelector<ParcelSearchCubit, ParcelSearchState, bool>(
                  selector: (final ParcelSearchState state) =>
                      state.query.trim().isNotEmpty,
                  builder:
                      (final BuildContext context, final bool isSearching) =>
                          DeveloperFooterBadge(isSearching: isSearching),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
