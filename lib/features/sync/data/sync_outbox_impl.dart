import 'dart:async';
import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/entities/sync_operation.dart';
import '../domain/repositories/sync_queue.dart';

/// Local outbox backed by [KeyValueStore] — the whole queue is a handful
/// of pending operations at most (unlike a city snapshot's thousands of
/// rows), so `SharedPreferences`-backed storage is the right weight for
/// it, same as the small per-parcel edit overlay (`ParcelEditsStore`).
class SyncOutboxImpl implements SyncQueue {
  SyncOutboxImpl(this._keyValueStore);

  static const String _key = 'sync_outbox';

  final KeyValueStore _keyValueStore;
  final StreamController<int> _countController = StreamController<int>.broadcast();

  @override
  Stream<int> get pendingCountChanges => _countController.stream;

  Future<List<SyncOperation>> _readAll() async {
    final String? raw = await _keyValueStore.getString(_key);
    if (raw == null || raw.isEmpty) return <SyncOperation>[];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (final dynamic e) => SyncOperation.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _writeAll(final List<SyncOperation> operations) async {
    if (operations.isEmpty) {
      await _keyValueStore.remove(_key);
    } else {
      await _keyValueStore.setString(
        _key,
        jsonEncode(
          operations.map((final SyncOperation o) => o.toJson()).toList(),
        ),
      );
    }
    if (!_countController.isClosed) _countController.add(operations.length);
  }

  @override
  Future<void> enqueue(final SyncOperation operation) async {
    final List<SyncOperation> ops = await _readAll()
      ..add(operation);
    await _writeAll(ops);
  }

  @override
  Future<List<SyncOperation>> pending() => _readAll();

  @override
  Future<void> remove(final String operationId) async {
    final List<SyncOperation> ops = await _readAll()
      ..removeWhere((final SyncOperation o) => o.id == operationId);
    await _writeAll(ops);
  }

  @override
  Future<void> update(final SyncOperation operation) async {
    final List<SyncOperation> ops = await _readAll();
    final int idx = ops.indexWhere((final SyncOperation o) => o.id == operation.id);
    if (idx >= 0) ops[idx] = operation;
    await _writeAll(ops);
  }

  void dispose() => _countController.close();
}
