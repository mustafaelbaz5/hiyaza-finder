import '../storage/key_value_store.dart';

typedef LocalMigration = Future<void> Function();

/// Runs ordered, idempotent local migrations for one scoped data set.
///
/// The version advances only after a migration succeeds. A failed step leaves
/// the previous data and version intact, so it can be retried safely later.
class LocalMigrationRunner {
  const LocalMigrationRunner(this._store);

  final KeyValueStore _store;

  Future<void> run({
    required final String versionKey,
    required final Map<int, LocalMigration> migrations,
  }) async {
    final int current =
        int.tryParse(await _store.getString(versionKey) ?? '') ?? 0;
    final List<int> versions = migrations.keys
        .where((final int value) => value > current)
        .toList()
      ..sort();

    for (final int version in versions) {
      await migrations[version]!();
      await _store.setString(versionKey, version.toString());
    }
  }
}
