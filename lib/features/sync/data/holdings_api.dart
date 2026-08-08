import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/errors/exceptions.dart';

/// The single seam between "what Supabase call does this write make" and
/// "when it's invoked" — every write in the app goes through here,
/// directly and synchronously (awaited), with no local-first deferral or
/// retry queue: online-first means a failed call throws (via
/// [ErrorHandler.handleException]) straight back to the caller, which is
/// responsible for showing the failure and letting the user retry.
class HoldingsApi {
  HoldingsApi(this._client);

  final SupabaseClient _client;

  /// A hung request would otherwise block the calling UI action
  /// indefinitely — bounding it turns a stuck connection into a normal,
  /// user-visible failure instead of a silent freeze, and produces a
  /// `TimeoutException` rather than a raw `ClientException`/
  /// `HandshakeException` surfacing verbatim in a snackbar.
  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<void> editHolding({
    required final String holdingId,
    required final String cityId,
    required final Map<String, dynamic> payload,
    required final String editedByUserId,
  }) async {
    try {
      await _client.from('holding_edits').insert(<String, dynamic>{
        'holding_id': holdingId,
        'city_id': cityId,
        'payload': payload,
        'edited_by': editedByUserId,
        'client_edited_at': DateTime.now().toIso8601String(),
      }).timeout(_requestTimeout);
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  /// Applies [payloadsByHoldingId] one row at a time, continuing past a
  /// per-row failure rather than aborting the whole batch — a bulk edit
  /// spans many independent holdings, so one failure shouldn't silently
  /// discard progress already made on the rest. Returns the ids that
  /// failed, for the caller to report a succeeded/failed count.
  Future<List<String>> bulkEditHoldings({
    required final String cityId,
    required final Map<String, Map<String, dynamic>> payloadsByHoldingId,
    required final String editedByUserId,
  }) async {
    final List<String> failedIds = <String>[];
    final String editedAt = DateTime.now().toIso8601String();
    for (final MapEntry<String, Map<String, dynamic>> entry
        in payloadsByHoldingId.entries) {
      try {
        await _client.from('holding_edits').insert(<String, dynamic>{
          'holding_id': entry.key,
          'city_id': cityId,
          'payload': entry.value,
          'edited_by': editedByUserId,
          'client_edited_at': editedAt,
        }).timeout(_requestTimeout);
      } catch (_) {
        failedIds.add(entry.key);
      }
    }
    return failedIds;
  }

  /// Returns the `added_holdings.promoted_holding_id` of the row just
  /// inserted, if the DB trigger `added_holdings_auto_approve` already
  /// promoted it into `holdings` by the time this INSERT returns — `null`
  /// if it hasn't been promoted (shouldn't happen given the trigger fires
  /// unconditionally on insert today, but callers must not assume it).
  ///
  /// Selecting the row back in the same round-trip (rather than just
  /// awaiting a bare insert) is what lets the caller learn about the
  /// promotion immediately, instead of waiting on separate Realtime events
  /// for the `added_holdings` INSERT, the trigger's `holdings` INSERT, and
  /// the trigger's `added_holdings` UPDATE to all arrive and reconcile —
  /// three independent async round-trips that previously left the newly
  /// added record visible under its pre-promotion id for a window before
  /// disappearing and reappearing under its promoted id.
  Future<String?> addRecord({
    required final String id,
    required final String cityId,
    required final Map<String, dynamic> record,
    required final String? parentHoldingId,
    required final String createdByUserId,
  }) async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('added_holdings').insert(<String, dynamic>{
        // The row's primary key is the app's own client-generated id (same
        // one already used as `Parcel.id` and `client_id`) rather than a
        // fresh server-generated uuid — keeps the id stable across app,
        // database, and `holding_edits.holding_id` from creation onward.
        'id': id,
        ...record,
        'city_id': cityId,
        'client_id': id,
        'parent_holding_id': parentHoldingId,
        'created_by': createdByUserId,
      }).select('promoted_holding_id').timeout(_requestTimeout);
      return rows.isEmpty ? null : rows.first['promoted_holding_id'] as String?;
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  Future<void> deleteAddedHolding(final String id) async {
    try {
      await _client.from('added_holdings').delete().eq('id', id).timeout(_requestTimeout);
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  /// Live server-side search fallback for [cityId] — matches [query]
  /// against رقم الحيازة (exact) or حائز/مالك name (`ilike` contains) across
  /// both `holdings` and `added_holdings`. Called *in addition to* the
  /// primary local cache search (`REFACTOR_ROADMAP.md` Phase 9 #7), never
  /// instead of it: the local city snapshot remains the fast, offline-first
  /// primary path; this only catches records synced to the server after the
  /// device's last download, which the local cache can't see yet. Returns
  /// raw rows per table so the caller can map each with the correct mapper
  /// (`holdingRowToParcel`/`addedHoldingRowToParcel`) — kept out of this
  /// data-source class to avoid a `cities`-feature import here.
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({
    required final String cityId,
    required final String query,
  }) async {
    try {
      final List<Map<String, dynamic>> holdingsRows = await _client
          .from('holdings')
          .select()
          .eq('city_id', cityId)
          .or('holding_id_number.eq.$query,holder_name.ilike.%$query%')
          .limit(20)
          .timeout(_requestTimeout);
      final List<Map<String, dynamic>> addedRows = await _client
          .from('added_holdings')
          .select()
          .eq('city_id', cityId)
          .isFilter('promoted_holding_id', null)
          .or('holding_id_number.eq.$query,holder_name.ilike.%$query%')
          .limit(20)
          .timeout(_requestTimeout);
      return (holdings: holdingsRows, addedHoldings: addedRows);
    } catch (_) {
      // A failed live search must never break the local results already on
      // screen — the caller treats this as "no remote results found",
      // exactly like being offline.
      return (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);
    }
  }

  /// Sets/clears field-worker completion (`completed_at`/`completed_by`) —
  /// distinct from `reviewed`/`reviewed_at`/`reviewed_by`, which this app
  /// never writes (staff/Dashboard-only, `SYSTEM_DESIGN.md` §10,
  /// `REFACTOR_ROADMAP.md` Phase 9 #12).
  ///
  /// Goes through the `mark_parcel_completed` RPC (`REFACTOR_ROADMAP.md`
  /// Phase 19) rather than a direct table `UPDATE`, for two reasons:
  /// - `holdings_write` RLS only allows admin/editor, and
  ///   `added_holdings_update_own` only covers rows still `status =
  ///   'pending'` (a narrow window — `auto_approve_added_holding` promotes
  ///   almost immediately) — a field-role user had no RLS path to write
  ///   these two columns on a promoted `holdings` row at all. The RPC is
  ///   `security definer`, scoped to exactly `completed_at`/`completed_by`.
  /// - Marking completed ([completed] `true`) needs to be conditioned on
  ///   `completed_at is null` — the one place two devices can genuinely
  ///   race each other over the same parcel: both might read "not yet
  ///   reviewed" locally, then both call this within the same window. The
  ///   RPC does the condition-then-update atomically in one transaction,
  ///   closing the race window a client-side check-then-update from
  ///   PostgREST (`.eq(...).isFilter(...).select()`) would still have.
  ///   Losing that race throws [ConflictException] instead of silently
  ///   succeeding, so the caller can tell that user their action didn't
  ///   actually take effect.
  ///
  /// Reopening ([completed] `false`) stays unconditional — it's a
  /// single-actor, user-initiated undo (`DetailScreen._reopenParcel`'s own
  /// doc), not a race two devices are plausibly both attempting on the same
  /// parcel at once the way "mark reviewed" is.
  Future<void> markCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final DateTime? completedAt,
    required final String completedByUserId,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _client.rpc(
        'mark_parcel_completed',
        params: <String, dynamic>{
          'p_parcel_id': parcelId,
          'p_is_field_added': isFieldAdded,
          'p_completed': completed,
        },
      ).timeout(_requestTimeout);

      final Map<String, dynamic> result = rows.first;
      if (completed && result['conflict'] == true) {
        throw ConflictException(
          message: 'This parcel was already marked reviewed by another user.',
        );
      }
    } on ConflictException {
      rethrow;
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  /// Resolves `profiles.email` for a set of `profiles.id` uuids — used to
  /// show "تمت الإضافة بواسطة: user@email.com" on an added-parcel badge
  /// (`REFACTOR_ROADMAP.md` Phase 11 §12, `Parcel.createdBy`). Returns an
  /// empty map (never throws) on failure — a missing creator email is a
  /// cosmetic gap, not worth surfacing as an error to the field worker.
  Future<Map<String, String>> fetchProfileEmails(
    final Iterable<String> profileIds,
  ) async {
    final List<String> ids = profileIds.toSet().toList();
    if (ids.isEmpty) return const <String, String>{};
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('profiles')
          .select('id, email')
          .inFilter('id', ids)
          .timeout(_requestTimeout);
      return <String, String>{
        for (final Map<String, dynamic> row in rows)
          row['id'] as String: row['email'] as String,
      };
    } catch (_) {
      return const <String, String>{};
    }
  }
}
