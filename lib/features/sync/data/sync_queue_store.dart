import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/entities/sync_operation.dart';
import '../domain/entities/sync_operation_codec.dart';

/// Persists the pending-writes outbox as one JSON-encoded list under a
/// single `KeyValueStore` key — global, not per-city, since a queued write
/// must survive the user switching cities/app restarts regardless of which
/// city is currently active (`REFACTOR_ROADMAP.md` Phase 9 #9).
class SyncQueueStore {
  const SyncQueueStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
    final SyncOperationCodec codec = const SyncOperationCodec(),
  })  : _store = store,
        _codec = codec;

  final KeyValueStore _store;
  final SyncOperationCodec _codec;

  static const String _key = 'sync_outbox_queue';

  Future<List<SyncOperation>> load() async {
    final String? raw = await _store.getString(_key);
    if (raw == null || raw.isEmpty) return const <SyncOperation>[];

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return <SyncOperation>[
      for (final dynamic entry in decoded)
        if (_codec.fromJson(entry as Map<String, dynamic>) case final SyncOperation op)
          op,
    ];
  }

  Future<void> save(final List<SyncOperation> operations) async {
    if (operations.isEmpty) {
      await _store.remove(_key);
      return;
    }
    await _store.setString(
      _key,
      jsonEncode(<Map<String, dynamic>>[
        for (final SyncOperation op in operations) _codec.toJson(op),
      ]),
    );
  }
}
