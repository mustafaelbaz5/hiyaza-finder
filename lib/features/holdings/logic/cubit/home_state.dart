import 'package:equatable/equatable.dart';
import '../../data/local/holding_search_service.dart';
import '../../data/model/parcel.dart';

enum HomeStatus { loading, noFile, loaded, error }

class HomeState extends Equatable {
  const HomeState({
    required this.status,
    this.parcels = const <Parcel>[],
    this.query = '',
    this.results = const <SearchResult>[],
    this.allHoldings = const <SearchResult>[],
    this.errorMessage,
    this.modifiedIds = const <String>{},
  });

  factory HomeState.initial() => const HomeState(status: HomeStatus.loading);

  final HomeStatus status;
  final List<Parcel> parcels;
  final String query;
  final List<SearchResult> results;

  /// Every distinct holding, city-wide, unfiltered — Home's flat list
  /// (APP_CLAUDE.md § 9.1). Shown while [query] is empty; a non-empty
  /// [query] shows [results] instead.
  final List<SearchResult> allHoldings;

  final String? errorMessage;

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
    final List<SearchResult>? allHoldings,
    final String? errorMessage,
    final Set<String>? modifiedIds,
  }) {
    return HomeState(
      status: status ?? this.status,
      parcels: parcels ?? this.parcels,
      query: query ?? this.query,
      results: results ?? this.results,
      allHoldings: allHoldings ?? this.allHoldings,
      errorMessage: errorMessage,
      modifiedIds: modifiedIds ?? this.modifiedIds,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        parcels,
        query,
        results,
        allHoldings,
        errorMessage,
        modifiedIds,
      ];
}
