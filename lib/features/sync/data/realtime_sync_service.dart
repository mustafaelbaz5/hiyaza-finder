import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parcel_change_handler.dart';
import '../domain/realtime_payload_dispatcher.dart';

/// Subscribes to Supabase Realtime `postgres_changes` on `holdings`,
/// `holding_edits`, and `added_holdings` for the currently active city, and
/// patches incoming rows into [ParcelChangeHandler] rather than re-downloading
/// the city. See `supabase/migrations/20260804000015_enable_realtime.sql` for
/// the publication side of this — RLS (unchanged) governs what a
/// subscription can actually receive, same as a plain `SELECT`.
///
/// Only one city is ever active at a time (mirrors `HoldingsRepository`'s
/// one-city model — its `loadParcelsForCity` — the concrete
/// [ParcelChangeHandler] implementation in practice), so [subscribeToCity]
/// tears down any previous channel before opening the new one.
class RealtimeSyncService {
  /// Takes a getter rather than a [ParcelChangeHandler] directly: both
  /// the handler and this service are GetIt lazy singletons and each needs
  /// the other (this one to patch incoming rows in, the handler to open a
  /// subscription whenever the active city changes) — resolving one eagerly
  /// during the other's construction would recurse. The getter defers that
  /// lookup until a channel callback actually fires, by which point both
  /// singletons already exist.
  RealtimeSyncService(this._repositoryGetter, {final SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final ParcelChangeHandler Function() _repositoryGetter;
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  void subscribeToCity(final String cityId) {
    unsubscribe();

    final RealtimeChannel channel = _client.channel('city-$cityId-changes');

    final RealtimePayloadDispatcher dispatcher =
        RealtimePayloadDispatcher(_repositoryGetter());

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'holdings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'city_id',
        value: cityId,
      ),
      callback: dispatcher.handleHoldingsPayload,
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
      callback: dispatcher.handleAddedHoldingsPayload,
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
      callback: dispatcher.handleHoldingEditPayload,
    );

    channel.subscribe(
      (final RealtimeSubscribeStatus status, final Object? error) {
        // supabase_flutter retries the underlying socket connection on its
        // own — this callback exists purely for visibility (there is no
        // logging framework in this app yet, see
        // FLUTTER_ARCHITECTURE_REFERENCE.md §15 item 6) rather than to
        // trigger a manual reconnect: a channelError/timedOut here doesn't
        // mean the app is broken, since every write already confirms
        // against the server directly (online-first, §5) — it only means
        // *other devices'* changes won't appear live until the socket
        // recovers, which the underlying client already does automatically.
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          debugPrint(
            'RealtimeSyncService: city-$cityId-changes subscription '
            '$status${error != null ? ' ($error)' : ''}',
          );
        }
      },
    );
    _channel = channel;
  }

  void unsubscribe() {
    final RealtimeChannel? channel = _channel;
    if (channel == null) return;
    _client.removeChannel(channel);
    _channel = null;
  }
}
