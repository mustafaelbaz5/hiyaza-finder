import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../data/local/arabic_normalizer.dart';
import '../data/local/holding_search_service.dart';
import '../data/model/parcel.dart';
import '../data/repo/holdings_repository.dart';
import 'widgets/basin_filter_row.dart';
import 'widgets/recommendation_tile.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../../../core/widgets/screen_header.dart';

/// Lists every parcel whose رقم الحيازة is missing/lost data — blank, the
/// "-"/"-1" pending placeholders, or a literal "0" (see
/// [Parcel.isHoldingIdMissingOrZero]) — the field-worker worklist for going
/// back and filling in a real value, reachable from "أدوات المدينة". Reuses
/// [RecommendationTile] and the existing [Routes.holdingDetail] flow so
/// filling in the missing value uses the same field-edit UI as anywhere
/// else in the app.
class MissingHoldingIdScreen extends StatefulWidget {
  const MissingHoldingIdScreen({super.key});

  @override
  State<MissingHoldingIdScreen> createState() => _MissingHoldingIdScreenState();
}

class _MissingHoldingIdScreenState extends State<MissingHoldingIdScreen> {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String? _selectedBasin;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Parcel> get _missingParcels => _repository.parcels
      .where((final Parcel p) => p.isHoldingIdMissingOrZero)
      .toList();

  /// [Parcel.groupKey] treats a literal `"0"` رقم الحيازة as a normal,
  /// non-shared value (by design — see [Parcel.isHoldingIdMissingOrZero]),
  /// so grouping by it directly here would wrongly merge every unrelated
  /// person who happens to have `"0"` into one result. Falls back to the
  /// parcel's own [Parcel.id] for that one case; [Parcel.groupKey] already
  /// handles the pending-placeholder case (blank/"-"/"-1") correctly.
  String _worklistGroupKey(final Parcel parcel) =>
      parcel.holdingId.trim() == '0' ? parcel.id : parcel.groupKey;

  /// Keyed by [_worklistGroupKey] so [_openDetail] can look parcels up
  /// directly instead of going through `HoldingsRepository.parcelsForHolding`
  /// — that method matches on `Parcel.groupKey`, which (by design, see
  /// [Parcel.isHoldingIdMissingOrZero]'s doc) does NOT special-case a
  /// literal `"0"` رقم الحيازة, so it can't resolve the [Parcel.id]-based
  /// key this screen uses for that one case.
  Map<String, List<Parcel>> _groupsByKey = <String, List<Parcel>>{};

  List<SearchResult> _groupResults(final List<Parcel> parcels) {
    final Map<String, List<Parcel>> byGroup = <String, List<Parcel>>{};
    for (final Parcel parcel in parcels) {
      (byGroup[_worklistGroupKey(parcel)] ??= <Parcel>[]).add(parcel);
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

  void _openDetail(final SearchResult result) {
    final List<Parcel> parcels =
        _groupsByKey[result.groupKey] ?? const <Parcel>[];
    context.pushNamed(Routes.holdingDetail, arguments: parcels);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final List<Parcel> missing = _missingParcels;
    final List<String> basins = missing
        .map((final Parcel p) => p.basinName)
        .whereType<String>()
        .where((final String b) => b.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    List<Parcel> filtered = missing;
    if (_selectedBasin != null) {
      filtered = filtered
          .where((final Parcel p) => p.basinName == _selectedBasin)
          .toList();
    }
    if (_query.trim().isNotEmpty) {
      final String normalizedQuery =
          ArabicNormalizer.normalizeForSearch(_query);
      filtered = filtered.where((final Parcel p) {
        final String? name = p.holderName;
        if (name != null &&
            ArabicNormalizer.normalizeForSearch(name)
                .contains(normalizedQuery)) {
          return true;
        }
        return p.id.toLowerCase().contains(_query.trim().toLowerCase());
      }).toList();
    }

    final List<SearchResult> results = _groupResults(filtered)
      ..sort((final SearchResult a, final SearchResult b) =>
          (a.holderName ?? '').compareTo(b.holderName ?? ''));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(title: 'cities.tools.missing_holding_id.title'.tr()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomTextForm(
                    hintText:
                        'cities.tools.missing_holding_id.search_hint'.tr(),
                    controller: _searchController,
                    isRTL: true,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colors.iconSecondary,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: colors.iconSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    onChanged: (final String value) =>
                        setState(() => _query = value),
                  ),
                  if (basins.isNotEmpty) ...[
                    verticalSpacing(10),
                    BasinFilterRow(
                      basins: basins,
                      selected: _selectedBasin,
                      onChanged: (final String? basin) =>
                          setState(() => _selectedBasin = basin),
                    ),
                  ],
                  verticalSpacing(8),
                  if (missing.isNotEmpty)
                    Text(
                      'cities.tools.missing_holding_id.results_count'.tr(
                        namedArgs: {'count': results.length.toString()},
                      ),
                      style: AppTextStyles.font12Regular
                          .copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.right,
                    ),
                ],
              ),
            ),
            verticalSpacing(8),
            Expanded(
              child: missing.isEmpty
                  ? const _EmptyState()
                  : results.isEmpty
                      ? const _NoResultsState()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: rw(16))
                              .copyWith(bottom: rh(24)),
                          itemCount: results.length,
                          itemBuilder:
                              (final BuildContext context, final int i) {
                            final SearchResult result = results[i];
                            return RecommendationTile(
                              result: result,
                              onTap: () => _openDetail(result),
                              animationDelay: Duration(milliseconds: i * 30),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: colors.success,
            ),
            const SizedBox(height: 16),
            Text(
              'cities.tools.missing_holding_id.empty'.tr(),
              style: AppTextStyles.font16SemiBold
                  .copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'cities.tools.missing_holding_id.empty_hint'.tr(),
              style: AppTextStyles.font14Regular
                  .copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(final BuildContext context) {
    return Center(
      child: Text(
        'cities.tools.missing_holding_id.no_results'.tr(),
        style: AppTextStyles.font14Regular
            .copyWith(color: context.customColors.textHint),
      ),
    );
  }
}
