import '../../holdings/domain/entities/parcel.dart';

/// Contract for applying incoming Supabase Realtime changes to the active
/// city's dataset. [RealtimeSyncService] depends on this interface rather
/// than [HoldingsRepository] directly, so a future feature needing its own
/// realtime handling can implement this contract without
/// [RealtimeSyncService] growing another hardcoded call.
abstract class ParcelChangeHandler {
  /// Applies an INSERT/UPDATE event for [updated] to the active dataset.
  void applyRemoteChange(final Parcel updated);

  /// Merges a `holding_edits` INSERT event's [payload] onto [holdingId]'s
  /// current value.
  void applyRemoteEdit(final String holdingId, final Map<String, dynamic> payload);

  /// Removes the parcel identified by [id] from the active dataset.
  void applyRemoteDelete(final String id);
}
