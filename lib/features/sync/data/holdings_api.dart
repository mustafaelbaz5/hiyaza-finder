import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';

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

  Future<void> addRecord({
    required final String id,
    required final String cityId,
    required final Map<String, dynamic> record,
    required final String? parentHoldingId,
    required final String createdByUserId,
  }) async {
    try {
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
      }).timeout(_requestTimeout);
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

  Future<void> markReviewed({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool reviewed,
    required final DateTime? reviewedAt,
    required final String reviewedByUserId,
  }) async {
    final String table = isFieldAdded ? 'added_holdings' : 'holdings';
    try {
      await _client.from(table).update(<String, dynamic>{
        'reviewed': reviewed,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'reviewed_by': reviewed ? reviewedByUserId : null,
      }).eq('id', parcelId).timeout(_requestTimeout);
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }
}
