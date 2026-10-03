import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../parcel_catalog/data/model/search_result.dart';

import '../../../core/router/routes.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../home/ui/widgets/recommendation_tile.dart';
import '../../home/ui/widgets/top_bar_icon_button.dart';
import '../../parcel_add/data/model/add_record_args.dart';
import '../../parcel_catalog/data/model/parcel.dart';
import '../../parcel_catalog/data/model/parcel_visibility_filter.dart';
import '../../parcel_export/ui/export_bottom_sheet.dart';
import '../../parcel_search/data/local/holding_search_service.dart';
import '../data/model/basin_holding_filter.dart';
import '../logic/cubit/basin_holdings_cubit.dart';
import '../logic/cubit/basin_holdings_state.dart';
import 'widgets/basin_info_card.dart';

/// Operational basin view with independent visibility and review filters.
class BasinScreen extends StatelessWidget {
  const BasinScreen({super.key, required this.basinName});
  final String basinName;

  Future<void> _openDetail(
          final BuildContext context, final SearchResult result) =>
      context.pushNamed(
        Routes.holdingDetail,
        arguments:
            context.read<BasinHoldingsCubit>().parcelsFor(result.groupKey),
      );

  Future<void> _addParcel(final BuildContext context) =>
      context.pushNamed<Parcel?>(
        Routes.addRecord,
        arguments: AddRecordArgs(
          initialParcel: Parcel(
              holdingId: '',
              landNumber: '0',
              basinName: basinName,
              holdingsCount: 1),
        ),
      );

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocBuilder<BasinHoldingsCubit, BasinHoldingsState>(
          builder:
              (final BuildContext context, final BasinHoldingsState state) =>
                  Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: rw(16), vertical: rh(12)),
                child: Row(children: <Widget>[
                  const AppBackButton(),
                  horizontalSpacing(12),
                  Expanded(
                      child: Text(basinName,
                          style: AppTextStyles.font20Bold
                              .copyWith(color: colors.textPrimary),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  Text(
                      '${state.completedHoldingCount}/${state.activeHoldingCount}',
                      style: AppTextStyles.font16Bold
                          .copyWith(color: colors.textSecondary)),
                  horizontalSpacing(4),
                  TopBarIconButton(
                      icon: Icons.ios_share_rounded,
                      tooltip: 'holdings.export.title'.tr(),
                      onTap: () => showExportBottomSheet(context,
                          basinName: basinName,
                          basinParcels: state.basinParcels)),
                  horizontalSpacing(4),
                  TopBarIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'holdings.home.activity.filter_title'.tr(),
                    onTap: () => _showBasinFilterSheet(context, state),
                  ),
                ]),
              ),
              BasinInfoCard(basin: state.basin),
              Padding(
                padding: EdgeInsets.fromLTRB(rw(16), rh(8), rw(16), 0),
                child: _ActivitySummary(state: state),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(rw(16), rh(8), rw(16), 0),
                child: _FilterSummary(state: state),
              ),
              verticalSpacing(8),
              Expanded(
                  child: Stack(children: <Widget>[
                state.visibleResults.isEmpty
                    ? Center(
                        child: Text('holdings.basin_screen.empty'.tr(),
                            style: AppTextStyles.font14Regular
                                .copyWith(color: colors.textHint)))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: rw(16))
                            .copyWith(bottom: rh(80)),
                        itemCount: state.visibleResults.length,
                        itemBuilder:
                            (final BuildContext context, final int index) {
                          final SearchResult result =
                              state.visibleResults[index];
                          return RecommendationTile(
                              result: result,
                              onTap: () => _openDetail(context, result),
                              animationDelay: Duration(
                                  milliseconds: index.clamp(0, 8) * 20));
                        },
                      ),
                PositionedDirectional(
                    bottom: rh(16),
                    end: rw(16),
                    child: FloatingActionButton.extended(
                        onPressed: () => _addParcel(context),
                        backgroundColor: AppColors.primary200,
                        foregroundColor: AppColors.white,
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: Text('holdings.add.new_parcel_title'.tr()))),
              ])),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.state});
  final BasinHoldingsState state;
  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final summary = state.activitySummary;
    return Row(children: <Widget>[
      Expanded(
          child: _Metric(
              '${summary.activeParcelCount}',
              'holdings.home.activity.active_parcels'.tr(),
              AppColors.primary200)),
      Expanded(
          child: _Metric(
              '${summary.totalParcelCount}',
              'holdings.home.activity.total_records'.tr(),
              colors.textSecondary)),
      Expanded(
          child: _Metric('${summary.zeroAreaParcelCount}',
              'holdings.home.activity.zero_area_short'.tr(), colors.textHint)),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(final BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(value, style: AppTextStyles.font16Bold.copyWith(color: color)),
        Text(label,
            style: AppTextStyles.font12Regular.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis)
      ]);
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.state});
  final BasinHoldingsState state;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: <Widget>[
        const Icon(Icons.filter_alt_outlined,
            size: 17, color: AppColors.primary200),
        horizontalSpacing(8),
        Expanded(
            child: Text(
                '${_visibilityLabel(state.visibility)} · ${_reviewLabel(state.filter)}',
                style: AppTextStyles.font12Bold
                    .copyWith(color: colors.textSecondary),
                textAlign: TextAlign.right)),
      ]),
    );
  }
}

