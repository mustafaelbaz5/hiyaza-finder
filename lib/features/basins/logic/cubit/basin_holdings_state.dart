import 'package:equatable/equatable.dart';

import '../../../cities/data/model/basin.dart';
import '../../../parcel_catalog/data/local/holding_search_service.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/model/parcel_activity_summary.dart';
import '../../../parcel_catalog/data/model/parcel_visibility_filter.dart';
import '../../data/model/basin_holding_filter.dart';

/// Immutable data rendered by one basin's parcel screen.
class BasinHoldingsState extends Equatable {
  const BasinHoldingsState({
    required this.basinName,
    this.basin,
    this.filter = BasinHoldingFilter.all,
    this.visibility = ParcelVisibilityFilter.activeOnly,
    this.activitySummary = const ParcelActivitySummary(),
    this.basinParcels = const <Parcel>[],
    this.visibleBasinParcels = const <Parcel>[],
    this.allResults = const <SearchResult>[],
    this.visibleResults = const <SearchResult>[],
    this.groupsByKey = const <String, List<Parcel>>{},
  });

  final String basinName;
  final Basin? basin;
  final BasinHoldingFilter filter;
  final ParcelVisibilityFilter visibility;
  final ParcelActivitySummary activitySummary;

  /// Every stored row in the basin, retained for actions such as export.
  final List<Parcel> basinParcels;

  /// Rows after the active/all/zero-area visibility choice.
  final List<Parcel> visibleBasinParcels;
  final List<SearchResult> allResults;
  final List<SearchResult> visibleResults;
  final Map<String, List<Parcel>> groupsByKey;

  int get completedHoldingCount => allResults
      .where((final SearchResult result) =>
          result.parcelCount > 0 && result.completedCount >= result.parcelCount)
      .length;

  int get activeHoldingCount => groupsByKey.length;

  @override
  List<Object?> get props => <Object?>[
        basinName,
        basin,
        filter,
        visibility,
        activitySummary,
        basinParcels,
        visibleBasinParcels,
        allResults,
        visibleResults,
        groupsByKey,
      ];
}
