import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../data/local/holding_search_service.dart';
import '../../data/model/basin_progress.dart';
import '../../data/model/parcel.dart';
import '../../data/repo/holdings_repository.dart';
import '../../logic/cubit/home_cubit.dart';
import '../../logic/cubit/home_state.dart';
import '../add_record_screen.dart';

import 'basin_card.dart';
import 'basin_progress_bar.dart';
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

/// Search bar stays pinned at the top — only the body below scrolls. Body
/// shows search results while [HomeState.query] is non-empty, otherwise
/// the basin-first progress card list (APP_CLAUDE.md § Screen 1).
class LoadedBody extends StatefulWidget {
  const LoadedBody({
    super.key,
    required this.state,
    required this.controller,
    required this.cubit,
    required this.onQueryChanged,
    required this.onOpenFileStatus,
    required this.onChangeCity,
  });

  final HomeState state;
  final TextEditingController controller;
  final HomeCubit cubit;
  final void Function(String query) onQueryChanged;
  final VoidCallback onOpenFileStatus;
  final VoidCallback onChangeCity;

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

  Future<void> _openBasin(final BuildContext context, final String basinName) async {
    await context.pushNamed(Routes.basin, arguments: basinName);
    if (context.mounted) widget.cubit.refreshData();
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
          notes: <String>['نقص بيانات الحصر'],
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
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: isSearching
                        ? RecommendationList(
                            query: widget.state.query,
                            results: widget.state.results,
                            onSelect: (final SearchResult result) =>
                                _openDetail(context, result),
                            onAddNew: () => _openAddPerson(context),
                          )
                        : _BasinList(
                            state: widget.state,
                            onOpenBasin: (final String basin) =>
                                _openBasin(context, basin),
                            onOpenFileStatus: widget.onOpenFileStatus,
                            onChangeCity: widget.onChangeCity,
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

/// Basin progress cards + the whole-city footer progress bar
/// (APP_CLAUDE.md § Screen 1's "الإجمالي: 114 / 1,350  8%" row).
class _BasinList extends StatelessWidget {
  const _BasinList({
    required this.state,
    required this.onOpenBasin,
    required this.onOpenFileStatus,
    required this.onChangeCity,
  });

  final HomeState state;
  final ValueChanged<String> onOpenBasin;
  final VoidCallback onOpenFileStatus;
  final VoidCallback onChangeCity;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    if (state.basins.isEmpty) {
      return Center(
        child: Text(
          'holdings.home.no_basins'.tr(),
          style: AppTextStyles.font14Regular.copyWith(color: colors.textHint),
        ),
      );
    }

    final int total = state.totalHoldingsCount;
    final int completed = state.completedHoldingsCount;
    final double overallProgress = total == 0 ? 0 : completed / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'holdings.home.basins_title'.tr(),
                style: AppTextStyles.font16SemiBold.copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            IconButton(
              icon: Icon(Icons.swap_horiz_rounded, color: colors.iconSecondary),
              tooltip: 'holdings.home.change_file'.tr(),
              onPressed: onChangeCity,
            ),
            IconButton(
              icon: Icon(Icons.dashboard_customize_rounded, color: colors.iconSecondary),
              tooltip: 'holdings.bulk_edit.entry_pill'.tr(),
              onPressed: onOpenFileStatus,
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: state.basins.length,
            itemBuilder: (final BuildContext context, final int i) {
              final BasinProgress basin = state.basins[i];
              return BasinCard(
                basin: basin,
                animationIndex: i,
                onTap: () => onOpenBasin(basin.basinName),
              );
            },
          ),
        ),
        verticalSpacing(8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'holdings.home.overall_total'.tr(
                        namedArgs: {
                          'completed': completed.toString(),
                          'total': total.toString(),
                        },
                      ),
                      style: AppTextStyles.font14Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Text(
                    '${(overallProgress * 100).round()}%',
                    style: AppTextStyles.font14Bold.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              verticalSpacing(8),
              BasinProgressBar(
                progress: overallProgress,
                isFullyCompleted: total > 0 && completed == total,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
