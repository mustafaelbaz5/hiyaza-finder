import 'package:equatable/equatable.dart';

import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel_visibility_filter.dart';
import 'package:hiyaza_finder/features/parcel_search/data/local/holding_search_service.dart';

class ParcelSearchState extends Equatable {
  const ParcelSearchState({
    this.query = '',
    this.results = const <SearchResult>[],
    this.visibility = ParcelVisibilityFilter.activeOnly,
    this.zeroAreaMatchCount = 0,
  });

  final String query;
  final List<SearchResult> results;
  final ParcelVisibilityFilter visibility;

  /// Matching holding groups hidden by the active-only view. It lets the UI
  /// offer a safe reveal action instead of making reference records noisy.
  final int zeroAreaMatchCount;

  ParcelSearchState copyWith({
    final String? query,
    final List<SearchResult>? results,
    final ParcelVisibilityFilter? visibility,
    final int? zeroAreaMatchCount,
  }) =>
      ParcelSearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        visibility: visibility ?? this.visibility,
        zeroAreaMatchCount: zeroAreaMatchCount ?? this.zeroAreaMatchCount,
      );

  @override
  List<Object?> get props => <Object?>[
        query,
        results,
        visibility,
        zeroAreaMatchCount,
      ];
}
