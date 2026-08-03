import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cities/data/holding_row_mapper.dart';
import '../../holdings/data/repository/holdings_repository.dart';

/// Subscribes to Supabase Realtime `postgres_changes` on `holdings`,
/// `holding_edits`, and `added_holdings` for the currently active city, and
/// patches incoming rows into [HoldingsRepository] rather than re-downloading
/// the city. See `supabase/migrations/20260804000015_enable_realtime.sql` for
/// the publication side of this — RLS (unchanged) governs what a
/// subscription can actually receive, same as a plain `SELECT`.
///
/// Only one city is ever active at a time (mirrors
/// `HoldingsRepository.loadParcelsForCity`'s one-city model), so
/// [subscribeToCity] tears down any previous channel before opening the new
/// one.
class RealtimeSyncService {
  /// Takes a getter rather than a [HoldingsRepository] directly: both
  /// classes are GetIt lazy singletons and each needs the other (this one
  /// to patch incoming rows in, the repository to open a subscription
  /// whenever the active city changes) — resolving one eagerly during the
  /// other's construction would recurse. The getter defers that lookup
  /// until a channel callback actually fires, by which point both
  /// singletons already exist.
  RealtimeSyncService(this._repositoryGetter, {final SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final HoldingsRepository Function() _repositoryGetter;
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  void subscribeToCity(final String cityId) {
    unsubscribe();

    final RealtimeChannel channel = _client.channel('city-$cityId-changes');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'holdings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'city_id',
        value: cityId,
      ),
      callback: (final PostgresChangePayload payload) =>
          _handleHoldingsPayload(payload, holdingRowToParcel),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'added_holdings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'city_id',
        value: cityId,
      ),
      callback: (final PostgresChangePayload payload) =>
          _handleHoldingsPayload(payload, addedHoldingRowToParcel),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'holding_edits',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'city_id',
        value: cityId,
      ),
      callback: _handleHoldingEditPayload,
    );

    channel.subscribe();
    _channel = channel;
  }

  void _handleHoldingsPayload(
    final PostgresChangePayload payload,
    final dynamic Function(Map<String, dynamic>) mapRow,
  ) {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final dynamic id = payload.oldRecord['id'];
      if (id is String) _repositoryGetter().applyRemoteDelete(id);
      return;
    }
    _repositoryGetter().applyRemoteChange(mapRow(payload.newRecord));
  }

  void _handleHoldingEditPayload(final PostgresChangePayload payload) {
    final dynamic holdingId = payload.newRecord['holding_id'];
    final dynamic payloadJson = payload.newRecord['payload'];
    if (holdingId is String && payloadJson is Map<String, dynamic>) {
      _repositoryGetter().applyRemoteEdit(holdingId, payloadJson);
    }
  }

  void unsubscribe() {
    final RealtimeChannel? channel = _channel;
    if (channel == null) return;
    _client.removeChannel(channel);
    _channel = null;
  }
}
