import 'package:equatable/equatable.dart';

class SyncStatusState extends Equatable {
  const SyncStatusState({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.isSyncing = false,
    this.isOffline = false,
  });

  final int pendingCount;

  /// Operations that hit `syncMaxAttempts` and are parked — still counted
  /// in [pendingCount] too, but surfaced separately so the badge can show
  /// "couldn't sync" instead of implying these are still being retried.
  final int failedCount;
  final bool isSyncing;

  /// Whether the device currently has no internet connection, per
  /// `NetworkInfo.onStatusChange` — tracked so the badge can show "waiting
  /// for internet" instead of a generic "pending" count while there's
  /// nothing this device can do about it but wait for connectivity.
  final bool isOffline;

  bool get hasPending => pendingCount > 0;
  bool get hasFailed => failedCount > 0;

  SyncStatusState copyWith({
    final int? pendingCount,
    final int? failedCount,
    final bool? isSyncing,
    final bool? isOffline,
  }) {
    return SyncStatusState(
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  List<Object?> get props => <Object?>[pendingCount, failedCount, isSyncing, isOffline];
}
