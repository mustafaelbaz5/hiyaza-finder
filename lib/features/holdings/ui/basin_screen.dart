import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../data/local/holding_search_service.dart';
import '../data/model/parcel.dart';
import '../data/repo/holdings_repository.dart';
import 'add_record_screen.dart';
import 'widgets/basin_info_card.dart';
import 'widgets/export_bottom_sheet.dart';
import 'widgets/recommendation_tile.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../cities/data/model/basin.dart';
import 'widgets/top_bar_icon_button.dart';

/// Which completion state the basin screen's holdings are filtered to.
enum BasinFilter { all, pending, completed }

/// Every حيازة in one حوض, sorted by رقم الحيازة ascending — the basin-first
/// home screen's drill-down target. Each card is one holding (not one
/// قطعة); a holding with more than one parcel still shows as a single card
/// with its parcel count, same as everywhere else search results group.
class BasinScreen extends StatefulWidget {
  const BasinScreen({super.key, required this.basinName});

  final String basinName;

  @override
  State<BasinScreen> createState() => _BasinScreenState();
}

class _BasinScreenState extends State<BasinScreen> {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();
  BasinFilter _filter = BasinFilter.all;

  Map<String, List<Parcel>> _groupsByKey = <String, List<Parcel>>{};

  List<Parcel> get _basinParcels => _repository.parcels
      .where((final Parcel p) => p.basinName == widget.basinName)
      .toList();

  List<SearchResult> _groupResults(final List<Parcel> parcels) {
    final Map<String, List<Parcel>> byGroup = <String, List<Parcel>>{};
    for (final Parcel parcel in parcels) {
      (byGroup[parcel.groupKey] ??= <Parcel>[]).add(parcel);
    }
    _groupsByKey = byGroup;

    return byGroup.entries.map((final MapEntry<String, List<Parcel>> entry) {
      final List<Parcel> group = entry.value;
      final Parcel first = group.first;
      final int completedCount =
          group.where((final Parcel p) => p.completedAt != null).length;
      return SearchResult(
        holdingId: first.holdingId,
        groupKey: entry.key,
        holderName: first.holderName,
        parcelCount: group.length,
        score: 0,
        completedCount: completedCount,
        isFieldAdded: first.isFieldAdded,
      );
    }).toList();
  }

  Future<void> _openDetail(final SearchResult result) async {
    final List<Parcel> parcels =
        _groupsByKey[result.groupKey] ?? const <Parcel>[];
    await context.pushNamed(Routes.holdingDetail, arguments: parcels);
    if (mounted) setState(() {});
  }

  Future<void> _addParcelForBasin() async {
    final Parcel? added = await context.pushNamed<Parcel?>(
      Routes.addRecord,
      arguments: AddRecordArgs(
        initialParcel: Parcel(
          holdingId: '',
          landNumber: '0',
          basinName: widget.basinName,
          holdingsCount: 1,
        ),
      ),
    );
    if (added != null && mounted) setState(() {});
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final List<Parcel> basinParcels = _basinParcels;
    final List<SearchResult> allResults = _groupResults(basinParcels)
      ..sort(
        (final SearchResult a, final SearchResult b) =>
            _holdingNumberValue(a.holdingId).compareTo(_holdingNumberValue(b.holdingId)),
      );

    final List<SearchResult> filtered = switch (_filter) {
      BasinFilter.all => allResults,
      BasinFilter.pending => allResults
          .where(
            (final SearchResult r) => r.completedCount < r.parcelCount,
          )
          .toList(),
      BasinFilter.completed => allResults
          .where(
            (final SearchResult r) =>
                r.parcelCount > 0 && r.completedCount >= r.parcelCount,
          )
          .toList(),
    };

    final int completedHoldings = allResults
        .where(
          (final SearchResult r) => r.parcelCount > 0 && r.completedCount >= r.parcelCount,
        )
        .length;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16), vertical: rh(12)),
              child: Row(
                children: [
                  const AppBackButton(),
                  horizontalSpacing(12),
                  Expanded(
                    child: Text(
                      widget.basinName,
                      style: AppTextStyles.font20Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$completedHoldings/${allResults.length}',
                    style: AppTextStyles.font16Bold.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  horizontalSpacing(4),
                  TopBarIconButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'holdings.export.title'.tr(),
                    onTap: () => showExportBottomSheet(
                      context,
                      basinName: widget.basinName,
                      basinParcels: basinParcels,
                    ),
                  ),
                ],
              ),
            ),
            BasinInfoCard(
              basin: _repository.activeBasins
                  .cast<Basin?>()
                  .firstWhere((final Basin? b) => b?.basinName == widget.basinName, orElse: () => null),
            ),
            verticalSpacing(8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16)),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterChip(
                      label: 'holdings.basin_screen.filter_all'.tr(),
                      isSelected: _filter == BasinFilter.all,
                      onTap: () => setState(() => _filter = BasinFilter.all),
                    ),
                  ),
                  horizontalSpacing(8),
                  Expanded(
                    child: _FilterChip(
                      label: 'holdings.basin_screen.filter_pending'.tr(),
                      isSelected: _filter == BasinFilter.pending,
                      onTap: () => setState(() => _filter = BasinFilter.pending),
                    ),
                  ),
                  horizontalSpacing(8),
                  Expanded(
                    child: _FilterChip(
                      label: 'holdings.basin_screen.filter_completed'.tr(),
                      isSelected: _filter == BasinFilter.completed,
                      onTap: () => setState(() => _filter = BasinFilter.completed),
                    ),
                  ),
                ],
              ),
            ),
            verticalSpacing(8),
            Expanded(
              child: Stack(
                children: [
                  filtered.isEmpty
                      ? Center(
                          child: Text(
                            'holdings.basin_screen.empty'.tr(),
                            style: AppTextStyles.font14Regular
                                .copyWith(color: colors.textHint),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: rw(16))
                              .copyWith(bottom: rh(80)),
                          itemCount: filtered.length,
                          itemBuilder: (final BuildContext context, final int i) {
                            final SearchResult result = filtered[i];
                            return RecommendationTile(
                              result: result,
                              onTap: () => _openDetail(result),
                              animationDelay: Duration(milliseconds: i * 20),
                            );
                          },
                        ),
                  PositionedDirectional(
                    bottom: rh(16),
                    end: rw(16),
                    child: FloatingActionButton.extended(
                      onPressed: _addParcelForBasin,
                      backgroundColor: AppColors.primary200,
                      foregroundColor: AppColors.white,
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: Text('holdings.add.new_parcel_title'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Numeric holdings sort before non-numeric ones (pending placeholders
  /// like "-"/"-1"/"" sort last, matching APP_CLAUDE.md's mockup order).
  double _holdingNumberValue(final String holdingId) {
    final double? parsed = double.tryParse(holdingId.trim());
    return parsed ?? double.infinity;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary200 : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.font12Bold.copyWith(
            color: isSelected ? AppColors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
