import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../data/local/holding_search_service.dart';
import '../../data/model/parcel.dart';
import '../../data/repo/holdings_repository.dart';
import '../../logic/cubit/home_cubit.dart';
import '../../logic/cubit/home_state.dart';
import '../add_record_screen.dart';
import 'home_empty_state.dart';
import 'recommendation_list.dart';

class LoadingBody extends StatelessWidget {
  const LoadingBody({super.key});

  @override
  Widget build(final BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary200),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Search bar stays pinned at the top — only the body below scrolls. Home is
/// search-first (UI/UX Updates prompt "Change 3"): the body shows
/// [RecommendationList]'s search results while [HomeState.query] is
/// non-empty, and [HomeEmptyState] otherwise — there is no flat,
/// unfiltered city-wide list here at all (basin grouping/progress lives on
/// its own [BasinsPage]).
class LoadedBody extends StatefulWidget {
  const LoadedBody({
    super.key,
    required this.state,
    required this.controller,
    required this.cubit,
    required this.onQueryChanged,
  });

  final HomeState state;
  final TextEditingController controller;
  final HomeCubit cubit;
  final void Function(String query) onQueryChanged;

  @override
  State<LoadedBody> createState() => LoadedBodyState();
}

class LoadedBodyState extends State<LoadedBody> {
  void _openDetail(final BuildContext context, final SearchResult result) {
    final HoldingsRepository repository = getIt<HoldingsRepository>();
    context.pushNamed(
      Routes.holdingDetail,
      arguments: repository.parcelsForHolding(result.groupKey),
    );
  }

  Future<void> _openAddPerson(final BuildContext context) async {
    final bool? added = await context.pushNamed<bool>(
      Routes.addRecord,
      arguments: const AddRecordArgs(
        initialParcel: Parcel(
          // Left blank — رقم الحيازة is a required field
          // (`Parcel.hasRequiredFieldsFilled`) that must be explicitly
          // typed by the user.
          holdingId: '',
          landNumber: '0',
          holdingsCount: 1, // a brand-new person starts with one قطعة
        ),
      ),
    );
    if (added == true && context.mounted) {
      widget.cubit.refreshData();
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    final List<Widget> suffixButtons = <Widget>[
      if (widget.controller.text.isNotEmpty)
        IconButton(
          icon: Icon(Icons.close_rounded, color: colors.iconSecondary),
          tooltip: 'holdings.search.clear'.tr(),
          onPressed: () {
            widget.controller.clear();
            widget.onQueryChanged('');
          },
        ),
    ];
    final Widget? suffixIcon = suffixButtons.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: suffixButtons);

    final bool isSearching = widget.state.query.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double horizontalPadding = isTablet ? rw(64) : rw(16);

        return Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      verticalSpacing(8),
                      CustomTextForm(
                        hintText: 'holdings.search.hint'.tr(),
                        controller: widget.controller,
                        isRTL: true,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: colors.iconSecondary,
                        ),
                        suffixIcon: suffixIcon,
                        onChanged: widget.onQueryChanged,
                      ),
                      verticalSpacing(8),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: isSearching
                        ? RecommendationList(
                            query: widget.state.query,
                            results: widget.state.results,
                            onSelect: (final SearchResult result) =>
                                _openDetail(context, result),
                            onAddNew: () => _openAddPerson(context),
                          )
                        : const HomeEmptyState(),
                  ),
                ),
              ],
            ),
            // Always-visible add-person entry point — previously only
            // reachable after typing a search that returned no results,
            // which meant a brand-new person could only be added by first
            // proving they weren't already in the data.
            PositionedDirectional(
              bottom: rh(20),
              end: rw(20),
              child: FloatingActionButton.extended(
                onPressed: () => _openAddPerson(context),
                backgroundColor: AppColors.primary200,
                foregroundColor: AppColors.white,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text('holdings.add.new_person_cta'.tr()),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 250.ms);
      },
    );
  }
}
