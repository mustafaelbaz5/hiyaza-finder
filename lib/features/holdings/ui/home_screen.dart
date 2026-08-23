import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
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
import '../../../core/themes/app_colors.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/custom_text_form_.dart';

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
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (final BuildContext context, final HomeState state) {
            return Column(
              children: <Widget>[
                HomeTopBar(
                  onChangeCity: () => _openCityPicker(cubit),
                ),
                // The search bar (UI/UX Updates prompt "Change 5") — its own
                // elevated card, separate from `HomeTopBar`, fixed at the
                // top of the body while everything below scrolls. Only
                // meaningful once a city is loaded, so it's hidden entirely
                // for the loading/no-file/error states.
                if (state.status == HomeStatus.loaded)
                  Padding(
                    padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(12)),
                    child: _SearchCard(
                      controller: _controller,
                      onChanged: (final String q) => _onQueryChanged(q, cubit),
                    ),
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
                            cubit: cubit,
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

/// The search bar's own elevated, rounded card (UI/UX Updates prompt
/// "Change 5") — visually distinct from the surrounding screen so it reads
/// as a clear, tappable search affordance rather than blending into the
/// AppBar the way it used to. Stateful only so the clear (×) suffix icon
/// can appear/disappear as [controller]'s text changes — [HomeScreen]
/// itself still owns the controller and the debounce.
class _SearchCard extends StatefulWidget {
  const _SearchCard({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<_SearchCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: CustomTextForm(
        hintText: 'holdings.search.hint'.tr(),
        controller: widget.controller,
        isRTL: true,
        borderColor: Colors.transparent,
        focusedBorderColor: AppColors.primary200,
        backgroundColor: Colors.transparent,
        borderRadius: 16,
        prefixIcon: Icon(Icons.search_rounded, color: colors.iconSecondary),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: colors.iconSecondary),
                tooltip: 'holdings.search.clear'.tr(),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
