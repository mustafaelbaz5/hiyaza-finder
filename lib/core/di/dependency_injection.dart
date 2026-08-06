import 'dart:async';

import 'package:get_it/get_it.dart';

import '../../features/sync/data/sync_queue_store.dart';
import '../../features/sync/domain/entities/sync_operation.dart' show SyncOperation;
import '../../features/sync/domain/services/sync_runner.dart';
import 'modules/auth_module.dart';
import 'modules/cities_module.dart';
import 'modules/core_module.dart';
import 'modules/holdings_module.dart';
import 'modules/sync_module.dart';

final GetIt getIt = GetIt.instance;

Future<void> setUpDependencies() async {
  await registerCoreModule(getIt);
  registerAuthModule(getIt);
  registerSyncModule(getIt);
  registerHoldingsModule(getIt);
  registerCitiesModule(getIt);

  // Restores any operations left pending from a previous app session
  // (`REFACTOR_ROADMAP.md` Phase 9 #9) — must run after `registerHoldingsModule`
  // has registered every operation type's handler on `SyncRunner`, and
  // before any screen can start enqueuing new writes on top of it. The
  // initial flush is fire-and-forget: startup must never block on network
  // I/O for background write recovery.
  final SyncRunner syncRunner = getIt<SyncRunner>();
  final SyncQueueStore queueStore = getIt<SyncQueueStore>();
  final List<SyncOperation> pending = await queueStore.load();
  syncRunner.restore(pending);

  // Mirrors every in-memory queue change to durable storage — without this
  // the outbox would only ever exist for the current app session, defeating
  // the entire point of surviving a restart with a write still pending.
  syncRunner.onQueueChanged.listen((final List<SyncOperation> ops) {
    unawaited(queueStore.save(ops));
  });

  unawaited(syncRunner.flush());
}
