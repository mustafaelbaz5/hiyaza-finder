import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../domain/entities/sync_operation.dart';
import '../domain/repositories/sync_api.dart';

/// The only file that writes `holding_edits`/`added_holdings` for the
/// sync flow. A Postgrest `23505` (unique-violation) on any of these
/// inserts means "already applied by an earlier attempt" — per
/// `client_op_id`/`client_id` idempotency — and is treated as success,
/// not an error.
class SupabaseSyncApi implements SyncApi {
  SupabaseSyncApi(this._client);

  final SupabaseClient _client;

  /// A single insert that hangs on a flaky connection would otherwise block
  /// the whole flush (and, for `pushBulkEdit`, every remaining row) with no
  /// upper bound — bounding it turns a stuck connection into a normal
  /// retry-next-flush case instead of a long hang, and produces a
  /// `TimeoutException` rather than a raw `ClientException`/
  /// `HandshakeException` surfacing verbatim in the sync sheet.
  static const Duration _requestTimeout = Duration(seconds: 15);

  bool _isDuplicate(final Object error) => error is PostgrestException && error.code == '23505';

  @override
  Future<void> pushEditHolding(
    final EditHoldingOperation operation, {
    required final String editedByUserId,
  }) async {
    try {
      await _client.from('holding_edits').insert(<String, dynamic>{
        'holding_id': operation.holdingId,
        'city_id': operation.cityId,
        'payload': operation.payload,
        'edited_by': editedByUserId,
        'client_edited_at': operation.createdAt.toIso8601String(),
        'client_op_id': operation.id,
      }).timeout(_requestTimeout);
    } catch (error) {
      if (_isDuplicate(error)) return;
      ErrorHandler.handleException(error);
    }
  }

  @override
  Future<void> pushBulkEdit(
    final BulkEditOperation operation, {
    required final String editedByUserId,
  }) async {
    // Each row's own client_op_id makes it independently idempotent, so a
    // retry after a partial failure only re-inserts the rows that didn't
    // land last time — the ones that did just report a duplicate.
    for (final BulkEditRow row in operation.rows) {
      try {
        await _client.from('holding_edits').insert(<String, dynamic>{
          'holding_id': row.holdingId,
          'city_id': operation.cityId,
          'payload': row.payload,
          'edited_by': editedByUserId,
          'client_edited_at': operation.createdAt.toIso8601String(),
          'client_op_id': row.opId,
        }).timeout(_requestTimeout);
      } catch (error) {
        if (_isDuplicate(error)) continue;
        ErrorHandler.handleException(error);
      }
    }
  }

  @override
  Future<void> pushAddRecord(
    final AddRecordOperation operation, {
    required final String createdByUserId,
  }) async {
    try {
      await _client.from('added_holdings').insert(<String, dynamic>{
        // The row's primary key is the app's own client-generated id (same
        // one already used as `Parcel.id` and `client_id`) rather than a
        // fresh server-generated uuid — keeps the id stable across app,
        // database, and `holding_edits.holding_id` from creation onward.
        'id': operation.id,
        ...operation.record,
        'city_id': operation.cityId,
        'client_id': operation.id,
        'parent_holding_id': operation.parentHoldingId,
        'created_by': createdByUserId,
      }).timeout(_requestTimeout);
    } catch (error) {
      if (_isDuplicate(error)) return;
      ErrorHandler.handleException(error);
    }
  }
}
