import 'package:equatable/equatable.dart';

import '../../data/models/parcel.dart';
import '../services/holding_search_service.dart';

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
    this.missingColumns = const <String>[],
    this.availableBasins = const <String>[],
    this.selectedBasin,
    this.needsAssociationConfirm = false,
    this.associationNameDraft,
  });

  factory HomeState.initial() => const HomeState(status: HomeStatus.loading);

  final HomeStatus status;
  final List<Parcel> parcels;
  final String query;
  final List<SearchResult> results;
  final String? errorMessage;
  final List<String> missingColumns;

  /// Distinct اسم الحوض values found in the loaded dataset, sorted.
  final List<String> availableBasins;

  /// The basin currently focused for search, or `null` for "all basins".
  final String? selectedBasin;

  /// Whether the just-loaded file's اسم الجمعية hasn't been confirmed yet
  /// and the UI should prompt for it.
  final bool needsAssociationConfirm;

  /// The derived (or previously confirmed) اسم الجمعية to pre-fill the
  /// confirmation sheet with.
  final String? associationNameDraft;

  int get holdingCount =>
      parcels.map((final Parcel p) => p.holdingId).toSet().length;

  HomeState copyWith({
    final HomeStatus? status,
    final List<Parcel>? parcels,
    final String? query,
    final List<SearchResult>? results,
    final String? errorMessage,
    final List<String>? missingColumns,
    final List<String>? availableBasins,
    final Object? selectedBasin = _unset,
    final bool? needsAssociationConfirm,
    final Object? associationNameDraft = _unset,
  }) {
    return HomeState(
      status: status ?? this.status,
      parcels: parcels ?? this.parcels,
      query: query ?? this.query,
      results: results ?? this.results,
      errorMessage: errorMessage,
      missingColumns: missingColumns ?? this.missingColumns,
      availableBasins: availableBasins ?? this.availableBasins,
      selectedBasin: identical(selectedBasin, _unset)
          ? this.selectedBasin
          : selectedBasin as String?,
      needsAssociationConfirm:
          needsAssociationConfirm ?? this.needsAssociationConfirm,
      associationNameDraft: identical(associationNameDraft, _unset)
          ? this.associationNameDraft
          : associationNameDraft as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    parcels,
    query,
    results,
    errorMessage,
    missingColumns,
    availableBasins,
    selectedBasin,
    needsAssociationConfirm,
    associationNameDraft,
  ];
}