Future<void> _showBasinFilterSheet(
    final BuildContext context, final BasinHoldingsState state) async {
  final _BasinFilterSelection? selection =
      await showModalBottomSheet<_BasinFilterSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (final BuildContext context) => _BasinFilterSheet(initial: state),
  );
  if (selection == null || !context.mounted) return;
  final BasinHoldingsCubit cubit = context.read<BasinHoldingsCubit>();
  cubit.selectVisibility(selection.visibility);
  cubit.selectFilter(selection.review);
}

class _BasinFilterSheet extends StatefulWidget {
  const _BasinFilterSheet({required this.initial});
  final BasinHoldingsState initial;
  @override
  State<_BasinFilterSheet> createState() => _BasinFilterSheetState();
}

class _BasinFilterSheetState extends State<_BasinFilterSheet> {
  late ParcelVisibilityFilter visibility = widget.initial.visibility;
  late BasinHoldingFilter review = widget.initial.filter;
  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: colors.border,
                            borderRadius: BorderRadius.circular(99)))),
                verticalSpacing(18),
                Text('holdings.home.activity.filter_title'.tr(),
                    style: AppTextStyles.font18Bold
                        .copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.right),
                verticalSpacing(12),
                Text('holdings.home.activity.filter_title'.tr(),
                    style: AppTextStyles.font12Bold
                        .copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.right),
                for (final ParcelVisibilityFilter option
                    in ParcelVisibilityFilter.values)
                  _SheetChoice(
                      label: _visibilityLabel(option),
                      selected: visibility == option,
                      onTap: () => setState(() => visibility = option)),
                verticalSpacing(14),
                Text('holdings.basin_screen.review_filter'.tr(),
                    style: AppTextStyles.font12Bold
                        .copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.right),
                for (final BasinHoldingFilter option
                    in BasinHoldingFilter.values)
                  _SheetChoice(
                      label: _reviewLabel(option),
                      selected: review == option,
                      onTap: () => setState(() => review = option)),
                verticalSpacing(16),
                FilledButton(
                    onPressed: () => Navigator.pop(
                        context, _BasinFilterSelection(visibility, review)),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary200,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text('app_dialogs.confirm'.tr())),
              ]),
        ));
  }
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
            margin: const EdgeInsets.only(top: 7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary200.withValues(alpha: .12)
                    : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: <Widget>[
              Expanded(
                  child: Text(label,
                      style: AppTextStyles.font14SemiBold
                          .copyWith(color: colors.textPrimary),
                      textAlign: TextAlign.right)),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary200)
            ])));
  }
}

class _BasinFilterSelection {
  const _BasinFilterSelection(this.visibility, this.review);
  final ParcelVisibilityFilter visibility;
  final BasinHoldingFilter review;
}

String _visibilityLabel(final ParcelVisibilityFilter value) => switch (value) {
      ParcelVisibilityFilter.activeOnly =>
        'holdings.home.activity.filter_active'.tr(),
      ParcelVisibilityFilter.all => 'holdings.home.activity.filter_all'.tr(),
      ParcelVisibilityFilter.zeroAreaOnly =>
        'holdings.home.activity.filter_zero'.tr()
    };
String _reviewLabel(final BasinHoldingFilter value) => switch (value) {
      BasinHoldingFilter.all => 'holdings.basin_screen.filter_all'.tr(),
      BasinHoldingFilter.pending => 'holdings.basin_screen.filter_pending'.tr(),
      BasinHoldingFilter.completed =>
        'holdings.basin_screen.filter_completed'.tr()
    };
