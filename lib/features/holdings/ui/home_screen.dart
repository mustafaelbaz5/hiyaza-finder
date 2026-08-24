import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/router/routes.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/custom_text_form_.dart';
import '../../cities/data/model/city_snapshot.dart';
import '../logic/cubit/home_cubit.dart';
import '../logic/cubit/home_state.dart';
import 'widgets/app_identity_header.dart';
import 'widgets/empty_body.dart';
import 'widgets/error_body.dart';
import 'widgets/home_main_card.dart';
import 'widgets/loading_body.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _onQueryChanged(final String query, final HomeCubit cubit) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
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
      // The footer badge should stay pinned in place rather than being
      // shoved up by the on-screen keyboard when the search field is
      // focused — the search results area is what should shrink instead.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (final BuildContext context, final HomeState state) {
            final bool isSearching = state.query.trim().isNotEmpty;
            return Column(
              children: <Widget>[
                const AppIdentityHeader(),
                if (state.status == HomeStatus.loaded) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(rw(16), rh(4), rw(16), rh(12)),
                    child: HomeMainCard(
                      onChangeCity: () => _openCityPicker(cubit),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(12)),
                    child: CustomTextForm(
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
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: colors.iconSecondary),
                              tooltip: 'holdings.search.clear'.tr(),
                              onPressed: () {
                                _controller.clear();
                                _onQueryChanged('', cubit);
                              },
                            ),
                      onChanged: (final String q) => _onQueryChanged(q, cubit),
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
                        HomeStatus.loaded => LoadedBody(
                            state: state,
                            cubit: cubit,
                          ),
                      },
                    ),
                  ),
                ),
                DeveloperFooterBadge(isSearching: isSearching),
              ],
            );
          },
        ),
      ),
    );
  }
}
