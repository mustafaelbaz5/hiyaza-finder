import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cities/data/holding_row_mapper.dart';
import 'parcel_change_handler.dart';

/// Pure dispatch logic for incoming Supabase Realtime `postgres_changes`
/// payloads — extracted from `RealtimeSyncService` (which owns the actual
/// channel subscription/socket lifecycle) so this decision logic can be
/// unit-tested without a real or mocked `SupabaseClient`/`RealtimeChannel`.
/// `PostgresChangePayload` has a plain public constructor, which is what
/// makes that split possible.
class RealtimePayloadDispatcher {
  const RealtimePayloadDispatcher(this._handler);

  final ParcelChangeHandler _handler;

  void handleHoldingsPayload(final PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final dynamic id = payload.oldRecord['id'];
      if (id is String) _handler.applyRemoteDelete(id);
      return;
    }
    _handler.applyRemoteChange(holdingRowToParcel(payload.newRecord));
  }

  /// `added_holdings` needs one extra check `holdings`/`holding_edits`
  /// don't: `added_holdings_auto_approve` (a DB trigger) INSERTs a row here,
  /// then — in the same transaction — INSERTs the promoted copy into
  /// `holdings` and UPDATEs this row's `promoted_holding_id` to point at it.
  /// Each of those three writes fires its own Realtime event. Without this
  /// check, the client would end up showing BOTH the original
  /// `added_holdings` row (from its INSERT, before promotion) and the new
  /// `holdings` row (from the trigger's INSERT) as two separate people —
  /// exactly the "duplicate after adding a person" symptom this was added
  /// to fix. `downloadHoldings`'s initial fetch already filters to
  /// `promoted_holding_id is null` for the same reason (see
  /// `supabase_city_data_source.dart`); this mirrors that filter for the
  /// incremental Realtime stream. Once `promoted_holding_id` is set, this
  /// row is superseded — remove it rather than upsert it, same handling as
  /// a genuine DELETE.
  void handleAddedHoldingsPayload(final PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final dynamic id = payload.oldRecord['id'];
      if (id is String) _handler.applyRemoteDelete(id);
      return;
    }
    if (payload.newRecord['promoted_holding_id'] != null) {
      final dynamic id = payload.newRecord['id'];
      if (id is String) _handler.applyRemoteDelete(id);
      return;
    }
    _handler.applyRemoteChange(addedHoldingRowToParcel(payload.newRecord));
  }

  void handleHoldingEditPayload(final PostgresChangePayload payload) {
    final dynamic holdingId = payload.newRecord['holding_id'];
    final dynamic payloadJson = payload.newRecord['payload'];
    if (holdingId is String && payloadJson is Map<String, dynamic>) {
      _handler.applyRemoteEdit(holdingId, payloadJson);
    }
  }
}
