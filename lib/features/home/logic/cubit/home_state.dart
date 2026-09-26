import 'package:equatable/equatable.dart';
import 'package:hiyaza_finder/features/cities/data/model/association_type.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

enum HomeStatus { loading, noFile, loaded, error }

class HomeState extends Equatable {
  const HomeState({
    required this.status,
    this.parcels = const <Parcel>[],
    this.errorMessage,
    this.modifiedIds = const <String>{},
    this.cityName,
    this.associationType,
  });

  factory HomeState.initial() => const HomeState(status: HomeStatus.loading);

  final HomeStatus status;
  final List<Parcel> parcels;
  final String? errorMessage;

  /// `Parcel.id`s with a local edit-overlay entry
  /// (`ParcelCatalogRepository.isParcelEdited`) — snapshotted into state
  /// (rather than queried per-build from the repository) so
  /// [modifiedCount] is a plain `Equatable`-comparable field like every
  /// other count here. Populated by `HomeCubit` alongside [parcels]
  /// whenever the dataset is (re)loaded.
  final Set<String> modifiedIds;
  final String? cityName;
  final AssociationType? associationType;

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
    final String? errorMessage,
    final Set<String>? modifiedIds,
    final String? cityName,
    final AssociationType? associationType,
  }) {
    return HomeState(
      status: status ?? this.status,
      parcels: parcels ?? this.parcels,
      errorMessage: errorMessage,
      modifiedIds: modifiedIds ?? this.modifiedIds,
      cityName: cityName ?? this.cityName,
      associationType: associationType ?? this.associationType,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        parcels,
        errorMessage,
        modifiedIds,
        cityName,
        associationType,
      ];
}
