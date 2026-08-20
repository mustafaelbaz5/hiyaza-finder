import 'package:equatable/equatable.dart';
import '../../data/local/holding_search_service.dart';
import '../../data/model/parcel.dart';

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
    this.modifiedIds = const <String>{},
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

  /// `Parcel.id`s with a local edit-overlay entry
  /// (`HoldingsRepository.isParcelEdited`) — snapshotted into state
  /// (rather than queried per-build from the repository) so
  /// [modifiedCount] is a plain `Equatable`-comparable field like every
  /// other count here. Populated by `HomeCubit` alongside [parcels]
  /// whenever the dataset is (re)loaded.
  final Set<String> modifiedIds;

  /// Raw parcel row count for the loaded dataset — a single حيازة can span
  /// several قطع, so this counts every parcel row, not distinct holdings
  /// (matches the "downloaded cities" screen's `CachedCityMeta.parcelsCount`).
  int get holdingCount => parcels.length;

  /// Parcel-row counts by status, for the home screen's lightweight summary
  /// cards (`REFACTOR_ROADMAP.md` Phase 7/9, `PROJECT_OBJECTIVES.md` §4's
  /// "original / modified / added / reviewed counts" — "reviewed" there
  /// means field-worker completion, now tracked via `Parcel.completedAt`,
  /// not the staff/Dashboard-only `reviewed` column — see
  /// `REFACTOR_ROADMAP.md` Phase 9 #12). Counts parcel rows, matching
  /// [holdingCount]'s convention — not distinct holdings. There is no
  /// separate "original" count: it's just `holdingCount - addedCount`, not
  /// independently useful enough to a field worker to warrant its own card
  /// (`REFACTOR_ROADMAP.md` Phase 9 #13 — deliberately kept lightweight,
  /// not a drill-down/filterable activity center).
  int get addedCount =>
      parcels.where((final Parcel p) => p.isFieldAdded).length;

  int get completedCount =>
      parcels.where((final Parcel p) => p.completedAt != null).length;

  int get pendingCompletionCount => parcels.length - completedCount;

  int get modifiedCount =>
      parcels.where((final Parcel p) => modifiedIds.contains(p.id)).length;

  HomeState copyWith({
    final HomeStatus? status,
    final List<Parcel>? parcels,
    final String? query,
    final List<SearchResult>? results,
    final String? errorMessage,
    final List<String>? availableBasins,
    final Object? selectedBasin = _unset,
    final Set<String>? modifiedIds,
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
      modifiedIds: modifiedIds ?? this.modifiedIds,
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
        modifiedIds,
      ];
}
