import 'package:equatable/equatable.dart';

import '../../../cities/data/model/basin.dart';
import '../../../parcel_catalog/data/local/holding_search_service.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../data/model/basin_holding_filter.dart';

/// Immutable data rendered by one basin's holdings screen.
class BasinHoldingsState extends Equatable {
  const BasinHoldingsState({
    required this.basinName,
    this.basin,
    this.filter = BasinHoldingFilter.all,
    this.basinParcels = const <Parcel>[],
    this.allResults = const <SearchResult>[],
    this.visibleResults = const <SearchResult>[],
    this.groupsByKey = const <String, List<Parcel>>{},
  });

  final String basinName;
  final Basin? basin;
  final BasinHoldingFilter filter;
  final List<Parcel> basinParcels;
  final List<SearchResult> allResults;
  final List<SearchResult> visibleResults;
  final Map<String, List<Parcel>> groupsByKey;

  int get completedHoldingCount => allResults
      .where((final SearchResult result) =>
          result.parcelCount > 0 && result.completedCount >= result.parcelCount)
      .length;

  @override
  List<Object?> get props => <Object?>[
        basinName,
        basin,
        filter,
        basinParcels,
        allResults,
        visibleResults,
        groupsByKey,
      ];
}
