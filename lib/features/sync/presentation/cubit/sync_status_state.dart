import 'package:equatable/equatable.dart';

class SyncStatusState extends Equatable {
  const SyncStatusState({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.isSyncing = false,
  });

  final int pendingCount;

  /// Operations that hit `syncMaxAttempts` and are parked — still counted
  /// in [pendingCount] too, but surfaced separately so the badge can show
  /// "couldn't sync" instead of implying these are still being retried.
  final int failedCount;
  final bool isSyncing;

  bool get hasPending => pendingCount > 0;
  bool get hasFailed => failedCount > 0;

  SyncStatusState copyWith({
    final int? pendingCount,
    final int? failedCount,
    final bool? isSyncing,
  }) {
    return SyncStatusState(
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => <Object?>[pendingCount, failedCount, isSyncing];
}
