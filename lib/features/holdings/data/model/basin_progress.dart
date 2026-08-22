import 'package:equatable/equatable.dart';

/// Completion progress for one اسم الحوض — how many of its holdings are
/// fully field-worker-completed out of the total. Drives the basin-first
/// home screen's progress cards (`BasinCard`/`BasinProgressBar`).
class BasinProgress extends Equatable {
  const BasinProgress({
    required this.basinName,
    required this.totalCount,
    required this.completedCount,
  });

  final String basinName;

  /// Distinct holdings in this basin (by `Parcel.groupKey`, not raw
  /// `holdingId` — see `ParcelQueryService.basinHoldingCounts`'s doc for
  /// why pending records need grouping by key, not the raw id).
  final int totalCount;

  /// Holdings whose every parcel is `Parcel.completedAt`-set.
  final int completedCount;

  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  bool get isFullyCompleted => totalCount > 0 && completedCount == totalCount;
  bool get isNotStarted => completedCount == 0;

  @override
  List<Object?> get props => <Object?>[basinName, totalCount, completedCount];
}
