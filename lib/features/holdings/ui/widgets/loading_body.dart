import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/features/holdings/data/local/holding_search_service.dart';
import 'package:hiyaza_finder/features/holdings/data/repo/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/logic/cubit/home_cubit.dart';
import 'package:hiyaza_finder/features/holdings/logic/cubit/home_state.dart';

class LoadingBody extends StatelessWidget {
  const LoadingBody({super.key});

  @override
  Widget build(final BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary200),
    ).animate().fadeIn(duration: 200.ms);
  }
}


/// Search bar (and the file-info card above it) stay pinned at the top —
/// only the results list below scrolls — so the user never has to scroll
/// up just to search again.
class _LoadedBody extends StatefulWidget {
  const _LoadedBody({
    required this.state,
    required this.controller,
    required this.cubit,
    required this.onQueryChanged,
    required this.onOpenBasinFilter,
    required this.onOpenFileStatus,
    required this.onChangeCity,
  });

  final HomeState state;
  final TextEditingController controller;
  final HomeCubit cubit;
  final void Function(String query) onQueryChanged;
  final VoidCallback onOpenBasinFilter;
  final VoidCallback onOpenFileStatus;
  final VoidCallback onChangeCity;

  @override
  State<_LoadedBody> createState() => _LoadedBodyState();
}

class _LoadedBodyState extends State<_LoadedBody> {
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
          // Left blank rather than defaulting to "-1" — رقم الحيازة is a
          // required field (`Parcel.hasRequiredFieldsFilled`) that must be
          // explicitly typed, even if the user's own answer ends up being
          // "-1" themselves; auto-filling it here would satisfy the
          // required-field gate without the user ever touching the field.
          holdingId: '',
          nationalId: '11111111111111',
          landNumber: '-1',
          notes: 'نقص بيانات الحصر',
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
                      FileInfoCard(
                        holdingCount: widget.state.holdingCount,
                        selectedBasin: widget.state.selectedBasin,
                        hasBasins: widget.state.availableBasins.isNotEmpty,
                        onChangeFile: widget.onChangeCity,
                        onOpenBasinFilter: widget.onOpenBasinFilter,
                        onOpenFileStatus: widget.onOpenFileStatus,
                      ),
                      verticalSpacing(16),
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
                    child: RecommendationList(
                      query: widget.state.query,
                      results: widget.state.results,
                      onSelect: (final SearchResult result) =>
                          _openDetail(context, result),
                      onAddNew: () => _openAddPerson(context),
                    ),
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
