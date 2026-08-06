import 'package:equatable/equatable.dart';

import '../../domain/entities/parcel.dart';
import '../../domain/services/holding_search_service.dart';

enum HomeStatus { loading, noFile, loaded, error }

/// Sentinel used by [HomeState.copyWith] so `selectedBasin` can be
/// explicitly set to `null` (meaning "focus on all basins") instead of
/// `null` always meaning "leave the current value unchanged".
const Object _unset = Object();

class HomeState extends Equatable {
  const HomeState({
    required this.status,
    this.parcels = const <Parcel>[],
    this.query = '',
    this.results = const <SearchResult>[],
    this.errorMessage,
    this.availableBasins = const <String>[],
    this.selectedBasin,
    this.isCityDataStale = false,
  });

  factory HomeState.initial() => const HomeState(status: HomeStatus.loading);

  final HomeStatus status;
  final List<Parcel> parcels;
  final String query;
  final List<SearchResult> results;
  final String? errorMessage;

  /// Distinct اسم الحوض values found in the loaded dataset, sorted.
  final List<String> availableBasins;

  /// The basin currently focused for search, or `null` for "all basins".
  final String? selectedBasin;

  /// Whether the server has newer data for the active city than what's
  /// cached locally — drives a non-blocking "تحديث البيانات" banner.
  final bool isCityDataStale;

  /// Raw parcel row count for the loaded dataset — a single حيازة can span
  /// several قطع, so this counts every parcel row, not distinct holdings
  /// (matches the "downloaded cities" screen's `CachedCityMeta.parcelsCount`).
  int get holdingCount => parcels.length;

  /// Parcel-row counts by status, for the home screen's lightweight summary
  /// cards (`REFACTOR_ROADMAP.md` Phase 7, `PROJECT_OBJECTIVES.md` §4's
  /// "original / modified / added / reviewed counts"). Counts parcel rows,
  /// matching [holdingCount]'s convention — not distinct holdings.
  int get addedCount =>
      parcels.where((final Parcel p) => p.isFieldAdded).length;

  int get reviewedCount => parcels.where((final Parcel p) => p.reviewed).length;

  int get pendingReviewCount => parcels.length - reviewedCount;

  HomeState copyWith({
    final HomeStatus? status,
    final List<Parcel>? parcels,
    final String? query,
    final List<SearchResult>? results,
    final String? errorMessage,
    final List<String>? availableBasins,
    final Object? selectedBasin = _unset,
    final bool? isCityDataStale,
  }) {
    return HomeState(
      status: status ?? this.status,
      parcels: parcels ?? this.parcels,
      query: query ?? this.query,
      results: results ?? this.results,
      errorMessage: errorMessage,
      availableBasins: availableBasins ?? this.availableBasins,
      selectedBasin: identical(selectedBasin, _unset)
          ? this.selectedBasin
          : selectedBasin as String?,
      isCityDataStale: isCityDataStale ?? this.isCityDataStale,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        parcels,
        query,
        results,
        errorMessage,
        availableBasins,
        selectedBasin,
        isCityDataStale,
      ];
}
