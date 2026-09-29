import 'package:equatable/equatable.dart';

/// Completion progress and activity counts for one basin.
class BasinProgress extends Equatable {
  const BasinProgress({
    required this.basinName,
    required this.totalCount,
    required this.completedCount,
    this.totalParcelCount = 0,
    this.activeParcelCount = 0,
    this.zeroAreaParcelCount = 0,
    this.activeHoldingCount = 0,
    this.activeCompletedCount = 0,
    this.basinCode,
  });

  final String basinName;
  final String? basinCode;

  /// All distinct holdings, retained for backwards-compatible summaries.
  final int totalCount;
  final int completedCount;

  /// All rows versus the operational subset used for area work.
  final int totalParcelCount;
  final int activeParcelCount;
  final int zeroAreaParcelCount;

  /// Completion is calculated from holdings with at least one active parcel.
  final int activeHoldingCount;
  final int activeCompletedCount;

  double get progress =>
      activeHoldingCount == 0 ? 0 : activeCompletedCount / activeHoldingCount;

  bool get isFullyCompleted =>
      activeHoldingCount > 0 && activeCompletedCount == activeHoldingCount;
  bool get isNotStarted => activeCompletedCount == 0;

  @override
  List<Object?> get props => <Object?>[
        basinName,
        basinCode,
        totalCount,
        completedCount,
        totalParcelCount,
        activeParcelCount,
        zeroAreaParcelCount,
        activeHoldingCount,
        activeCompletedCount,
      ];
}
