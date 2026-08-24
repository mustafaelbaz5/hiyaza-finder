# HiyazaFinder — Refactor Roadmap

**Status:** Frozen v1 — the implementation roadmap. Sequenced to protect production at every step: the
import/export pipeline and Excel schema are never touched, and each phase is independently shippable
and revertable. See `SYSTEM_DESIGN.md` for the architecture being built toward, `DATABASE_REFERENCE.md`
for full schema detail, and `PROJECT_OBJECTIVES.md` for the business goals every phase serves.

---

## Phase 1 — Database: additive schema evolution

**Status (2026-08-06): fully resolved and reclassified against the live database**
(`bbahuyqjptojlighriyy`, direct `list_migrations`/`execute_sql` verification — read-only, nothing
executed beyond `SELECT`s and catalog introspection). Every item below either has a live-confirmed
scope or has been retired as moot once checked against reality. See `DATABASE_REFERENCE.md` §4 and §7
for full per-item justification; this section carries only the final scope + classification.

**Objective:** close every confirmed structural gap without breaking anything currently live.

**Classification legend** (per the deployment-safety rule governing this whole effort):

- **Safe before release** — fully additive, zero Flutter dependency, deployable now with no
  coordination.
- **Safe after Flutter update** — additive at the schema level, but only becomes meaningful once a
  Flutter release reads/writes the new columns; deploying early is harmless, just inert.
- **Requires maintenance window** — not a pure additive schema change; either rewrites existing rows,
  or changes the behavior of an existing live function/trigger in a way that needs a deliberate
  before/after verification pass, not a blind same-day rollout.
- **Optional cleanup** — safe to defer indefinitely; do only once justified by actual need.

| #   | Item                                                                   | Scope                                                                                                                                                             | Classification                                                                                                                                                                                                                          | Notes                                                                                                                                                                                                                                                                                                                                         |
| --- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `association_types` reference table (`DATABASE_REFERENCE.md` §4.1)     | `create table association_types (...)`; seed 2 current values; `cities.association_type_code` new nullable column                                                 | **Safe before release**                                                                                                                                                                                                                 | Existing `association_type` enum untouched; Dashboard mgmt UI is separate follow-up work                                                                                                                                                                                                                                                      |
| 2   | `holding_edits.holding_type` discriminator (§4.2, §7.1)                | `alter table holding_edits add column holding_type text not null default 'holding' check (...)`                                                                   | **Safe before release**                                                                                                                                                                                                                 | Zero Flutter dependency (confirmed: zero `.rpc()` calls, column never read by any live query); old rows get an approximate default, see §7.1 caveat                                                                                                                                                                                           |
| 3   | `editable_fields` table + validation trigger (§4.3, §7.2)              | `create table editable_fields (...)` + trigger, deployed **warn-only** first                                                                                      | **Safe before release** for the table + warn-only trigger; promotion to reject-mode is its own later step, treated as **Requires maintenance window** in spirit (needs an observation window against real traffic, not a timed rollout) | Do not enable rejection until a confirmed zero-unknown-key observation period                                                                                                                                                                                                                                                                 |
| 4   | `added_holdings.reform_type` (§4.4)                                    | —                                                                                                                                                                 | **Already live** — no migration needed                                                                                                                                                                                                  | Confirmed via column comment on the live schema                                                                                                                                                                                                                                                                                               |
| 5   | `city_top_holders` refresh automation (§4.5)                           | —                                                                                                                                                                 | **Retired — moot**                                                                                                                                                                                                                      | Live-verified plain view, not materialized; no refresh step exists to automate                                                                                                                                                                                                                                                                |
| 6   | `persons` table (§4.6)                                                 | —                                                                                                                                                                 | **Not building**                                                                                                                                                                                                                        | Superseded; `person_id` (already live) is the real, correct mechanism                                                                                                                                                                                                                                                                         |
| 6b  | `person_client_id` (§7.5, new finding)                                 | —                                                                                                                                                                 | **Not building; doc cleanup only**                                                                                                                                                                                                      | Confirmed absent from live schema; delete/mark-abandoned the stale Flutter-repo migration file that introduced it                                                                                                                                                                                                                             |
| 7   | Completion state `completed_at`/`completed_by` (§4.7)                  | `alter table holdings/added_holdings add column completed_at timestamptz, add column completed_by uuid references profiles(id)`                                   | **Safe before release**, but functionally inert until Flutter Phase 2 reads/writes it — tracked as **Safe after Flutter update** for when it becomes _meaningful_, even though the migration itself can ship immediately                | Explicitly named as a current Flutter Phase 2 blocker in this doc's own prior status update                                                                                                                                                                                                                                                   |
| 8   | Soft delete `deleted_at`/`deleted_by` on `added_holdings` (§4.8)       | `alter table added_holdings add column deleted_at timestamptz, add column deleted_by uuid references profiles(id)`                                                | **Safe before release**; filter-usage is **Safe after Flutter update**                                                                                                                                                                  | Existing queries keep returning these rows until Flutter Phase 2 adds `deleted_at is null` filters                                                                                                                                                                                                                                            |
| 9   | Sync idempotency `operation_id`/`target_was_stale` (§4.9, §7 decision) | `alter table holding_edits add column operation_id uuid unique; add column target_was_stale boolean not null default false`                                       | **Safe before release**                                                                                                                                                                                                                 | Repurposed as general retry-safety/staleness-detection infrastructure, independent of the abandoned offline outbox — see §7's alternatives-considered writeup for why this wasn't dropped                                                                                                                                                     |
| 10  | National ID format CHECK (§4.10, §7.6)                                 | `check (national_id ~ '^\d{14}$' or national_id = '1111111111')` on `holdings`/`added_holdings`, added **`VALID`, not `NOT VALID`**                               | **Safe before release**                                                                                                                                                                                                                 | Live audit: only 1 non-conforming row per table, both the known placeholder — constraint is 100% compliant with current data once the placeholder is exempted, no need for the cautious `NOT VALID` path                                                                                                                                      |
| 11  | `commit_import_batch` dedup guard (§7.4, new finding)                  | Add `on conflict (city_id, dedup_key) do nothing` to the existing insert, wire the already-present-but-hardcoded `rowsDuplicate` response field to the real count | **Requires maintenance window**                                                                                                                                                                                                         | Confirmed live: the function currently has **zero** dedup guard — a behavior change to an existing, load-bearing function, not a new additive object; needs a deliberate test-import verification pass (duplicate/fresh/partial-overlap files) before shipping, and a small Dashboard follow-up to surface the now-real `rowsDuplicate` count |
| 12  | Legacy `id`/`client_id` backfill on `added_holdings` (§6)              | `update added_holdings set id = client_id where id <> client_id` + repoint `holding_edits.holding_id` for affected rows                                           | **Requires maintenance window**, explicit sign-off gated                                                                                                                                                                                | Live-reconfirmed: exactly 353 rows. Deferred to Phase 4, not this phase — rewrites synced production rows and an append-only audit table's keys                                                                                                                                                                                               |
| 13  | `is_stale` column/index/filter cleanup                                 | Drop the vestigial column, its index, and all `is_stale=false` filter clauses                                                                                     | **Optional cleanup**                                                                                                                                                                                                                    | Currently a functional no-op (nothing sets it `true` anymore); needs a full grep of every reader before removal, not urgent                                                                                                                                                                                                                   |

**Dependencies:** items 1, 2, 3 (table+warn-trigger), 7, 8, 9, 10 have none — can start immediately.
Item 11 (import dedup) has no schema dependency but needs its own verification pass. Item 12 needs
explicit user sign-off, tracked separately in Phase 4.

**Complexity:** low for every "Safe before release" item — new tables, new nullable columns, new
indexes, no existing row rewritten, no existing constraint tightened on non-compliant data (confirmed
by live audit for item 10). Item 11 is low-complexity but touches existing logic, hence its own
classification. Item 12 is the only genuinely complex/high-risk item, and it's excluded from this
phase's default execution.

**Risks:** low across the "Safe before release" set — live-verified against actual production data,
not assumed. Item 11's risk is behavioral (a currently-permissive import path becomes selectively
rejecting) rather than structural. Item 12 remains the one deliberately deferred, sign-off-gated risk.

**Notes:** Excel import/export schema and behavior are out of scope for this phase, and for every phase.
Item 11 touches the import _commit_ function's dedup behavior, not the Excel column mapping/schema
itself — the export format and import field mapping remain untouched.

---

## Phase 2 — Flutter: architecture rebuild, online-first sync/realtime decoupling, UI/UX, quality

**Status as of 2026-08-06 (verified against the real `lib/` tree, not assumed):** superseded and
re-scoped. The original objective below — a durable offline sync outbox as the highest-priority item —
is **abandoned**, per the correction already recorded in `SYSTEM_DESIGN.md` §5: the app is
intentionally online-first (every write awaits its Supabase call directly; no local queue). This
roadmap entry was not updated when that correction landed; the paragraph and scope list immediately
below are the **original, superseded** version, kept for history. See "Current, corrected scope" further
down for what's actually being executed.

**Original objective (superseded):** bring the app's real code in line with the target architecture,
and — the highest-priority item — build a working, durable offline sync outbox (previously fully
designed, never implemented), plus the new review/completion and add-person/add-parcel workflows.

**Original scope (superseded):**

- Split `HoldingsRepository` (646 lines today) into focused services along the lines already specified
  in the app's own prior planning doc (`ParcelQueryService`, `ParcelEditOverlay`, `BulkEditService`,
  `ClipboardFormatter`, plus new sync/completion services).
- Build `core/sync/` as generic infrastructure with zero imports from any feature: `SyncOperation`
  (pure data), `SyncOperationHandler` registry, `SyncRunner` (`SYSTEM_DESIGN.md` §5.1). Holdings (and
  any future feature) register their own handlers.
- Apply the same dependency-inversion fix to Realtime dispatch: raw Postgres payloads are translated
  into domain events in one place; feature handlers consume domain events, never raw rows
  (`SYSTEM_DESIGN.md` §6, §7).
- Implement the reconnect sequence as one ordered flow: flush → staleness check → refresh
  (`SYSTEM_DESIGN.md` §5.2).
- Implement the completion state machine as its own domain service (`SYSTEM_DESIGN.md` §10).
- Rebuild add-person/add-parcel as one atomic flow, including the duplicate-person detection call
  (`SYSTEM_DESIGN.md` §11).
- Progressive-disclosure parcel detail UI; active/completed sections in the main list.
- Soft-delete-aware queries throughout (`deleted_at is null`).

**Original dependencies (superseded):** Phase 1's `persons`, `completed_at`/`completed_by`,
`deleted_at`/`deleted_by`, `operation_id`, `target_was_stale` columns.

---

### Current, corrected scope (online-first — this is what's actually being executed)

**Objective:** finish decomposing the two remaining god-classes, decouple Realtime dispatch, close
confirmed Flutter-side data gaps, and bring the whole app (not just architecture) to production
quality — UI/UX consistency, full localization, and test coverage.

**Done (commits on `core-refactor`, verified against the real files, not the names/line-counts this
doc previously assumed):**

- `ParcelSyncService` extracted from `HoldingsRepository` — network-facing writes
  (add/delete/edit/mark-reviewed/bulk-edit) now live in
  `lib/features/holdings/data/services/parcel_sync_service.dart`.
- `ParcelChangeHandler` interface (`lib/features/sync/domain/parcel_change_handler.dart`) — Realtime
  dispatch depends on this contract instead of the concrete `HoldingsRepository`. Note: this is
  consumer-side dependency inversion only: `RealtimeSyncService` still maps raw Postgres rows to
  `Parcel` itself, it does not yet publish a distinct domain-event type separate from `Parcel` mapping.
  Fine for the current single-consumer reality (`SYSTEM_DESIGN.md` §7's own "don't build for one
  consumer" note); revisit if a second feature ever needs live updates.
- `ParcelDetailCard` split — status row/info banners/id chip extracted to
  `lib/features/holdings/ui/widgets/parcel_detail_header.dart` (621 → 440 lines).
- `Parcel.holderNameFarmerCard`/`ownerNameFarmerCard`/`growthStages` added and wired end-to-end
  (entity, row mappers, `added_holdings_mapper`, edit overlay) — closes 2 of 3 confirmed export-gap
  columns. `owner_national_id` remains unclosed: **no such column exists live** (confirmed via the
  live schema — only a single `national_id` column exists on both `holdings`/`added_holdings`); this is
  a database-side item, not a Flutter gap.
- `holdings.fields.*` localization namespace added; `ParcelDetailCard`'s hardcoded Arabic field labels
  migrated to it (first slice of the localization gap); `login_screen.dart`'s hardcoded app title fixed.

**Explicitly abandoned (not gaps — confirmed via `SYSTEM_DESIGN.md`'s own correction):** the sync
outbox (`SyncOperation`/`SyncOperationHandler`/`SyncRunner`, `core/sync/`), the reconnect
flush→staleness-check→refresh sequence, the `persons` table (real mechanism is `person_id`).

**Blocked on database work (owned by the user, not this session) — confirmed via live schema query,
not assumed:** `completed_at`/`completed_by`/`deleted_at`/`deleted_by` do not exist on `holdings` or
`added_holdings` in the live database. The completion-state domain service (distinct from today's
single `reviewed` flag) and soft-delete-aware queries (`deleted_at is null`) cannot be built until
these columns land — there is nothing to write to or filter by. Tracked as explicit TODOs, not silently
dropped.

**Remaining, in-progress (Flutter-only, no DB dependency):**

- Full localization pass — ~114 hardcoded Arabic strings across ~15 UI files (`add_record_screen.dart`,
  `see_more_section.dart`, `field_edit_dialogs.dart`, `crop_type_picker.dart`, `field_row.dart`,
  `border_compass.dart`, `basin_filter_sheet.dart`, `toggle_field_row.dart`, `home_screen.dart`,
  `recommendation_tile/list.dart`, `detail_screen.dart`).
- `file_status_screen.dart`'s empty-state inconsistency (bespoke inline `Text` instead of the shared
  `EmptyBody` widget already used on `home_screen.dart`).
- Widget test coverage — currently exactly one UI widget test file
  (`test/features/holdings/ui/widgets/parcel_detail_card_test.dart`) against ~28 UI files.
- Dead-code cleanup flagged by `FLUTTER_ARCHITECTURE_REFERENCE.md` §17/§15 (verify each claim before
  acting — that doc has its own accuracy issues): unused Firebase deps if actually present in
  `pubspec.yaml`, the apparently-unused `lib/core/api/` (Dio) path if genuinely dead.

**Complexity:** medium — no longer "highest in this roadmap" now that the outbox rebuild is off the
table; the remaining scope is decomposition, localization, and polish, not a rewrite of the sync model.

**Risks:** regression risk in a tool people depend on every day, same as originally noted. Mitigate
with small, independently-committed, analyzer-and-test-gated steps (already the pattern used for the
three landed commits) rather than a big-bang change.

---

## Phase 3 — Dashboard: additive extension

**Objective:** build the control-center vision on top of what already works, per the explicit
"extend, don't replace" priority — this phase can run in parallel with Phase 2 since it's a separate
codebase and never touches import/export.

**Scope:**

- New Holding Details page. Plain composition, except association-type-conditional sections, which use
  a small registry (`SYSTEM_DESIGN.md` §3) since that variation already exists today (Credit vs. Reform
  fields).
- Provenance (original / modified / added) surfaced in the main Holdings table, extending the existing
  edit-overlay diff primitive with a source dimension.
- Per-user activity pulled into the Users management page (data already computed by the existing
  team-activity analytics board — a presentation change, not new data work).
- Audit trail updated to use the `holding_type` discriminator (Phase 1) instead of guessing which table
  an edit's `holding_id` belongs to; a new "orphaned/conflicting edits" filter over `target_was_stale`,
  reusing the existing review-queue UI pattern rather than new screens.
- Home/City page statistics upgrades using existing analytics data sources.
- `association_types` management UI — adding a new type becomes a Dashboard action, not a deploy.

**Dependencies:** Phase 1's `association_types` and `holding_type` columns.

**Complexity:** low–medium — extends existing, already-clean repository and registry patterns.

**Risks:** low — import/export is untouched.

---

## Phase 4 — Cross-cutting closure

**Objective:** finish the items that depend on both sides being done, or that need explicit sign-off
before they run.

**Scope:**

- Flutter captures the three export-gap fields (owner national ID, farmer-card names, growth stage)
  once their domain is fully defined; Dashboard removes its export fallback logic once real data flows.
- **Legacy `id`/`client_id` backfill** (`DATABASE_REFERENCE.md` §6) — executed only after explicit
  go-ahead, since it rewrites already-synced production rows and an append-only audit table.
  **Requires maintenance window.** Live-reconfirmed 2026-08-06: exactly 353 rows.
- **`commit_import_batch` dedup guard** (`DATABASE_REFERENCE.md` §7.4, new 2026-08-06 finding) —
  live-verified to currently have zero duplicate-import protection. **Requires maintenance window**
  (needs a test-import verification pass first); pulled forward from "investigate" to a scoped,
  Ready-to-implement item now that its current behavior is confirmed, not assumed. Small Dashboard
  follow-up: wire the already-present `rowsDuplicate` response field to the real count once the guard
  ships.
- Per-city user scoping, if still needed by this point.
- Begin `holding_edits` retention/archival planning if table size has become a measured concern.
- **Documentation cleanup:** delete or mark-abandoned the Flutter repo's stale
  `20260805000020_person_client_id.sql` and `20260801000011_city_top_holders.sql` (materialized-view
  version) migration files — both describe objects confirmed absent from/inconsistent with the live
  schema (`DATABASE_REFERENCE.md` §7.5, §2.7) and currently mislead anyone reading that repo's
  migrations folder.

**Dependencies:** Phases 1–3 complete.

**Complexity:** low — mostly follow-through on already-scoped items.

**Risks:** low; the two higher-stakes items (the legacy-id backfill, the import dedup guard) are each
explicitly gated on a verification/sign-off step, not defaulted to a blind rollout.

---

## Phase 7 — Deferred UI/UX & workflow requirements (Flutter)

**Status (2026-08-06):** added from a full planning audit (24 requirement categories checked against
code and docs; see the audit's coverage matrix, retained in the session's plan history) that verified
which of the user's discussed requirements were actually captured here versus only ever discussed in
conversation. This phase exists so nothing stays chat-only.

**Objective:** close the confirmed, real UI/UX and workflow gaps found by the audit — split into items
that are buildable now, one item blocked on Phase 1 DB work, and four items that are explicitly **not
yet approved for implementation** pending the user's sign-off, because building them would reverse an
already-documented architectural decision.

**Buildable now (unblocked) — all done, 2026-08-06:**

- ✅ **Review-workflow redesign — Copy ID becomes the review action.** `parcel_detail_card.dart`'s
  `_copyId` now validates required fields (`Parcel.hasRequiredFieldsFilled`, shared with
  `AddRecordScreen`'s save gate), copies the id, then calls the existing
  `HoldingsRepository.setParcelReviewed(reviewed: true)` → `ParcelSyncService.syncMarkReviewed` path —
  unless the parcel is already reviewed, in which case it's a plain re-copy (repeatedly tapping Copy ID
  on an already-reviewed parcel must not be a surprising side effect). Finish/Reopen remain available
  as an explicit alternate path. Built against the existing `reviewed`/`reviewedAt`/`reviewedBy`
  fields — not blocked on `completed_at`. Migrating this workflow's semantics onto `completed_at` once
  that column ships live is a documented **follow-up**, not a prerequisite. Tests:
  `test/features/holdings/domain/entities/parcel_national_id_test.dart`'s
  `Parcel.hasRequiredFieldsFilled` group.
- ✅ **Snackbar strategy.** `context_ext.dart`'s `showSnackBar`/`showErrorSnackBar`/`showSuccessSnackBar`
  now call `ScaffoldMessenger.clearSnackBars()` before showing — a new message no longer queues behind
  a stale one from a fast-preceding action.
- ✅ **Newly added parcels sort first.** No creation timestamp exists on `Parcel` (still true — this
  isn't a full recency sort), but `SearchResult.isFieldAdded` now breaks a same-score tie in favor of
  field-added parcels in `HoldingSearchService._groupAndRank`. Tests: `holding_search_service_test.dart`
  "isFieldAdded tiebreak" group.
- ✅ **Holder-status UI badge.** `ParcelDetailTopRow` now shows ورثة/مفوض badges from
  `parcel.isInheritance`/`isDelegate`, alongside the existing added/reviewed badges.
- ✅ **Home screen summary cards.** New `StatusSummaryCards` widget (added/pending-review/reviewed
  parcel-row counts, derived from `HomeState.parcels` — no new state) shown below `FileInfoCard`.

**Unblocked and done (2026-08-06) — `completed_at`/`completed_by` confirmed live:**

- ✅ **Details-screen tabs** (Original/Added/Modified/Completed/Pending), built as
  `REFACTOR_ROADMAP.md` Phase 9 #12, in two gated sub-steps:
  1. Migrated the field-worker completion signal (Finish/Reopen buttons, Copy-ID auto-complete, home
     summary cards, per-holding search badges) from the `reviewed` column onto the new
     `completed_at`/`completed_by` columns — `reviewed`/`reviewed_at`/`reviewed_by` are reserved for a
     future staff/Dashboard workflow and the Flutter app no longer reads or writes them anywhere. This
     was a larger rename than originally scoped: `reviewed` turned out to be driving every
     field-worker-completion surface in the app already, not just Copy-ID.
  2. Built the actual filter UI: `ParcelStatusFilter` (`parcel_status_filter.dart`) + a chip row over
     `DetailScreen`'s own parcel list — a holding typically has only 1–3 parcels, so this is a filter
     over the existing on-screen list, not separate navigable tab pages, matching the "lightweight, not
     a Dashboard replacement" philosophy already established for the home summary cards. The row only
     shows once a holding has more than one parcel (a single-parcel holding gains nothing from
     filtering its own one row).

**Explicitly open decisions — user approved 2026-08-06, implemented one at a time, gated:**

Each of these was raised during the planning audit as a "new-sounding" requirement that, if built,
would reverse a decision this project already made and documented. The user has now explicitly signed
off on implementing all four; each is built and gated independently before the next starts.

- ✅ **Search: cache-first + live DB + merge (2026-08-06).** Local city-snapshot search
  (`HoldingSearchService`) remains the primary, instant, offline-first path — unchanged. Added
  `HoldingsApi.searchRemote` (queries `holdings`+`added_holdings` for the active city: exact
  رقم الحيازة or `ilike` حائز/مالك match, capped 20 rows each) and
  `HoldingsRepository.searchRemote(query, localResults)`, which maps rows via the existing
  `holdingRowToParcel`/`addedHoldingRowToParcel` mappers and returns only holdings not already present
  among the local results (deduped by `groupKey`). `HomeCubit.search()` now fires this as an
  **additive follow-up** after emitting local results immediately — a token counter
  (`_searchToken`) discards a stale reply if the user has typed a newer query since, and a failed/slow
  remote call never blocks or replaces what's already on screen. This does not reverse the local-first
  design; it adds a supplementary layer on top, catching only records synced to the server after the
  device's last city download. Zero behavior change when offline (remote call fails silently, local
  results stand alone).
- ✅ **"No manual refresh" (2026-08-06).** The app-bar refresh icon (`HomeTopBar`) and the detail
  screen's `RefreshIndicator`/header refresh icon are removed — `HomeScreen`/`DetailScreen` no longer
  expose any manual resync action. Per explicit sign-off, the safety net stays but goes silent: both
  screens now mix in `WidgetsBindingObserver` and call `refreshActiveCity()`/`syncNow()` automatically
  on `AppLifecycleState.resumed` (foreground return), swallowing any failure rather than surfacing it —
  the point is to close the one gap Realtime can't cover on its own (a channel that silently dropped
  while backgrounded), not to give the user a new visible action. `DetailScreen` needed its own
  resume hook rather than relying solely on `HomeScreen`'s: `HoldingsRepository.loadParcelsForCity`
  doesn't fire `onRemoteChange`, so a `HomeScreen`-only resync wouldn't reach an already-open detail
  screen. `HomeTopBar`/`DetailScreenHeader` had their now-dead `onRefresh`/`isRefreshing`/`isBusy`
  parameters removed rather than left unused.
- 🚧 **Background operations (continue after leaving screen, retry, queue) — in progress, 2026-08-06.**
  This reverses `SYSTEM_DESIGN.md` §5's documented online-first decision, per explicit user sign-off
  to rebuild it. Being built in three gated sub-steps:
  1. ✅ **Core outbox infrastructure** (`lib/features/sync/domain/entities/sync_operation.dart`,
     `sync_operation_codec.dart`, `lib/features/sync/domain/services/sync_runner.dart`,
     `sync_backoff.dart`, `sync_operation_handler.dart`, `lib/features/sync/data/sync_queue_store.dart`)
     — rebuilds the previously-documented-but-never-built `SyncOperation`/`SyncOperationHandler`/
     `SyncRunner` design from `SYSTEM_DESIGN.md` §5.1 almost exactly as originally specified.
     `SyncOperation` is a sealed class (`AddParcelOperation`/`DeleteParcelOperation`/
     `EditParcelOperation`/`MarkReviewedOperation`/`BulkEditOperation`), pure data with
     `attempts`/`lastAttemptAt`/`lastError`. `SyncRunner` is generic (zero feature imports), FIFO,
     exponential-backoff retry, parks an operation at `maxAttempts` (visible, not auto-retried) with an
     explicit `retry()` that bypasses backoff for a future manual-retry UI. 19 tests.
  2. ✅ **HoldingsRepository rewired.** All 5 write methods (`addLocalParcel`, `deleteLocalParcel`,
     `updateParcel`, `setParcelReviewed`, `bulkApplyField`) now mutate the local dataset **immediately**
     (optimistic) and enqueue a `SyncOperation` in the same call — none of them await the network
     round-trip anymore when a `SyncRunner` is configured. A `_syncRunner == null` fallback path
     (test-mode, mirrors the old `holdingsApi == null` convention) preserves the exact original
     await-then-mutate ordering so existing repository tests asserting "a failed write leaves the
     dataset untouched" keep passing unchanged — that invariant is real and correct for the _synchronous
     test double_, it's just no longer true for the production optimistic path, which is now covered by
     its own dedicated test file (`holdings_repository_outbox_test.dart`, 7 tests) proving the local
     mutation happens before any network call and survives a network failure without being undone.
     `AddParcelSyncHandler`/`DeleteParcelSyncHandler`/`EditParcelSyncHandler`/
     `MarkReviewedSyncHandler`/`BulkEditSyncHandler` (`lib/features/holdings/data/services/`) execute
     each operation type against `ParcelSyncService`/`HoldingsApi`. The old synchronous
     `promotedHoldingId` swap in `addLocalParcel` (avoiding a person briefly showing under its
     pre-promotion id) is **not** duplicated in the async handler — that reconciliation now arrives via
     the existing Realtime path instead, same as any other device's write, which is simpler and already
     proven correct. `bulkApplyField`'s `BulkEditOutcome` now means "rows queued," not "rows the server
     confirmed" — a per-row synchronous success/failure summary no longer exists under this model; a
     permanently-failed row surfaces later via the queue, not from the call site. DI:
     `SyncRunner`/`SyncQueueStore` registered in `sync_module.dart`; `holdings_module.dart` registers
     each handler and injects `SyncRunner` into `HoldingsRepository`; `dependency_injection.dart`
     restores the queue from durable storage at startup, mirrors every in-memory queue change back to
     storage via `SyncRunner.onQueueChanged`, and fires an initial fire-and-forget flush.
     `HomeScreen`'s existing resume-lifecycle hook (Phase 9 #8) now also calls `SyncRunner.flush()`, so
     app-resume both re-syncs the read side and drains the write queue.
  3. ✅ **Pending/failed-syncs UI (2026-08-06).** `home_top_bar.dart`'s empty trailing slot (left by
     Phase 9 #8's manual-refresh removal) now hosts a sync icon with a live badge
     (`StreamBuilder` over `SyncRunner.onQueueChanged`) — count when anything is queued, red once any
     operation has failed at least once. Tapping it opens `pending_syncs_sheet.dart`, listing each
     operation via `syncOperationSummary()` with retry/discard actions wired directly to
     `SyncRunner.retry()`/`remove()`. Reused the `sync.status`/`sync.details`/`sync.operation`
     localization namespace already present in `assets/lang/{ar,en}.json` (a leftover provision from
     the originally-designed-but-never-built outbox — genuinely a perfect fit, not repurposed) rather
     than adding a duplicate; added the one missing key (`sync.operation.delete_parcel`) both languages
     needed. `sync_operation_summary_test.dart` (6 tests, the widget-driven `.tr()` pattern
     `CLAUDE.md`'s localization section documents) verifies the actual Arabic strings render, not just
     that a key is returned.

  **Phase 9 #9 complete** — flutter analyze clean, flutter test 263/263 passing (up from 250 before
  this item).

- ✅ **In-app activity center per city (2026-08-06) — resolved as a scope clarification, not a
  reversal.** The full "activity center" reading (filterable history, drill-down lists, a dedicated
  screen) was and remains out of scope per §4's "lightweight... not a Dashboard replacement" boundary —
  not built. What §4's actual requirement text asks for is four counts: original/modified/added/
  reviewed. Added/reviewed already existed (Phase 7's `StatusSummaryCards`); this closes the one real
  gap — **modified** — by adding `HomeState.modifiedIds`/`modifiedCount` (populated by `HomeCubit` from
  `HoldingsRepository.isParcelEdited`, snapshotted into state rather than queried per-build so it stays
  a plain `Equatable` field) and a 4th `StatusSummaryCards` tile. No "original" tile: it's just
  `holdingCount - addedCount`, explicitly judged not worth its own card. Still deliberately just plain
  numbers — no filters, no history feed, no drill-down — the exact boundary the widget's own doc comment
  already stated before this item was addressed. 8 new tests
  (`test/features/holdings/presentation/cubit/home_state_test.dart`, also covering the previously-
  untested `addedCount`/`reviewedCount`/`pendingReviewCount` getters).

**All four explicitly-flagged open-decision items (#7, #8, #9, #13), plus the previously-blocked #12,
are now resolved.** Three of the open-decision items were implemented as approved reversals of
documented decisions; #13 turned out to be a scope clarification achievable without any reversal at
all. #12 was unblocked once `completed_at`/`completed_by` were confirmed live and involved both a
larger-than-expected data-model migration and the actual filter UI. **Phase 9 is complete.** flutter
analyze clean, flutter test 279/279 passing.

**Dependencies:** none remaining — every item this phase tracked (#7, #8, #9, #12, #13) is done.

**Complexity:** low–medium for the buildable items (mostly wiring existing, already-tested lower
layers into new UI); #12 was medium-high once unblocked, due to the `reviewed`→`completed_at` rename
turning out larger than scoped; the open-decision items were each a real scope/architecture decision,
not an estimate.

**Risks:** low for the buildable items. The open-decision items each carry the risk of quietly
undoing a considered, documented trade-off if implemented without a fresh, explicit go-ahead — that is
exactly why they're gated here instead of built.

---

## Phase 8 — Project-wide feature-parity pass

**Status (2026-08-06): done.** Applied the same quality bar Phases 1–5/7 already applied to `holdings`
(architecture, test coverage) to `auth`, `cities`, `about`, `sync`.

**Objective:** Phases 1–5/7 applied a real quality bar (architecture, localization, tests, UI
consistency) to `holdings` specifically. No phase has yet applied that same bar project-wide to the
features that went untouched this session: `auth`, `cities`, `about`, `sync`.

**Done:**

- ✅ **`holdings` `logic/`+`ui/` → `domain/`+`presentation/` rename.** Pure-Dart services
  (`arabic_normalizer`, `area_calculator`, `holding_search_service`) moved to `domain/services/`; the
  cubit moved to `presentation/cubit/`; `ui/screens`+`ui/widgets` merged into `presentation/`. `about`'s
  `ui/` renamed to `presentation/` too (no `domain/` layer added — its single `about_constants.dart` is
  genuinely just constants, not domain logic; CLAUDE.md already documents `about` as presentation-only
  by design). `auth`/`cities`/`sync` already used `domain/`+`presentation/` — confirmed no drift there.
- ✅ **Removed the empty `lib/features/sync/presentation/` directory.**
- ✅ **`cities` god-classes split:** `city_picker_screen.dart` (362→250 lines) and
  `manage_cities_screen.dart` (332→152 lines) — extracted `CityPickerLoadingList`, `CityListEmptyState`/
  `CityListErrorState`, `CachedCityTile`, `ManageCitiesEmptyState`/`ManageCitiesErrorState` into
  `presentation/widgets/`.
- ✅ **`sync` test coverage:** extracted the private payload-dispatch logic from `RealtimeSyncService`
  (untestable without a real `SupabaseClient`/`RealtimeChannel`) into a new, pure, public
  `RealtimePayloadDispatcher` (`domain/realtime_payload_dispatcher.dart`) — `PostgresChangePayload` has
  a plain public constructor, making the dispatch decisions (delete detection, the
  `added_holdings`-promotion dedup check, edit-payload validation) directly unit-testable. 9 new tests.
  `HoldingsApi`/`RealtimeSyncService` themselves remain untested — thin wrappers directly calling
  `SupabaseClient`, not worth mocking the query-builder chain for.
- ✅ **`about` test coverage:** widget test for `AboutScreen` (2 tests). Needed a new
  `wrapLocalizedScreen`/`pumpLocalizedScreen` harness variant (`test/support/localized_widget_test_harness.dart`)
  — `AboutScreen` has its own top-level `Scaffold`+`SingleChildScrollView`, which the existing
  `pumpLocalized` harness's wrapper nested inside another one, throwing an unbounded-height layout error.
- ✅ **`cities` test coverage:** widget test for `ManageCitiesScreen` (3 tests: empty/populated/error
  states) via a `_FakeCityRepository` registered through `getIt`.
- ✅ **`auth` test coverage:** widget test for `LoginScreen` (4 tests: renders, empty-form validation,
  malformed-email validation, failed sign-in stays on screen) and a unit test for the display-name/role
  mapping logic, extracted from `SupabaseAuthRepository`'s private `_toAppUser` into a public
  `toAppUser()` (`data/supabase_user_mapper.dart`) for the same "make the pure logic testable without a
  real Supabase client" reason as the sync dispatcher — Supabase's `User` type also has a plain public
  constructor. 6 new tests.

**Deliberately not done:** deep behavioral tests for `HoldingsApi`/`RealtimeSyncService`'s actual
Supabase wiring (would need mocking Postgrest's fluent query builder — low value for the effort versus
the extracted pure-logic tests above, which cover the actual decision logic).

flutter analyze: clean. flutter test: 230/230 passing (up from 206 before this phase).

---

## Phase 9 — Parcel Details UX pass (field-worker QA request, 2026-08-07)

**Status (2026-08-07): done.** A QA-style requirements list (9 items) came in requesting a
usability pass on the Parcel Details screen. Audited against current code first — findings below —
then implemented. flutter analyze clean, flutter test 279/279 passing (no test count change — no
widget test directly exercised the removed `onFinish` callback).

**Coverage matrix:**

| #   | Requirement                                                     | Status     | Evidence                                                                                                                                                                                                                                                                                                                   |
| --- | --------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Hide derived fields from manual entry                           | ⚠️ PARTIAL | `area_sqm` is already auto-calculated (`AreaCalculator.totalSqm`) whenever فدان/قيراط/سهم change, but is still rendered as its own tappable/editable `FieldRow` (`parcel_detail_card.dart`), duplicating the fraction field just above it and implying it's independently editable when it isn't.                          |
| 2/8 | Reorganize details screen, most-used info first                 | ⚠️ PARTIAL | A primary (`ResponsiveFieldsWrap`) vs. secondary (`SeeMoreSection`, collapsed) split already exists and is reasonable, but not formally reviewed for ordering, and not named `section_holder`/`section_extra` as the localization keys of the same name imply.                                                             |
| 3   | Copy ID = the only completion trigger, remove standalone Finish | ❌ MISSING | Copy ID already auto-completes (`_copyId` calls `setParcelCompleted(completed: true)`), but a fully independent Finish/Reopen button pair still exists (`ParcelDetailTopRow` → `DetailScreen._finishParcel`/`_reopenParcel`). Two independent paths write the same `completedAt` field today.                              |
| 4   | Emphasize primary action, de-emphasize secondary                | ❌ MISSING | Delete/Reopen/Finish/Copy ID/Copy All/Add Parcel all use comparable tonal/outlined weight — no visual hierarchy.                                                                                                                                                                                                           |
| 5   | Spacing/grouping/readability polish                             | ⚠️ PARTIAL | Rolled into #2/#8's reorganization pass rather than tracked separately.                                                                                                                                                                                                                                                    |
| 6   | Faster data entry, fewer taps                                   | ⚠️ PARTIAL | Rolled into #1 (removing the redundant area_sqm tap target) and #3 (removing the now-redundant Finish tap once Copy ID covers it).                                                                                                                                                                                         |
| 7   | Floating Add Parcel action                                      | ❌ MISSING | `DetailScreen` uses an inline `CustomTextButton.outlined` in the header (`detail_screen_header.dart`), not a FAB. `HomeScreen` already has a `FloatingActionButton.extended` precedent to follow (`home_screen.dart:392`).                                                                                                 |
| 9   | Growth Stage field                                              | ✅ DONE    | Real end-to-end field already existed (`Parcel.growthStages`, both DB tables, `SeeMoreSection`/`AddRecordScreen` UI) but as unconstrained free text. User supplied the real business value list — converted to a real option enum (`Parcel.growthStageOptions`) matching the `usageTypeOptions`/`cropTypeOptions` pattern. |

**Scope for this phase (all done, 2026-08-07):**

- **#1** ✅ Removed `area_sqm`'s tap-to-edit affordance in `parcel_detail_card.dart` — display-only, driven purely by `AreaCalculator.totalSqm`.
- **#3** ✅ Removed the standalone Finish button from `ParcelDetailTopRow`/`DetailScreen`; Copy ID remains the sole completion trigger. Reopen stays (still needed to undo a completion — no other UI path does that).
- **#4** ✅ Restyled Copy ID (`ParcelIdChip`) as the visually primary action (filled, high-contrast green); `CopyAllButton` stepped down to an outlined secondary style so it no longer competes with it.
- **#2/#8** ✅ Reordering pass inside `ResponsiveFieldsWrap` — holder name, national ID, and area now lead; crop type moved up; association/basin/land-number/notes moved later. Existing primary (`ResponsiveFieldsWrap`) vs. secondary (`SeeMoreSection`) split kept as-is.
- **#5** ✅ `ResponsiveFieldsWrap` breakpoints tightened (1→2 columns on phones, 2→3 on tablets, 3→4 on desktop) — most field values here are short, so the previous single-phone-column layout wasted horizontal space and forced more scrolling than the content needed. `SeeMoreSection`'s collapse/expand affordance reviewed, already compact — no change needed there.
- **#6** Reviewed `add_record_screen.dart` end-to-end: it already reuses the exact same field-edit dialogs as the detail card, has a single always-visible required-field gate with inline per-field gap messages, and needed no structural tap-reduction — the real friction reduction for data entry came from #1 (one fewer dead tap target) and #3 (one fewer redundant completion action).
- **#7** ✅ Converted `DetailScreen`'s "Add Parcel" header button to a `FloatingActionButton.extended`, matching `HomeScreen`'s existing add-person FAB pattern exactly (`PositionedDirectional` in a `Stack`, not `Scaffold.floatingActionButton`).
- **#9** ✅ Added `Parcel.growthStageOptions` (مرحله الانبات / مرحله النمو الخضري / مرحله الإزهار واثمار) and `Parcel.defaultGrowthStage` (مرحله النمو الخضري) — mirrors `usageType`'s constructor-default + dropdown-picker pattern exactly. Wired through `copyWith`, `fromJson`/`toJson`, `fromEditableJson`/`toEditableJson`, both `holding_row_mapper.dart` mappers (default applied when a live DB row predates this field), and both UI edit sites (`see_more_section.dart`, `add_record_screen.dart`) — `_editText` replaced with `_editDropdown`, same call shape as `usage_type`'s row.

**Dependencies:** none — purely Flutter UI + one enum addition, no schema change needed (the
`growth_stages` column already exists live; this phase only constrains its allowed values client-side).

**Complexity:** low–medium — mostly widget-level changes to already-existing, already-tested pieces
(`parcel_detail_card.dart`, `parcel_detail_header.dart`, `detail_screen.dart`, `detail_screen_header.dart`,
`parcel.dart`, `see_more_section.dart`, `add_record_screen.dart`, `holding_row_mapper.dart`).

**Risks:** low — no data-model/schema change; the growth-stage constraint is client-side only (an
existing free-text value from before this change, or a Dashboard-side edit outside this enum, still
round-trips through `Parcel` unchanged — it just can't be re-selected via the Flutter picker unless it
matches one of the three options, same tradeoff `usageType`/`creditType` already accept).

flutter analyze: clean. flutter test: 279/279 passing (no test count change).

---

## Phase 10 — Details screen UI/UX & data-behavior update (2026-08-07)

**Status: done.** A 12-section QA request covering the Parcel Details experience end-to-end —
data entry/editing speed, information hierarchy, compact layout, and one real data bug. Audited
each section against current code before implementing; several sections landed on already-correct
behavior needing no change, one turned into a live database fix rather than a Flutter change.

**§3 — root cause found and fixed at the database layer, not in Flutter.** The reported bug ("crop
type appears empty right after saving a new person/parcel") does not originate in the Flutter
add/save/reload path — traced UI → `Parcel.copyWith` → `HoldingsRepository.addLocalParcel` →
`ParcelDatasetState.append`/`setOriginal` → `ParcelQueryService.parcelsForHolding` →
`DetailScreen._refreshFromRepository`, and `cropType` survives every hop intact (no JSON
round-trip or overlay merge exists in this path at all — those only apply to the _edit_ flow).
Root cause: `auto_approve_added_holding()` and `approve_added_holding()` (Postgres functions,
confirmed live via direct schema query) INSERT into `holdings` with an explicit column list that
predates most of `added_holdings`' app-only columns — `crop_type`, `notes`, `credit_type`,
`reform_type`, `usage_type`, `is_inheritance`, `is_delegate`, `owner_name`,
`holder_name_farmer_card`, `owner_name_farmer_card`, `growth_stages` were all silently dropped
(nulled) the instant a new record auto-promoted from `added_holdings` into `holdings` — which
happens synchronously on insert, so the app's very next read of the record already saw the empty
field. Fixed via migration `20260807000001_fix_added_holdings_promotion_field_loss.sql` (applied
live, user-approved before running): both functions' INSERT column lists now carry every
`added_holdings` column `holdings` also has.

**§1/§5 — Farmer-card fields (`holderNameFarmerCard`/`ownerNameFarmerCard`) no longer
user-facing.** Removed the two `FieldRow`s from `see_more_section.dart` and `add_record_screen.dart`
— they were previously independent, separately-typed fields with no automatic link to
`holderName`/`ownerName`. `HoldingsRepository._withDerivedFarmerCardNames` (new, applied inside
both `addLocalParcel` and `updateParcel`) now sets them to mirror `holderName`/`ownerName` on
every write, so the DB columns (still real, still synced — Dashboard/export consumers untouched)
stay populated without ever being shown or re-typed in the app. New test:
`holdings_repository_add_local_parcel_test.dart` "derives holderNameFarmerCard/ownerNameFarmerCard".

**§2 — Growth stage spelling corrected.** The prior session's `growthStageOptions`/
`defaultGrowthStage` (`Parcel`) used `ه` (heh) instead of `ة` (teh marbuta) in "مرحله", and
option 3 was missing `ال` before "إثمار". Corrected to the user-supplied exact strings: مرحلة
الإنبات / مرحلة النمو الخضري / مرحلة الإزهار والإثمار, default مرحلة النمو الخضري.

**§4/§8/§10 — Primary field layout rebuilt as explicit full-width rows, not a multi-column
grid.** `ParcelDetailCard`'s `ResponsiveFieldsWrap` grid replaced with an explicit `Column`: Row 1
pairs رقم الحيازة + عدد القطع في الحيازة (`Expanded` inside a `Row`); every other primary field
(اسم المالك, اسم الحائز, الرقم القومي, اسم الحوض, المساحة ×2, رقم الأرض, نوع الزرع, اسم الجمعية,
ملاحظات) gets its own full-width row — avoids the horizontal compression that made fields harder
to scan/tap accurately on phones. `ملاحظات` stays a single-line `FieldRow` (already compact —
it's a fixed-option dropdown via `Parcel.notesOptions`, never free text, so it never needed a
taller block) rather than a separate redesign.

**§6 — ورثة/مفوض name-prefix display added to the primary card.** New
`ClipboardFormatter.holderNamePrefix`/`ownerNamePrefix` (extracted from the existing `format()`
prefix logic so the display and the copy-all text can never drift apart): مفوض overrides ورثة for
اسم الحائز only, ورثة alone still prefixes both slots, matching the already-tested clipboard
matrix exactly. `ParcelDetailCard`'s owner/holder `FieldRow`s now show the prefixed name; the edit
dialog still opens with the raw, unprefixed name. Inheritance/Delegate toggles themselves were
already a compact adjacent pair in `SeeMoreSection` (two-per-row via `ResponsiveFieldsWrap` on
phones) — no widget change needed there. New tests:
`clipboard_formatter_test.dart` "holderNamePrefix/ownerNamePrefix" (4 cases, same matrix as the
existing `format()` coverage).

**§7 — Copy All shrunk to a small, non-full-width secondary action.** Was already outlined/
secondary-styled from Phase 9 #4, but still `width: double.infinity` — now a compact, right-aligned
text-icon button (`font12Medium`, 14px icon, no border/fill), clearly subordinate to
`ParcelIdChip`'s filled-green primary treatment. Copy ID was already positioned before Copy All in
the card (`ParcelIdChip` → `BorderCompass` → `CopyAllButton`) — no reordering needed, just the size
change.

**§8 — confirmed already correct, no change.** Copy ID auto-completing the parcel
(`ParcelDetailCard._copyId` → `HoldingsRepository.setParcelCompleted`) was already the sole
completion path as of Phase 9 #3/#12 — verified no duplicate-operation risk exists.

**§9 — Completed-parcel lock rebuilt.** Previously: light `Opacity(0.68)` dimming with a pale
green tint — cosmetic only, every field's `onEdit` stayed wired and tappable even when completed.
Now: `ParcelDetailCard.build` splits into `topRow` (badges, Delete, إعادة الفتح — always
interactive) and `body` (everything else), wraps `body` in `IgnorePointer` when `completedAt !=
null`, and uses a stronger/darker treatment (`textPrimary`-tinted background, `textSecondary`
border, `Opacity(0.55)`) instead of the old green-tinted fade — reads as locked, not just muted.
إعادة الفتح itself upgraded from `OutlinedButton.icon` to a filled, high-contrast `FilledButton.icon`
(primary color, white text/icon, `lock_open_rounded`) since it's now the one interactive action
left on a completed card and needs to read as obviously tappable.

**§11 — already done** (Phase 9 #7's `FloatingActionButton.extended`, confirmed still present, no
change needed).

**§12 — addressed through the sections above, not as a separate pass:** every §1–§11 change
already pulls in the direction of "editable information is primary, copy/export is secondary" —
no additional isolated pass was needed beyond what those sections cover.

**Dependencies:** none — one live database migration (already applied, see §3) plus Flutter-only
changes, no other schema dependency.

**Complexity:** medium — §3's root-cause trace required reading through the outbox/dataset/query
layers before concluding the bug wasn't there, then a live Postgres function fix; §4/§9 were the
largest Flutter-side layout/interaction changes.

**Risks:** low. §3's migration is additive to two existing functions' column lists (no column
removed, no existing behavior for already-promoted rows changed) — a newly-promoted row now
carries more data than before, never less. §9's `IgnorePointer` only affects a parcel that is
already `completed_at != null`; a completed parcel's fields were never meant to be edited without
first reopening, this just makes that already-intended state actually enforced.

flutter analyze: clean. flutter test: 284/284 passing (5 new — derived-farmer-card-names test,
4 `holderNamePrefix`/`ownerNamePrefix` matrix tests).

---

## Phase 11 — Mobile Details/City Tools UX pass #2 (2026-08-07)

**Status: done.** A follow-up 18-section spec on top of Phase 10 — some items were already covered
by Phase 10 and just reverified, several were genuinely new (moving stats into City Tools, a real
action-order requirement, moving اسم الجمعية into More Details, exact 4-row secondary layout,
creator-email tracking, and — the largest single change — replacing the 6-way filter-chip row with
exactly 3 real tabs).

**§1 — Home stats moved into City Tools.** `StatusSummaryCards` removed from `home_screen.dart`;
`file_status_screen.dart` (the "City Tools" screen) now computes the same four counts directly from
`_repository.parcels`/`isParcelEdited` (same filters `HomeState`'s getters used, not routed through
a cubit this screen doesn't have) and renders them below the reordered Bulk Edit section — Bulk Edit
moved to be first (was second, after Basins), stats second, Basins third.

**§2 — confirmed already correct, no change.** `updateParcel`/`setParcelCompleted`/Copy ID all
already mutate the in-memory dataset and call `setState` synchronously after each write — no manual
refresh was ever required.

**§3 — Details action-area reordered.** Was badges → Copy ID → boundaries → Copy All; now exactly
badges/status → boundaries (`BorderCompass`) → Copy ID (`ParcelIdChip`) → Copy All, per the spec's
explicit order.

**§4/§5 — اسم الجمعية moved into More Details; exact row layout rebuilt.** `see_more_section.dart`
rewritten from one `ResponsiveFieldsWrap` (auto-wrapping, no manual pairing) to explicit rows via a
new `_pairRow` helper: Row 1 ورثة/مفوض, Row 2 كود الحوض/نوع الائتمان-أو-الإصلاح, Row 3 مراحل النمو
(full-width), Row 4 المديرية/الإدارة — then اسم الجمعية (moved here from the primary card) and نوع
الاستخدام as additional full-width rows, since the spec's 4 named rows didn't cover every existing
field and "keep the rest of the existing functionality" ruled out dropping them.

**§6/§7/§8/§9/§10 — reverified, no regressions.** Growth-stage spelling، farmer-card derivation، the
`auto_approve_added_holding`/`approve_added_holding` DB fix، ورثة/مفوض name-prefix display، and the
`_copyId`→`setParcelCompleted` auto-review path were all already correct from Phase 10 — grepped
each after this phase's edits to confirm nothing touched them incidentally.

**§11 — Filter-chip row replaced with exactly 3 real tabs.** This is a genuine UX reversal, not
additive: the previous `ParcelStatusFilter` enum (`all/original/added/modified/completed/pending`,
6 options, chip row, only shown for >1 parcel) is gone, replaced by a new `DetailScreenTab` enum
(`all/added/reviewed`, exactly 3) and a real `TabBar`/`TabController` on `DetailScreen`, always
visible regardless of parcel count, defaulting to الكل. `original`/`modified`/`pending` filtering is
no longer a user-facing feature — the spec was explicit ("exactly three tabs... do not add any other
tabs"). `parcel_status_filter.dart` rewritten (no more `ParcelStatusFilterRow`/`_FilterChip` widgets,
just the enum + `matches`/`label`); its test file rewritten for the new 3-case API (6 tests → 3).

**§12 — Duplicate added-badge removed; creator email added.** The top-row "مضافة من التطبيق"
`StatusBadge` chip was a near-duplicate of the fuller `ParcelDetailInfoBanner` shown right below it
— removed the chip, kept the banner. `Parcel.createdBy` (new field, `added_holdings.created_by`,
`null` on a promoted `holdings` row — that table has no such column, same lifecycle as
`isFieldAdded` flipping to `false` on promotion) wired through `copyWith`/`toJson`/`fromJson`/
`addedHoldingRowToParcel`. `HoldingsApi.fetchProfileEmails` (new) resolves `profiles.email` for a
set of uuids; `HoldingsRepository.resolveCreatorEmails` caches results in-memory for the repository's
lifetime. New `_AddedByBanner` (stateful, `parcel_detail_card.dart`) resolves and shows "تمت الإضافة
بواسطة: {email}" as a third banner line once known, without blocking the rest of the card on the
lookup. **Required a live database change**, applied with explicit sign-off: `profiles`' RLS
`profiles_self_read` policy only allowed a user to read their own row (or admin/editor/viewer roles
to read all) — `field` was not in that allow-list, so a field worker could not resolve another field
worker's email at all. Migration `20260807000002_allow_field_role_read_profiles.sql` adds `field` to
the same read-only policy, matching the existing admin/editor/viewer pattern exactly (no new
broader access, no write grant).

**§13/§14/§15/§16/§17 — reverified, no regressions.** The locked/dimmed completed-card treatment
with `IgnorePointer` + filled Reopen button, Copy ID auto-completing, Copy All's compact secondary
styling, the single-line notes `FieldRow`, and the Add Parcel FAB were all already correct from
Phase 10 — confirmed by direct grep after this phase's edits.

**§18 — addressed through the sections above**, consistent with Phase 10 §12's same conclusion: no
isolated "overall UX" pass was needed beyond what the concrete sections already cover.

**Dependencies:** one live database migration (profiles RLS, applied with sign-off) — everything
else is Flutter-only, no schema dependency.

**Complexity:** medium-high — §11 (real tabs replacing a filter enum) and §12 (a new cross-cutting
field, an API method, a repository cache, a stateful widget, and a live RLS change) were the two
substantial items; §1/§3/§4/§5 were moderate layout/reorganization work on already-existing pieces.

**Risks:** low-medium. §11 is a real, intentional feature removal (original/modified/pending
filtering) per an explicit, unambiguous spec instruction — flagged here rather than silently kept
alongside the 3 tabs. §12's RLS change is narrowly scoped (adds one role to an existing read-only
policy, no write access, no new columns exposed beyone what admin/editor/viewer already see) but is
the first RLS policy change made directly from this session — worth a quick Dashboard-side sanity
check that no other policy assumed `field` could never read `profiles`.

flutter analyze: clean. flutter test: 281/281 passing (net -3: the 6-case `ParcelStatusFilter` test
replaced by a 3-case `DetailScreenTab` test, plus the `parcel_detail_card_test.dart` badge assertion
retargeted from the removed `StatusBadge` to the surviving banner's text).

---

## Phase 12 — Copy-all visibility, notes auto-set correction, sync-completeness audit,

snackbar clarity (2026-08-07)

**Status: done.** A small, focused follow-up: `Parcel.defaultUsageType`/`defaultCreditType` were
already correct (`زراعة`/`ملك`, verified, no change needed); the other four items were real.

**Copy All button restored to genuinely visible.** Phase 9 #4/Phase 10 §7 shrank it to a small
right-aligned text link (14px icon, no border/fill) in the name of de-emphasizing copy/export next
to Copy ID — but that went far enough that the button became hard to notice and hard to tap
accurately, which the user flagged directly. `CopyAllButton` rebuilt as a full-width outlined button
(`AppColors.primary200` border/text/icon) — clearly visible and easy to hit, while staying outlined
rather than filled so `ParcelIdChip`'s solid-green fill still reads as the primary action. Visibility
and hierarchy are not the same axis; the previous version conflated them.

**الملاحظات no longer force-overwritten on every field edit.** Previously, `DetailScreen._updateField`
unconditionally reset الملاحظات to "نقص بيانات الحصر" on _any_ field save unless the save was itself
an explicit edit to الملاحظات — silently discarding whatever the user had actually written the moment
they corrected an unrelated field (national ID, basin, crop type, anything). Replaced with exactly
two deliberate triggers, per explicit user confirmation: المساحة (فدان/قيراط/سهم/المساحة بالمتر)
changing → "نقص بيانات الحصر"; نوع الاستخدام changing away from the زراعة default → "استخدام غير
زراعي" (wins if both fire in the same edit — the more specific, actionable message). Every other
field edit now leaves الملاحظات exactly as the user last set it. New-parcel creation (Add
Parcel/Add Person) still defaults to "نقص بيانات الحصر" as a starting value, unchanged — still
freely editable in the form before saving.

**Sync-completeness audit found and fixed a real silent-edit-loss bug.** Traced every UI-editable
field through `toEditableJson()`/`fromEditableJson()`/`EditParcelOperation`'s payload
(`ParcelDatasetState.editSnapshot` → `ParcelEditOverlay.snapshot`) and `parcelToAddedHoldingsRecord()`
for the add flow. Found: **اسم الجمعية (`associationName`)** became user-editable when it moved into
More Details (Phase 11 §4), but `Parcel.toEditableJson()`/`fromEditableJson()` still treated it as
one of the "never-editable, always-from-original" fields (a leftover from when it truly wasn't
editable) — an edit displayed correctly on screen and updated local state, but was silently dropped
before reaching `EditParcelOperation`'s payload, and reverted to the original value on the next
overlay rebuild (app restart, an incoming Realtime edit from another device). Fixed: added
`associationName` to both `toEditableJson`/`fromEditableJson`, with a fallback to
`original.associationName` for a pre-fix snapshot that never recorded it (so an already-queued sync
operation from before this fix doesn't crash or silently null the field on decode). Every other field
checked (growth stage, notes, usage type, credit type, and everything editable in
`add_record_screen.dart`) was already correctly wired end-to-end — no other gaps found. New tests:
`parcel_json_test.dart` "associationName round-trips through toEditableJson/fromEditableJson" and the
pre-fix-snapshot fallback case.

**Snackbar messages made action-specific instead of a blanket "حدث خطأ غير متوقع."** Added
`holdings.detail.save_failed`/`delete_error`/`reopen_failed`/`copy_and_review_failed` and
`holdings.add.save_failed`, wired into `DetailScreen._updateField`/`_deleteParcel`/`_reopenParcel`,
`AddRecordScreen._save`, and `ParcelDetailCard._copyId`'s completion-write failure — each now names
the action that failed and suggests checking the connection, rather than a generic unexpected-error
message that gave no signal about what to retry. `file_status_screen.dart`'s bulk-edit flow already
had three specific outcome messages (all-succeeded/all-failed/partial) — left its outer catch-all as
`errors.unknown` since that's the correct fallback for a genuinely unexpected exception outside the
three known outcomes, not a gap.

**Dependencies:** none — Flutter-only, no schema change (the sync-completeness fix corrects how an
already-live column, `associationName`/`holdings.association_name`/`added_holdings.association_name`,
gets included in the existing edit-overlay payload — the column itself needed no migration).

**Complexity:** low-medium — the `associationName` fix required care around backward-compat decoding
of a pre-fix snapshot; everything else was a contained, well-scoped change to already-existing pieces.

**Risks:** low. The `associationName` fix is strictly additive to the sync payload (a field that
previously never synced now does) — no existing behavior for any other field changed. The notes
auto-set narrowing is a deliberate, explicitly-confirmed behavior change, not a silent one.

flutter analyze: clean. flutter test: 283/283 passing (2 new).

---

## Phase 13 — ملاحظات "specify other" option (2026-08-07)

**Status: done.** ملاحظات gets the same "specify other" escape hatch نوع الزرع already had: a new
`أخرى` entry appended to `Parcel.notesOptions`, picking it opens a free-text follow-up dialog so a
field worker can write a note the fixed list doesn't cover, instead of being stuck with the closest
approximate option.

**`pickWithOther` (new, `specify_other_picker.dart`)** generalizes `pickCropType`'s "choice dialog →
if 'other', follow up with free text" flow into a reusable function, rather than duplicating that
logic a second time for ملاحظات. `pickCropType` itself was left as its own thin wrapper (a second call
site elsewhere in the app relies on its exact signature) but could be rewritten in terms of
`pickWithOther` in a later cleanup if a third field ever needs the same pattern.

Wired into all three places ملاحظات is edited: `ParcelDetailCard._editNotes` (detail card),
`AddRecordScreen._editNotes` (new-record form), and `FileStatusScreen._pickBulkValue`'s notes branch
(bulk edit) — each replaces a plain `showChoiceDialog`/`_editDropdown` call with `pickWithOther`,
mirroring exactly how each of those three call sites already special-cased `BulkEditableField.cropType`/
`_editCropType` for the same reason.

**Dependencies:** none — `notesOptions`'s `أخرى` entry is a plain Dart list value, no DB/schema
involvement; the custom text a user types is stored in the same `notes` column as any other value.

**Complexity:** low — reused the exact "specify other" pattern already proven for نوع الزرع.

**Risks:** low. Purely additive (`أخرى` is a new list entry, not a rename/removal of any existing
option) — every previously-valid `notes` value is unaffected.

flutter analyze: clean. flutter test: 283/283 passing (no test count change — `pickWithOther`/
`pickCropType` are UI-orchestration glue, matching the existing pattern of not unit-testing that
category of code in this codebase).

## Phase 14 — Added-provenance loss on promotion, notes default, الكل tab ordering (2026-08-08)

**Status: done.**

**Bug 1 — added-parcel provenance permanently lost on promotion.** A field-added parcel's
"مضافة"/creator-email visibility only survived until `added_holdings.promoted_holding_id` got set
(the `auto_approve_added_holding` trigger fires essentially immediately on insert), at which point
the client's `RealtimePayloadDispatcher` treats the `added_holdings` row as deleted and starts
showing the `holdings` row instead (`realtime_payload_dispatcher.dart` §"added_holdings needs one
extra check"). `holdings` had **no `created_by`/`is_field_added`/`source_added_holding_id`
columns at all**, and `holding_row_mapper.dart`'s `holdingRowToParcel` hardcoded `isFieldAdded:
false` and never read `created_by` — so the moment promotion completed (near-instant), the badge,
المضافة tab membership, and creator email were gone for good, not just delayed.

Fixed at both layers:

- **DB** (`supabase/migrations/20260808000001_preserve_added_provenance_on_promotion.sql`, applied
  live): added the three columns to `holdings`, and updated both `approve_added_holding` and
  `auto_approve_added_holding` to carry `created_by`/`is_field_added: true`/
  `source_added_holding_id` through on the INSERT into `holdings`. Additive-only — existing
  historical rows just read as `is_field_added = false`, same as their current (already wrong)
  display, not a regression.
- **Flutter** (`holding_row_mapper.dart`): `holdingRowToParcel` now reads all three columns instead
  of hardcoding `isFieldAdded: false`.
- **Flutter** (`parcel_status_filter.dart`): `DetailScreenTab.added.matches` was checking only
  `isFieldAdded`, while `ParcelDetailCard`'s own badge check used `isFieldAdded ||
sourceAddedHoldingId != null || isNew` — a parcel identified only via `sourceAddedHoldingId` (the
  common case right after promotion) showed the badge on the card but never appeared under the
  المضافة tab. Aligned the tab filter to the same definition.

**Bug 2 — wrong default ملاحظات on "Add new person."** `home_screen.dart`'s `_openAddPerson` set
`notes: 'غير محيز'` on the blank template `Parcel`; the sibling "add parcel for existing person" flow
(`detail_screen.dart`'s `_addParcelForPerson`) already correctly used `'نقص بيانات الحصر'`
(`_needsSurveyNote`). Fixed `home_screen.dart` to match.

**Bug 3 — no ordering in الكل tab.** `detail_screen.dart` never sorted `visibleParcels` at all — plain
fetch/insertion order. Added `compareParcelsForDisplay` (`parcel_status_filter.dart`): original
parcels first, then added parcels, with reviewed parcels (either origin) sunk to the end — applied to
every tab, not just الكل, since a reviewed added-parcel sinking within المضافة too matches the same
"done work drops to the bottom" intent.

**Dependencies:** the DB migration is a prerequisite for bug 1's Flutter fix actually taking effect —
without the new columns, `holding_row_mapper.dart` would just read `null`/`false` regardless of the
code change.

**Complexity:** medium — required tracing the promotion path (`added_holdings` insert → trigger →
`holdings` insert → Realtime delete-then-reinsert on the client) to find where provenance actually
got dropped, plus a live schema change.

**Risks:** low-medium. DB change is additive (new nullable/defaulted columns, no existing column
touched); promotion functions are `create or replace` on the same signature, no callers need to
change. The one behavior change to watch: المضافة tab and الكل ordering now surface more parcels
as "added" than before (any parcel with `sourceAddedHoldingId` set, not just `isFieldAdded`) — this
is the intended fix, not a side effect, but worth knowing if a field worker asks why a previously
badge-less parcel suddenly shows "مضافة".

flutter analyze: clean. flutter test: 286/286 passing (3 new: `compareParcelsForDisplay` sort-order
cases in `parcel_status_filter_test.dart`, plus a case for the `sourceAddedHoldingId`-only added-tab
match).

## Phase 15 — Realtime promotion duplicate-append fix, production-flavor connectivity-gate crash (2026-08-08)

**Status: done.**

**Bug 1 — `applyRemoteChange` could append a promoted parcel as a duplicate instead of replacing
it.** Investigating a "no parcels show for added persons" report surfaced a real latent bug in the
outbox path's only reconciliation mechanism: a just-promoted `holdings` row arrives with a
brand-new server-generated `id` (different from the client-generated id `addLocalParcel` created),
and the old `applyRemoteChange` matched the existing dataset entry by `id` alone
(`_dataset.indexOf(updated.id)`). Since the ids never match for a promotion event, it always fell
into the "not found" branch and appended the promoted row as a second parcel, leaving the
pre-promotion local one in place too — a genuine duplicate until the next full city re-download
silently absorbed it.

Fixed with `ParcelDatasetState.indexOfForRemoteChange` (replacing `indexOf` at this one call site):
matches on `id == updated.id` (ordinary update), `id == updated.sourceAddedHoldingId` (the
promotion case — the old local id is exactly what the promoted row's `sourceAddedHoldingId` now
points back to, via Phase 14's migration), or both sharing a non-null `sourceAddedHoldingId`
(repeat delivery). When a match is found under a different id, the old id's `original`/edit-overlay
bookkeeping is cleaned up so nothing lingers under an id no longer in the dataset.

**Bug 2 — production flavor crashed on startup with no internet: "No MaterialLocalizations
found."** `_ConnectivityGate` (`hiyaza_finder_app.dart`) wrapped `MaterialApp` from the _outside_
and called `AppDialogs.showError` (a `showDialog`-based Material dialog) using its own
`BuildContext` — but that context sits above `MaterialApp`'s internally-created
`Navigator`/`Localizations`, which `showDialog` requires. `NetworkInfoImpl.isConnected` bypasses to
`true` for `AppConfig.isDevelopment` (dev flavor only, existing `// TODO: remove before release`),
so this crash was invisible in dev but fired on any production-flavor launch without connectivity
— exactly what surfaced during this session's testing.

Fixed by moving `_ConnectivityGate` inside `MaterialApp.builder` (so it wraps the routed content,
not `MaterialApp` itself) and switching its dialog call to use `HiyazaFinderApp.navigatorKey`'s
`currentContext` (newly made non-private) instead of its own — that context is guaranteed to sit
inside the `Navigator` `MaterialApp` creates, wherever `_ConnectivityGate` itself sits in the tree.

**Dependencies:** Bug 1 depends on Phase 14's `holdings.source_added_holding_id` migration already
being live — this fix is meaningless without that column existing to round-trip through.

**Complexity:** medium for bug 1 (required reasoning through Realtime event ordering and the
outbox path's reconciliation model to find), low for bug 2 (a straightforward widget-tree ordering
mistake, once reproduced).

**Risks:** low for both — bug 1's fix only changes what an existing dataset lookup matches on, no
behavior change for the (much more common) case where `updated.id` already matches directly. Bug
2's fix is a mechanical reposition of one widget plus a context source change; `_ConnectivityGate`'s
own gating behavior (check once at startup, retry loop while disconnected, never intervene again)
is unchanged.

flutter analyze: clean. flutter test: 287/287 passing (1 new: a `holdings_repository_add_local_parcel_test.dart`
regression case simulating the outbox-path promotion-duplicate scenario directly).

---

## Phase 16 — Flavor-consistent, backend-accurate connectivity check (2026-08-08)

**Status: done.** `NetworkInfoImpl.isConnected` had `if (AppConfig.isDevelopment) return true; //
TODO: remove before release` — a dev-only bypass that made the connectivity check meaningless in
dev and, worse, meant it was never actually exercised until production, where Phase 15's
`_ConnectivityGate` crash was first hit. Removed the bypass entirely — both flavors now run the
exact same check.

The underlying check itself was also weak: `InternetConnectionChecker.createInstance()`'s default
address list pings generic public hosts unrelated to whether the app can actually reach its own
Supabase backend — an emulator/device can resolve those while Supabase itself is unreachable, or
vice versa. `core_module.dart` now configures the checker with `AppConfig.supabaseUrl` (a new
getter, reads `SUPABASE_URL` from the already-loaded `.env` via `flutter_dotenv`) as the primary
address, plus two well-known highly-available hosts (`one.one.one.one`, `dns.google`) as fallbacks
so a momentary Supabase-side blip alone doesn't read as "no internet" when the device is otherwise
online — any one responding is enough (`requireAllAddressesToRespond` stays `false`, the package
default).

**Dependencies:** none — purely a `NetworkInfo`/DI configuration change, no schema/API involvement.

**Complexity:** low.

**Risks:** low. The connectivity check now runs for real in dev too (previously always a silent
`true`) — a dev tester on a genuinely disconnected network will now see the same "no internet"
dialog a production user would, which is the intended, more accurate behavior, not a regression.

flutter analyze: clean. flutter test: 287/287 passing (no test count change — DI wiring and a
`.env`-backed config getter aren't unit-tested in this codebase's existing conventions).

---

## Phase 17 — root cause of the persistent "تعذّرت المزامنة" sync failure: unvalidated area values (2026-08-08)

**Status: done.** The sync failure banner that survived Phases 15/16's connectivity fixes turned out
to be unrelated to connectivity at all — confirmed via Supabase logs (`get_logs` on `postgres` and
`api`): every retry of the stuck `AddParcelOperation` hit `POST /rest/v1/added_holdings` and got
back `400` with Postgres error `numeric field overflow`. The outbox's exponential backoff was
retrying the exact same doomed insert indefinitely, since the payload itself was invalid — no amount
of connectivity or Realtime fixes could ever make it succeed.

Root cause: `field_edit_dialogs.dart`'s المساحة editor accepts فدان/قيراط/سهم as free-typed numbers
with zero upper-bound validation, and `added_holdings_mapper.dart` sent whatever was typed straight
through. `added_holdings.feddan/qirat/sahm` are `numeric(10,4)` (max `999999.9999`) — a field worker
mistyping a value (extra digit, wrong field) produces a number Postgres rejects outright, and the
only feedback that reached the user was the generic "check your internet connection" sync-failure
card, not an actual explanation.

Also found and fixed a **stale/incorrect comment**, not a live bug: the mapper's `.round()` calls on
`feddan`/`qirat`/`sahm` claimed these were `int` columns ("Postgres rejects a double like `1.0`") —
confirmed via `information_schema.columns` that they're actually `numeric(10,4)` and always have
been in this migration set; the comment (and a same-claim unit test) predates whichever migration
last touched these columns. Removed the now-pointless `.round()` (kept the `?? 0` fallback — the
columns are `NOT NULL`) so a fractional فدان value isn't silently truncated to a whole number before
ever reaching validation.

Fixed:

- `field_edit_dialogs.dart`'s `_AreaEditDialog` now validates on save: any of the three values at or
  above `999999.9999` shows an inline Arabic error ("القيمة كبيرة جدًا — يرجى مراجعة الرقم
  المدخل") and blocks the dialog from closing, instead of letting an invalid value ever reach the
  outbox where it fails silently and permanently.
- `added_holdings_mapper.dart` sends `feddan`/`qirat`/`sahm` as their literal (possibly fractional)
  value with only a `?? 0` null-fallback, not `.round()`.
- `added_holdings_mapper_test.dart` updated to match — the old test asserted `isA<int>()` based on
  the incorrect "these are int columns" premise.

**What this does NOT fix:** the one sync operation already stuck in this device's outbox queue with
an invalid value — that entry will keep retrying and failing forever regardless of this fix, since
the fix only prevents a _new_ bad value from being created. It needs to be discarded from the sync
sheet (تجاهل) and the parcel's area re-entered correctly by hand.

**Dependencies:** none.

**Complexity:** medium — required checking live Supabase Postgres/API logs to find the actual
failure reason, since neither the client nor the generic sync-failure UI surfaced it.

**Risks:** low. The validation is purely additive (rejects values that were always going to fail
server-side anyway); the mapper change only removes unnecessary integer rounding on columns that
were never integers.

flutter analyze: clean. flutter test: 287/287 passing (2 of `added_holdings_mapper_test.dart`'s
existing cases updated to reflect the numeric, not int, column type; no net test count change).

## Phase 18 — قيراط/سهم caps, reviewed-card locked styling, added-by verification (2026-08-08)

**Status: done.**

**قيراط/سهم domain caps.** 24 قيراط make a فدان and 24 سهم make a قيراط, so a value of 24 or more in
either field is never legitimate — it should have carried over into the next unit instead. Added a
`_maxQiratOrSahm = 24` check in `_AreaEditDialog._save` (`field_edit_dialogs.dart`), alongside
Phase 17's existing `_maxAreaValue` DB-range check on فدان. فدان itself stays unbounded — a large
فدان count is plausible on its own. Each violation gets its own inline error message
(`holdings.detail.qirat_max_exceeded`/`sahm_max_exceeded`).

**Reviewed-parcel UI.** Removed the large "تم مراجعة القطعة" / "تم جمع هذه البيانات من الحقل..."
banner from `ParcelDetailCard` — the small "تم المراجعة" `StatusBadge` already in `ParcelDetailTopRow`
said the same thing, and the full banner was redundant weight on an already-done record. That badge's
icon changed from a plain checkmark to a lock icon to read as "locked," not just "successfully
marked." The card's own locked styling (shown when `completedAt != null`) was strengthened: the
previous treatment was a barely-there `textPrimary` tint at 5% alpha with a translucent border, easy
to miss next to an active card; now a distinctly grey `textSecondary`-tinted surface (10% alpha) with
a solid, more visible grey border (55% alpha, 1.5px) — a completed parcel should be unmistakable at a
glance, not just slightly faded.

**Added-by-app info — verified, not changed.** `_AddedByBanner` (`parcel_detail_card.dart`) already
resolves `Parcel.createdBy` to an email via `HoldingsRepository.resolveCreatorEmails` and shows it as
a third banner line once resolved — this was Phase 11 work, confirmed still correct and now actually
functional end-to-end thanks to Phase 14/15's `holdings.created_by` migration and Realtime-promotion
fixes (previously `createdBy` was silently lost the moment a parcel promoted from `added_holdings`
into `holdings`, so the creator line would only show at the top before promotion arrived, if at all).
No code change needed here — user confirmed keeping the existing 3-line banner shape (label → hint →
"تمت الإضافة بواسطة: {email}") rather than collapsing into one combined line.

**Dependencies:** the added-by-app verification only actually shows correct data now because of
Phase 14/15's DB migration and duplicate-append fix — without those, `createdBy` would still be lost
on promotion regardless of this phase's UI being otherwise correct.

**Complexity:** low — no new mechanisms, straightforward validation/styling changes to existing code.

**Risks:** low. Removing the reviewed banner is purely subtractive (the badge already carried the
same information); the قيراط/سهم caps only reject values that were never valid; the styling change is
visual-only, no behavior change to `IgnorePointer`/`onReopen`/etc.

flutter analyze: clean. flutter test: 287/287 passing (no new tests — these are UI-styling and
inline-validation-message changes, matching the existing pattern of not unit-testing that category
of change in this codebase; validated by re-running the full suite for regressions).

## Phase 19 — online-first-when-possible writes, review-conflict guard (2026-08-09/10)

**Status: done.** Reworked every write in `HoldingsRepository` (`addLocalParcel`, `deleteLocalParcel`,
`updateParcel`, `setParcelCompleted`, `bulkApplyField`) to check `_isOnline()` (new — backed by
`NetworkInfo`) first: when online, the write calls straight into `ParcelSyncService`/`HoldingsApi`
and **awaits** it before applying anything locally or returning — a caller only sees success once the
server has genuinely confirmed the write, and a failure throws instead of silently landing in the
optimistic-apply-then-enqueue outbox path with the UI already showing success. Only when genuinely
offline (or no `SyncRunner`/`NetworkInfo` configured, e.g. most repository tests) does a write fall
back to the original Phase 9 #9 optimistic path. Offline-first is fully preserved — a queued write is
never blocked on network — this only changes what "success" means while online.

**`mark_parcel_completed` RPC** (new, `security definer`): the one sanctioned way to write
`completed_at`/`completed_by`. Two real bugs found and fixed along the way:

- `holdings_write` RLS only allowed admin/editor — a `field`-role user (the app's actual field
  workers) had no RLS path to write these columns on a promoted `holdings` row at all;
  `added_holdings_update_own` only covers rows still `status = 'pending'`, a narrow window since
  promotion is near-instant. The RPC runs with the function owner's privileges, scoped to exactly
  these two columns.
- The RPC's first version had its `completed_at`/`completed_by` OUT parameters shadowing the real
  table columns of the same name, causing every call to fail with "column reference completed_at is
  ambiguous" — a genuine SQL bug, not a client issue. Fixed by renaming the OUT parameters to
  `out_completed_at`/`out_completed_by` (required a drop+recreate since Postgres rejects an
  OUT-parameter shape change via `create or replace`).

Marking completed (`p_completed = true`) is conditioned atomically on `completed_at is null` — the
one place two devices can genuinely race each other over the same parcel. Losing that race returns
`conflict = true`, surfaced client-side as `ConflictException`/"already reviewed by another device"
instead of silently succeeding. Reopening stays unconditional (single-actor undo, not a race target).

**Dependencies:** none. **Complexity:** medium-high (RLS gap + RPC ambiguity bug both needed
diagnosing from live Supabase logs, not just code review). **Risks:** low — additive DB objects, no
existing column/policy removed; `HoldingsApi.markCompleted`'s RPC result only reads `conflict`, so
the OUT-parameter rename needed no Flutter-side follow-up change.

flutter analyze: clean. flutter test: 295/295 passing (8 new: `holdings_repository_online_sync_test.dart`
covers the online/awaited path directly for every write type; `holdings_repository_outbox_test.dart`
updated with an explicit offline `NetworkInfo` fake so it keeps exercising the path it's named for).

## Phase 20 — Copy ID review-status bug, field-added-parcel dedup false positive (2026-08-10)

**Status: done.** Investigated two reports without assuming the cause; both had a real, specific root
cause, not a repeat of Phase 19's work.

**Copy ID sometimes not reflecting "تمت المراجعة".** Root cause: `ParcelDetailCard._copyId` called
`setParcelCompleted` (genuinely server-confirms `completed_at`/`completed_by` — Phase 19's RPC is
correct), then reflected the result via `onFieldChanged`, which `DetailScreen` wires to `_updateField`
— a handler built for **editable-field edits**. `_updateField` issued its own separate
`_repository.updateParcel(toSave)` call (the edit-overlay/`holding_edits` path), which doesn't carry
`completedAt` at all (`Parcel.toEditableJson` never included it — pure redundant risk). If that second,
unrelated write failed for any reason, `_updateField`'s `catch` fired before `_parcels[idx] = toSave`
ever ran, so the local UI never picked up a review that had already succeeded, and the user saw a
misleading "save failed" message for an action that actually worked — plus two competing snackbars on
the success path.

Fixed by giving `ParcelDetailCard` a dedicated `onCompleted` callback (falls back to `onFieldChanged`
if unset), wired in `DetailScreen` to `_onParcelCompleted` — a `setState`-only handler, no repository
call, no `updateParcel`, no dependency on an unrelated write succeeding. `_copyId` now uses the
server-confirmed `Parcel` returned by `setParcelCompleted` directly.

**Multiple field-added parcels for the same person rejected as duplicates.** Root cause:
`holdings_active_dedup_key_unique` (`(city_id, dedup_key) WHERE is_stale = false`) was built
specifically to stop a re-uploaded Excel file from duplicating rows (`composite_dedup_key`'s own
migration comment says so) — its fallback fingerprint
(`holder_name|national_id|land_number|page_number|basin_code|basin_name`) assumes `land_number`
uniquely distinguishes rows within an import, true for an Excel sheet but not for field-added parcels,
whose `land_number` defaults to the placeholder `'-1'` (`DetailScreen._addParcelForPerson`) until
corrected. Two genuinely different parcels for the same person, both still `'-1'`, produce an
identical `dedup_key` and collide. `auto_approve_added_holding()` copies these fields verbatim on
promotion, so the same index applied there too, even though it was never designed for that path.

Fixed with a 1-predicate index change: `... where is_stale = false and is_field_added = false` —
narrows the constraint to exactly the rows it was ever meant to protect (imports). Field-added
parcels already have a real, enforced identity (`id`/`source_added_holding_id`, primary/foreign-keyed)
and were never at risk of the kind of silent duplication a re-imported row was.

**Verification against the live database (not just code review):**

- Two `holdings` inserts with `is_field_added = true` and an identical fingerprint (same holder,
  national ID, `land_number = '-1'`, basin) — both succeed. (Ran inside a transaction, rolled back —
  no data left behind.)
- Two `holdings` inserts with `is_field_added = false` and an identical fingerprint — second one still
  rejected with `holdings_active_dedup_key_unique` violation, confirming import-duplicate protection
  is untouched.
- Confirmed zero existing imported rows (`is_field_added = false`) currently share a `(city_id,
dedup_key)` pair — the narrower index applies with zero pre-existing violations.

**Dependencies:** the dedup fix depends on Phase 14's `holdings.is_field_added` column already being
live and reliably populated for promoted parcels.

**Complexity:** medium — required tracing `_copyId`'s callback wiring across two files for issue 1,
and reading the full migration history (`composite_dedup_key` → `dedup_holdings` →
`dedup_key_unique_constraint`) to understand issue 2's original intent before narrowing it.

**Risks:** low for both. Issue 1's fix is additive (new optional callback, old behavior preserved when
unset). Issue 2's fix only _removes_ rows from an index's scope — it cannot cause a previously-caught
import duplicate to slip through, since imports are still fully covered.

flutter analyze: clean. flutter test: 297/297 passing (2 new in `parcel_detail_card_test.dart`,
covering both the new `onCompleted` path and the `onFieldChanged` fallback for callers that haven't
adopted it yet — includes a genuine test-infra fix: `Clipboard.setData` needs an explicit mock method
handler in this test environment, or it hangs indefinitely and silently stalls `_copyId` before it
ever reaches the repository call, which is worth knowing for any future test tapping a
clipboard-writing action).

## Phase 21 — loading indicators + accurate error messages for every write action (2026-08-10)

**Status: done.** Surveyed all six write actions (add person/parcel, edit field, delete, reopen,
copy-ID/review, bulk edit) before changing anything. Found: only add and bulk-edit had any loading UI
at all (`CustomTextButton.isLoading`); delete/reopen/edit/copy-ID had none, despite `DetailScreen`
already tracking a screen-wide `_isBusy` flag that drove no visible feedback. Error messages were
inconsistent in both specificity (copy-ID/bulk-edit differentiate causes; edit/delete/reopen don't)
and key namespace (`holdings.detail.*_failed` vs `holdings.add.*_failed` vs bare `errors.unknown`) —
and, more importantly, **inaccurate**: every generic catch fell through to `ErrorHandler`'s
`ServerException` fallback regardless of whether the failure was a real server rejection or the
device genuinely being offline, since raw `SocketException`/`HandshakeException`/`dart:async`'s
`TimeoutException` were never classified into `AppException` subtypes at all.

**`ErrorHandler.handleException`/`_toException`** (`core/errors/error_handler.dart`): now classify
`SocketException`/`HandshakeException` (no route/DNS/TLS — the request never got a response) into
`NetworkException`, and `dart:async`'s `TimeoutException` (name collision with this app's own
`TimeoutException` in `exceptions.dart` — handled via an aliased import) into it. `http.ClientException`
(connection refused/reset) is matched by runtime-type-name string rather than a direct import, since
`http` is only a transitive dependency via `supabase`/`gotrue`/`postgrest`, not a direct one this app
should couple to.

**`resolveWriteErrorMessage`** (new, `core/errors/error_message_resolver.dart`): the single place
every write-action `catch` block now goes through — maps `NetworkException`/`TimeoutException`/
`ConflictException`/`ValidationException`/`ForbiddenException`/`UnauthorizedException` to their real,
already-existing `errors.*` translations, falling back to the caller's action-specific message only
for a genuinely unclassified error. Wired into `add_record_screen.dart`, `detail_screen.dart`
(`_updateField`/`_deleteParcel`/`_reopenParcel`), `parcel_detail_card.dart` (`_copyId`), and
`file_status_screen.dart` (replacing its stray `errors.unknown`-only catch).

**Loading indicators** for the four actions that had none:

- `ParcelIdChip` (copy-ID/review) gained `isLoading` — spinner replaces the fingerprint icon, tap
  disabled. `ParcelDetailCard` itself stays a `StatelessWidget` (converting the whole ~600-line card
  would be a much larger, unrelated diff); a new small `_ReviewIdChip` wrapper owns the in-flight
  state locally instead.
- `ParcelDetailTopRow` gained `isDeleting`/`isReopening` — same icon-swap treatment on the delete
  `IconButton` and reopen `FilledButton`.
- `DetailScreen._isBusy` (a single screen-wide bool, driving no UI) became `_busyParcelIds` (a
  `Set<String>`, keyed by parcel id) — necessary since several parcel cards are on screen at once and
  deleting one must not visually block reopening a different one. Threaded into `ParcelDetailCard`'s
  new `isDeleting`/`isReopening` props.
- Add/bulk-edit already had loading UI via `CustomTextButton.isLoading` — untouched, just had their
  error-catch blocks routed through the same resolver for consistency.

**Dependencies:** none. **Complexity:** medium — required surveying all 6 write actions first
(delegated to an Explore agent) to design one consistent solution instead of patching each in
isolation, then reasoning through which raw exception types Supabase/Dart actually throw for a true
offline failure vs. a server rejection.

**Risks:** low. `ErrorHandler`'s new classification only adds new `if` branches ahead of the existing
fallback — no existing classification path changed. Loading-state props all default to `false`,
matching prior behavior exactly when unset. `resolveWriteErrorMessage`'s fallback parameter means
every call site keeps its own accurate action-specific message for the truly-unknown case, not a
blanket generic string.

flutter analyze: clean. flutter test: 312/312 passing (15 new: `error_message_resolver_test.dart`
(6, using the real `assets/lang/ar.json` strings via the shared `pumpLocalized` harness, not `.tr()`'s
silent raw-key fallback), `error_handler_test.dart` (7, verifying the actual exception→type
classification), and 2 new widget tests in `parcel_detail_card_test.dart` for the delete/reopen
spinner states — needed an explicit timer-flush pattern since `CircularProgressIndicator`'s
indeterminate animation never lets `pumpAndSettle` complete on its own).

## Phase 22 — revert Supabase-domain connectivity check (2026-08-10)

**Status: done.** Phase 16's connectivity check pinged the bare Supabase domain
(`https://<project>.supabase.co`, no path) directly, reasoning that checking the app's actual
backend is more accurate than an arbitrary public host. In practice: that domain is
Cloudflare-fronted with bot management (a `__cf_bm` cookie on every response) and returns a bare
`404` to a plain HEAD request (`curl -I` confirmed this directly) — behavior an Android emulator's
network stack apparently handled inconsistently, since the app-launch "no internet" dialog started
firing on every attempt even though the rest of the app could reach Supabase's real REST API fine
and had real data loaded on screen.

**Fix:** `core_module.dart`'s `_connectivityCheckAddresses()` no longer includes the Supabase URL at
all — reverted to checking only `one.one.one.one`/`dns.google`, the two well-known hosts that behave
predictably everywhere. `AppConfig.supabaseUrl` (the getter added for this) is left in place since
it's a small, correctly-named, potentially-useful-later utility — just no longer wired into the
connectivity check.

**Dependencies:** none. **Complexity:** low — the fix is a straightforward revert once the actual
`curl` response revealed what was different about the bare domain vs. `one.one.one.one`/`dns.google`.

**Risks:** low. This is a net-narrower check (fewer addresses = less surface for a false negative on
an unrelated host), and matches what worked reliably before Phase 16.

flutter analyze: clean. flutter test: 312/312 passing (no test change needed — no test asserted on
the specific address list, only on `NetworkInfo`'s behavior given a fake, which is unaffected).

---

## Phase 23 — Blocking UI during critical, server-confirmed writes

**Problem:** Phase 19 already made every critical write (add parcel, edit field, mark reviewed/
reopen, delete) online-first-when-possible: when online, each method awaits the real Supabase
round-trip before mutating local state or returning, so success is never shown before the server has
actually confirmed the write, and a failure throws a real, classified error instead of landing
silently in the outbox (`HoldingsRepository` class doc, `holdings_repository.dart:41-60`). What was
still missing: nothing stopped the user from navigating away (back gesture/button) or interacting with
other on-screen controls while one of these awaits was in flight — only same-row double-tap was
guarded (`_busyParcelIds`, `_isSaving`).

**Fix:** added `BlockingLoadingOverlay` (`core/widgets/ui/loaders/blocking_loading_overlay.dart`) — a
reusable full-screen modal veil (opaque barrier + centered spinner + message) that also disables the
system back gesture via an internal `PopScope`. Wired into:

- `AddRecordScreen.build` — visible for the duration of `_save`'s awaited `addLocalParcel` call, with
  an outer `PopScope.canPop` now also gated on `!_isSaving` (previously only unsaved-changes-gated).
- `DetailScreen.build` — a new `_busyMessage` string (action-specific: saving/deleting/reopening) set
  right before each of `_updateField`/`_deleteParcel`/`_reopenParcel`'s awaited repository call and
  cleared in every `finally`, driving both the overlay and a `PopScope` that blocks navigation while
  any one of them is in flight.
- Copy ID/review (`ParcelDetailCard._copyId`/`_ReviewIdChip`) deliberately kept as its own per-card
  inline spinner rather than escalated to the screen-wide overlay — it already fully awaits server
  confirmation with an accurate loading/error state, and is scoped to the one card being reviewed;
  forcing every other card and the whole screen to block for an idempotent, low-risk action would be
  over-blocking relative to the actual risk of interruption.

Also corrected a now-misleading string: `holdings.add.saved` was `"تم الحفظ، سيتم رفعها عند توفر
الاتصال"` / `"Saved — will upload once you're online"` — a leftover from the pre-Phase-19 pure-outbox
model. Since the online path now already confirms the write before this message ever shows, it now
reads `"تم الحفظ بنجاح"` / `"Saved successfully"`. Added matching `*_in_progress` strings for each
action's overlay message.

**Dependencies:** Phase 19 (the awaited-write behavior this overlay makes visible/uninterruptible).
**Complexity:** low — one new stateless widget, three call sites wired.

**Risks:** low. The offline fallback path (genuinely offline, `_syncRunner != null && !await
_isOnline()`) is untouched — it still applies locally and enqueues instantly, so the overlay is only
ever visible for the duration of a real, brief network round-trip, never for an indefinite queued
write.

flutter analyze: clean. flutter test: 312/312 passing.

---

## Phase 24 — Add-person/add-parcel promotion-race bugs (duplicate/empty cards, orphaned second parcel)

**Problem:** field-reported — "add a new person, search for them, details screen shows no data" and
later "search shows two cards, one with the parcel, one empty." Root cause: `added_holdings_auto_approve`
(the DB trigger) promotes every field-created record into `holdings` synchronously, in the same
transaction as the insert. That means the awaited HTTP response (`addLocalParcel`'s online path) and
up to three independent Realtime events for the exact same underlying write (`added_holdings` INSERT,
`added_holdings` UPDATE setting `promoted_holding_id`, `holdings` INSERT) can arrive in almost any
order relative to each other. Four distinct bugs fell out of this:

1. `ParcelDatasetState.removeWhereIdOrSource`/`findByIdOrSource` matched by `sourceAddedHoldingId` as
   well as exact `id` — the "this added*holdings row is now superseded, remove it" handling
   (`handleAddedHoldingsPayload` in `realtime_payload_dispatcher.dart`) fires an `applyRemoteDelete`
   keyed on the \_pre-promotion* `added_holdings.id`. If that echo arrived after the local device had
   already applied the promoted parcel (now living under a _different_ `id`, with the old id only
   surviving as `sourceAddedHoldingId`), the wildcard match deleted it anyway — the empty-details bug.
2. `HoldingsRepository.addLocalParcel`'s local `applyLocally` used to blindly `_dataset.append(...)`
   instead of reconciling with an entry a racing Realtime echo might already have added for the exact
   same write — the two-cards-one-empty duplicate bug, when the `added_holdings` INSERT echo (still
   under the pre-promotion id) was processed before the awaited HTTP response returned.
3. `deleteLocalParcel`'s own local filter mirrored the same unsafe `sourceAddedHoldingId`-or-`id`
   match `removeWhereIdOrSource` was just narrowed away from — not currently exploitable (each row's
   `sourceAddedHoldingId` is unique today) but the same risky pattern, left in a second place.
4. `addLocalParcel`'s `parentHoldingId` → parent lookup matched only by exact `id` against the live
   dataset. `DetailScreen._addParcelForPerson` passes `source.id` from its own screen-local `_parcels`
   snapshot; if the parent had already been promoted (id changed) before this add's `parentHoldingId`
   was captured, the lookup silently missed and the new parcel got its own fresh `personId`/`groupKey`
   instead of joining the intended person — appearing as an unrelated new person in search, no error
   shown anywhere.

**Fix:**

1. `removeWhereIdOrSource`/`findByIdOrSource` now match only by exact `id` — a
   `sourceAddedHoldingId`-based supersede-delete can never remove an entry that's already moved on to
   a different id.
2. Added `ParcelDatasetState.upsert()` (same id-or-`sourceAddedHoldingId` matching
   `applyRemoteChange`/`indexOfForRemoteChange` already used) and switched `addLocalParcel`'s
   `applyLocally` to use it instead of `append` — whichever of the awaited response and the Realtime
   echo lands second now reconciles with the first instead of duplicating it.
3. `deleteLocalParcel`'s local filter now matches by exact `id` only, same as (1).
4. `addLocalParcel`'s parent lookup now falls back to a `sourceAddedHoldingId` match when the exact
   `parentHoldingId` isn't found in the live dataset — the promoted entry's `sourceAddedHoldingId`
   still equals the pre-promotion id the caller may be holding.

**Dependencies:** none — all four are self-contained fixes inside `HoldingsRepository`/
`ParcelDatasetState`. **Complexity:** low per fix, but required a careful skeptical re-audit (a
dedicated read-only Explore pass) of every write path for the same race shape before considering this
closed — (3) and (4) were found only by that follow-up audit, not the initial fix.

**Risks:** low. Each fix narrows an overly-broad match to an exact one, or adds a narrowly-scoped
fallback (4) — none change behavior for the non-racing, already-correct common case.

Regression tests added: `parcel_dataset_state_test.dart` (2 tests corrected — they'd encoded the old,
buggy match behavior as expected), `holdings_repository_add_local_parcel_test.dart` (2 new tests:
promoted-parcel survives its own supersede-echo delete; racing INSERT echo reconciles instead of
duplicating; 1 new test: stale parentHoldingId falls back correctly),
`holdings_repository_delete_local_parcel_test.dart` (1 new test: delete never wildcard-matches a
different parcel sharing a `sourceAddedHoldingId`).

**Follow-up (same phase): two more bugs found in the same skeptical re-audit, plus a stale-index race
in `setParcelCompleted`/`updateParcel`.**

5. `HoldingsApi.markCompleted` never checked the `mark_parcel_completed` RPC's `found` column — when
   the client's `isFieldAdded`/`parcelId` pairing was stale (pointed at the wrong table after a
   promotion the local dataset hadn't reconciled yet), the RPC ran its `UPDATE ... WHERE id = ...`
   against zero matching rows, returned `found: false, conflict: false`, and the client treated that
   as success. Field symptom: "Copy ID / mark reviewed" on a still-pending record throwing a generic
   "couldn't update the review status" error, or — worse, before this fix — silently reporting success
   with nothing actually written server-side.
6. `HoldingsRepository.setParcelCompleted`/`updateParcel` each captured `_dataset.indexOf(...)` once
   _before_ their awaited network call, then reused that numeric index afterward to apply the local
   write (`_applyCompletedLocally`/`applyLocally`'s `_dataset.replaceAt(idx, ...)`). If a Realtime
   event appended or removed an entry in `_dataset.parcels` while the await was in flight — shifting
   every later array position — the stale index could apply the confirmed write onto a completely
   unrelated parcel.

**Fix (5):** `markCompleted` now throws `NotFoundException` when `found != true`, wired through
`resolveWriteErrorMessage` to the existing `errors.not_found` string — this class of stale-id bug is
now a visible, accurate error instead of a silent no-op or a generic message. **Fix (6):**
`setParcelCompleted`/`updateParcel` now re-resolve the index by id (`_dataset.indexOf(parcelId)`)
immediately before applying the local write, instead of trusting the pre-await snapshot; a lookup miss
after the await (the entry having been removed entirely by a Realtime event in between) is treated as
a no-op rather than applying to whatever now occupies that stale position.

Regression tests added: `holdings_repository_set_parcel_completed_test.dart` (1 new test: a Realtime
insert during the RPC await must not redirect the completion onto the new, unrelated entry),
`holdings_repository_online_sync_test.dart` (1 new test: same shape for `updateParcel`).

flutter analyze: clean. flutter test: 318/318 passing.

---

## Phase 25 — Copy ID/mark-reviewed: honest messaging + reconciliation on an uncertain timeout

**Problem:** field-reported — the red snackbar "تم نسخ المعرّف، لكن تعذّر تحديث حالة المراجعة — حاول
مرة أخرى" (generic Copy ID failure) kept appearing, inconsistently: "sometimes it gives the same
message but the button logic work[s] and sometimes not." Verified via the live Supabase project
(`bbahuyqjptojlighriyy`, `get_logs`/`execute_sql`) that: the six Phase 24 fixes are present and match
the live `mark_parcel_completed` RPC exactly (ruling out a regression); every logged
`POST /rest/v1/rpc/mark_parcel_completed` call returns HTTP 200 (Postgrest never surfaces a
server-side error for this RPC — success/conflict/not-found are all in the JSON body, not the status
code). Combined with the exact snackbar text being `_copyId`'s generic fallback (only reached when the
caught error isn't `ConflictException` and isn't a type `resolveWriteErrorMessage` recognizes), and the
user confirming this happens on repeated taps/multiple devices, the root cause is
`HoldingsApi._requestTimeout` (15s) firing on slow/unstable field connectivity **after the RPC has
already committed server-side**: the client throws, shows an error, but the write already succeeded —
exactly "sometimes it works anyway even though it shows an error."

**Fix:**

1. New `HoldingsApi.fetchParcelById(id, {isFieldAdded})` — reads a single row's current server state
   from `holdings`/`added_holdings` (tries the table matching the last-known `isFieldAdded` first, both
   if unknown), returning `null` (never throwing) if not found in either — a failed reconciliation read
   is "still uncertain," not its own separate error.
2. New `HoldingsRepository.refreshParcel(parcelId)` — calls `fetchParcelById` and applies whatever it
   finds via the existing `applyRemoteChange` upsert path, same reconciliation shape Phase 24 already
   uses for Realtime echoes.
3. `resolveWriteErrorMessage` gained an opt-in `timeoutOutcomeUncertain` parameter — when `true`, a
   `TimeoutException` resolves to a new `errors.timeout_uncertain` string ("انتهت مهلة الاتصال، لكن
   العملية قد تكون قد تمت بالفعل") instead of the plain `errors.timeout` "try again" wording, which
   would be actively misleading for a write that might have already succeeded. Deliberately opt-in, not
   a blanket change to every write's timeout message — most writes (edit, delete) aren't idempotent-safe
   to reconcile this way and should keep the unambiguous "try again" wording.
4. `ParcelDetailCard._copyId` gained an `on TimeoutException` branch (previously falling into the
   generic `catch`): shows the uncertain-outcome message, then awaits `refreshParcel` — if it confirms
   `completedAt` is now set, reflects the reviewed state via `onCompleted` (same as a normal success)
   and shows a "confirmed after timeout" success message; if the parcel still isn't found reviewed (or
   the reconciliation read itself fails, e.g. still offline), shows a "still uncertain, check later"
   message and leaves local state untouched — never guesses or forces a false reviewed state.

**Dependencies:** Phase 24's `applyRemoteChange`/upsert reconciliation path (reused directly, not
duplicated). **Complexity:** medium — touches four files plus 7 test-double fakes that needed the new
`HoldingsApi.fetchParcelById` member added (a plain concrete class, so every `implements HoldingsApi`
fake needed an explicit override).

**Risks:** low. `refreshParcel` never throws and never asserts a positive result on failure to read —
the worst case on a still-genuinely-offline device is the same "still uncertain" message as before,
never a false "reviewed" claim. The `ConflictException` path (a real conflict — someone else already
completed it) is untouched, still its own distinct, already-accurate message.

Regression tests added: `error_message_resolver_test.dart` (1 new test: `timeoutOutcomeUncertain: true`
resolves to the new string, not plain `errors.timeout`), `parcel_detail_card_test.dart` (2 new tests: a
timeout that turns out to have succeeded reconciles to reviewed via `onCompleted`; a timeout that
genuinely didn't go through shows the uncertain message and never claims success) — plus a no-op
`fetchParcelById` override added to the `_FakeHoldingsApi` in every other repository test file so they
keep compiling against the now-larger `HoldingsApi` interface.

flutter analyze: clean. flutter test: 321/321 passing.

**Follow-up (same phase): the actual root cause, found via debug logging added on request.**

Phase 25's reconciliation logic above was built on a hypothesis (a 15s timeout racing a
server-side-committed write) that turned out to be wrong — added `debugPrint` tracing through the whole
`_copyId` → `setParcelCompleted` → `markCompleted` chain, and the very first real device log showed the
true cause immediately:

```
[markCompleted] parcelId=... threw _TypeError: type 'List<dynamic>' is not a subtype of type
'List<Map<String, dynamic>>'
```

**Root cause:** `HoldingsApi.markCompleted` declared `final List<Map<String, dynamic>> rows =
await _client.rpc('mark_parcel_completed', ...)`. Supabase's `.rpc()` call returns `dynamic` — the
underlying JSON array deserializes as a plain `List<dynamic>` whose _elements_ happen to be
`Map<String, dynamic>`, but the outer `List` itself is never statically typed as
`List<Map<String, dynamic>>`. Assigning it directly to that typed variable throws a runtime
`_TypeError` on **every single call**, unconditionally — not a race, not a timeout, not something that
only happens on slow connections. This explains why the error was so persistent and (from the user's
perspective) inconsistent: the RPC itself always succeeded server-side (confirmed earlier via Supabase
logs, Phase 25's first pass), so the _review status_ was frequently already correct by the time the
user re-checked, while the _client_ threw on every call — exactly "sometimes it works anyway even
though it shows an error."

**Fix:** cast the RPC result explicitly — `(rawResult as List).map((row) =>
Map<String, dynamic>.from(row as Map)).toList()` — instead of relying on an implicit type-annotation
cast. Checked every other query in `holdings_api.dart` for the same pattern: all other call sites use
`.from(table).select()`, which returns Supabase's own properly-typed `PostgrestList`
(`List<Map<String, dynamic>>`) already — `.rpc()` was the only call using the unsafe direct-cast shape.

The Phase 25 reconciliation logic (timeout → `refreshParcel` → confirm-or-uncertain messaging) is left
in place even though the originally-hypothesized timeout race turns out to be rare in practice — it's
still correct, harmless, low-risk behavior for the genuine case of a slow/unstable connection, just no
longer the primary explanation for what the user was hitting on every tap.

flutter analyze: clean. flutter test: 321/321 passing (no test changes needed for this fix — the bug
was in an implicit-cast type declaration no fake/mock reproduces, since test doubles return
already-correctly-typed `List<Map<String, dynamic>>` literals directly).

**Second follow-up (same phase): the actual real-world case caught live via debug logging —
`NotFoundException` from a stale `isFieldAdded` never reached the reconciliation path at all.**

With the type-cast crash fixed, the very next real device log showed the RPC now running cleanly and
returning a legitimate `found: false, conflict: false` — confirmed against the live DB
(`bbahuyqjptojlighriyy`) that the parcel genuinely existed, just in `holdings`, not `added_holdings`:
a field-added record that had already been promoted server-side (`REFACTOR_ROADMAP.md` Phase 24's
promotion area), whose local `Parcel.isFieldAdded` on this device was still `true`. `markCompleted`
correctly threw `NotFoundException` for this (Phase 24's fix), but two things then went wrong:

1. `_copyId`'s catch chain only special-cased `ConflictException`/`TimeoutException` —
   `NotFoundException` fell into the generic `catch`, showing the same unhelpful fallback message this
   whole phase was meant to eliminate.
2. `HoldingsRepository.refreshParcel` passed the local dataset's (stale) `isFieldAdded` as a hint into
   `fetchParcelById`, which made it search only the wrong table — repeating the exact mistake
   reconciliation exists to correct.

**Fix:**

1. `refreshParcel` no longer passes the local `isFieldAdded` hint at all — `fetchParcelById(parcelId)`
   with no hint checks both `holdings` and `added_holdings`, so a stale local flag can no longer point
   the reconciliation read at the wrong table.
2. `_copyId` gained an `on NotFoundException` branch: unlike a timeout (where the write's outcome is
   genuinely unknown), `found: false` means the write definitely did **not** happen — so after
   `refreshParcel` corrects the local dataset's `isFieldAdded` (via the `applyRemoteChange` call inside
   it), `_copyId` retries `setParcelCompleted` once with the now-correct value. `setParcelCompleted`
   always reads `isFieldAdded` fresh from the dataset at call time, so the retry automatically uses the
   corrected flag. A `ConflictException` on the retry (someone else completed it in the meantime) shows
   its own accurate message; any other retry failure falls back to the standard
   `resolveWriteErrorMessage` path. From the user's perspective this self-heals and completes
   transparently — no second tap required.

**Dependencies:** the type-cast fix above (without it, `NotFoundException` was never reliably
distinguishable from the crash). **Complexity:** low-medium — one repository-level parameter removed,
one new catch branch with its own nested try/retry.

**Risks:** low. The retry only fires for the specific case where the server has just told us,
authoritatively, that the write didn't happen — never a blind retry on an ambiguous failure.

Regression test added: `parcel_detail_card_test.dart` — a parcel whose local `isFieldAdded: true` is
stale (the row actually lives in `holdings`) throws `NotFoundException` on the first `markCompleted`
call, reconciles, and the retry (now with `isFieldAdded: false`) succeeds — asserts exactly 2
`markCompleted` calls and the normal success message, not a manual-retry-required error.

flutter analyze: clean. flutter test: 322/322 passing.

**Third follow-up (same phase): the NotFoundException retry looped forever — `Parcel.isFieldAdded`
doesn't mean what its own doc comment claimed.**

The very next real device log (after the type-cast and NotFoundException-retry fixes above both
landed) showed the retry loop still failing on the _second_ attempt too, with the exact same
`isFieldAdded=true` sent both times — even though `refreshParcel`'s reconciliation read had correctly
found the row in `holdings`. Tapping Copy ID again made the parcel disappear from the list entirely
(a downstream symptom of the repeated `NotFoundException` never resolving).

**Root cause:** `Parcel.isFieldAdded`'s doc comment (written well before Phase 24's
`preserve_added_provenance_on_promotion` migration) claimed it "discriminates which table this parcel
lives in." That was true once, but Phase 24 deliberately made `holdings.is_field_added` a **permanent
provenance marker** that stays `true` forever after promotion (so the "مضافة من التطبيق" badge keeps
working on a promoted row) — nothing ever updated this doc comment or the code that still relied on the
old contract. `holdingRowToParcel` correctly reads the raw (now-permanent) `is_field_added` column, so
`refreshParcel`'s reconciled `Parcel` still had `isFieldAdded: true` even though the row was
unambiguously in `holdings` — the retry read the same wrong signal and failed identically, forever.

**Fix:** added `Parcel.isCurrentlyInAddedHoldings` — the actually-correct "which table" signal,
short-circuiting `false` for a genuine import (`isFieldAdded == false`, always unambiguous), otherwise
derived from `sourceAddedHoldingId`: `null` or equal to `id` means still in `added_holdings`
(unsynced-local or synced-unpromoted); different from `id` means promoted into `holdings`. Replaced
every table-routing use of `isFieldAdded` with this new getter: `setParcelCompleted`'s RPC parameter
and outbox-enqueue payload, and `addLocalParcel`'s `safeParentHoldingId` FK-safety check (which had the
identical bug — a promoted parent's `id` could get wrongly treated as still needing to be nulled out).
`Parcel.isFieldAdded`'s doc comment was corrected to state its actual, current meaning (permanent
provenance) and explicitly warn against using it for table routing.

**Dependencies:** the two fixes immediately above (this was blocking their retry logic from ever
actually working). **Complexity:** low — one new getter, three call-site swaps, one doc correction.

**Risks:** low, but required fixing two existing test fixtures whose `Parcel(...)` literals had no
`sourceAddedHoldingId` set while intending to represent genuine imports — under the getter's first
version (before the `isFieldAdded` short-circuit was added), those fixtures were indistinguishable from
a brand-new unsynced field-added parcel. Corrected by adding the `isFieldAdded` short-circuit rather
than patching the fixtures, since the getter's original logic was the actual bug the fixtures exposed.

Regression tests added: `parcel_pending_test.dart` (4 new tests covering all four
`isCurrentlyInAddedHoldings` cases: genuine import, brand-new unsynced, synced-unpromoted, promoted).

flutter analyze: clean. flutter test: 326/326 passing.

**Fourth follow-up (same phase): a successful Copy ID could make the whole detail screen go blank
immediately after — `DetailScreen`'s captured `_groupKey` can go stale mid-session.**

With the retry loop now actually resolving, the next real device log showed Copy ID succeeding cleanly
— but the detail screen it was tapped from immediately showed "لا توجد بيانات لهذه الحيازة" (no data
for this holding) on every tab, even though the person genuinely still had data server-side.

**Root cause:** `DetailScreen._groupKey` is captured once at `initState` from the first parcel in the
list it was opened with, and every subsequent `_refreshFromRepository()` call (on this screen's own
writes and on every incoming `onRemoteChange` event, including ones this screen didn't cause) re-queries
`_repository.parcelsForHolding(_groupKey)` using that fixed value. `Parcel.groupKey` for a still-pending
record (`holdingId` placeholder) is derived from `personId ?? pendingGroupId ?? id` — stable as long as
`personId` doesn't change. Traced via the live DB (`bbahuyqjptojlighriyy`): the specific parcel that
went through the `NotFoundException`-then-retry cycle had a `person_id` populated server-side that this
device's local copy apparently hadn't captured yet (most plausible for an older locally-cached parcel
predating `person_id` being consistently populated) — `refreshParcel`'s reconciliation read pulled the
authoritative row, and `applyRemoteChange`'s "prefer the existing local value, fall back to the incoming
one" merge (`_dataset.parcels[idx].personId ?? updated.personId`) then adopted the server's `person_id`
since the local one was `null`. That's correct behavior for the dataset itself, but it means the
parcel's `groupKey` legitimately changed mid-session (`'pending:<id>'` → `'pending:<personId>'`) — and
`DetailScreen`'s `_groupKey`, captured before that change, silently stopped matching anything.

**Fix:** `_refreshFromRepository()` now falls back to re-deriving `_groupKey` when a query against the
currently-held one returns zero results but the screen previously had parcels: it re-reads each
currently-shown parcel's _current_ `groupKey` from the repository and retries the query with that,
adopting it as the new `_groupKey` the moment one produces results. Added `debugPrint` tracing at each
step so the exact trigger is fully visible if this recurs. Deliberately reactive (only kicks in on an
otherwise-would-be-empty result) rather than proactively re-syncing `_groupKey` on every refresh, so an
unrelated update elsewhere can't cause `_groupKey` to visibly ping-pong.

**Dependencies:** none — self-contained to `DetailScreen`. **Complexity:** low.

**Risks:** low. The fallback only ever activates when the primary query would otherwise show an empty
screen (a strictly worse outcome), and only ever adopts a `groupKey` that a currently-known parcel id
genuinely still has server-side.

**Not yet covered by an automated test** — `DetailScreen` has no existing widget-test harness (routing/DI
scaffolding not yet built for it), and reproducing this specific mid-session `personId`-population race
in a unit test would need the same scaffolding. Left as a manual-verification item; the debug logging
added here will confirm on the next occurrence whether this exact mechanism is what's firing.

flutter analyze: clean. flutter test: 326/326 passing (no test count change — this fix has no
automated coverage yet, see above).

**Fifth follow-up (same phase): require a real رقم الحيازة before a new person/parcel can be saved.**

Every bug this whole phase traced (empty details after add, duplicate cards, the review retry loop, the
detail-screen blanking) shared one root condition: a field-added parcel left at the `"-1"` رقم الحيازة
placeholder is "pending," and every write path downstream has to carry extra logic to handle a pending
record's shifting identity (`groupKey` keyed off `personId` instead of `holdingId`, promotion timing,
etc.). Per explicit request, رقم الحيازة now joins the existing required-field set
(اسم الحائز/اسم الحوض/نوع الزرع) — a field worker must enter a real holding number before Save is
enabled, closing off this whole class of ambiguity at the source rather than continuing to reconcile it
downstream.

**Fix:**

1. `Parcel.hasRequiredFieldsFilled` now also checks `!isHoldingIdPending` (the existing getter that
   already treats `""`/`"-"`/`"-1"` as not-yet-assigned) — `AddRecordScreen._canSave` already gates
   directly on this getter, so Save is now disabled until a real number is entered, with no separate
   change needed in the screen itself.
2. `requiredFieldGapMessages` gained a new first-listed message (`holdings.add.holding_id_required`,
   matching رقم الحيازة's position at the top of the form) for the pending case.
3. `AddRecordScreen`'s رقم الحيازة field label gained the `*` required-marker, matching every other
   required field's existing convention.

**Dependencies:** none — self-contained to the shared `hasRequiredFieldsFilled` gate already used by
both `AddRecordScreen`'s save button and `ParcelDetailCard`'s Copy ID review gate. **Complexity:** low.

**Risks:** low-medium. This is a genuine behavior change, not just messaging — a field worker can no
longer create a new person/parcel without immediately knowing/entering its official number, which may
not always be available at time of entry in the field. Accepted as the explicit tradeoff requested,
given the alternative was leaving the entire pending-parcel reconciliation surface open indefinitely.
Existing already-pending parcels created before this change are unaffected — this only gates _new_
saves going forward, not a migration of past records.

Regression tests added: `parcel_national_id_test.dart` (4 new cases: `"-1"`, blank, `"-"`, and a real
number), `required_field_gaps_test.dart` (new file, 3 tests: the real Arabic message shows, a complete
parcel shows nothing, and the holding-id message is listed first) — plus one existing
`parcel_detail_card_test.dart` fixture (`p-stale-field-added`) updated from a pending `"-1"` to a real
holding number, since it was inadvertently relying on the now-closed pending path to reach the
reconciliation logic it's actually testing.

flutter analyze: clean. flutter test: 333/333 passing.

**Sixth follow-up (same phase): allow "-1" as a deliberate, explicitly-entered value.**

Per explicit follow-up request: the required-field rule above was too strict — رقم الحيازة needed to
stay required (forcing an explicit choice, not a silent default), but a field worker who genuinely
doesn't yet have the official number must still be able to type `"-1"` themselves as an intentional
sortable placeholder, not be permanently blocked from saving.

**Fix:**

1. New `Parcel.isHoldingIdExplicitlyEntered(value)` — rejects only blank/whitespace-only input,
   deliberately allowing `"-1"` (unlike [isHoldingIdPending], which still treats `"-1"` as pending —
   that getter is untouched, since `groupKey`/search grouping must keep working exactly as before for
   a manually-entered `"-1"`). `hasRequiredFieldsFilled`/`requiredFieldGapMessages` switched to this
   new check.
2. Critical companion change: `AddRecordScreen`'s رقم الحيازة field, `HomeScreen._openAddPerson`'s
   initial `Parcel`, no longer auto-fill/reset to `"-1"` — the field now starts and stays genuinely
   blank until the user types something. Without this, the auto-filled `"-1"` would satisfy the
   now-more-permissive required check without the user ever touching the field, silently defeating the
   point of making it required in the first place (confirmed via explicit user sign-off before
   implementing, given the ambiguity).
3. `DetailScreen._addParcelForPerson` (add a parcel for an _existing_ person) intentionally left
   unchanged — it inherits the parent's real, already-assigned رقم الحيازة via `source.copyWith(...)`,
   which is correct as-is; only the _new person_ flow needed the blank-by-default change.

**Dependencies:** the prior required-field-gate follow-up in this same phase. **Complexity:** low.

**Risks:** low. Existing already-saved parcels (whether their رقم الحيازة is a real number or a
previously-defaulted `"-1"`) are unaffected — this only changes the save-time gate and the form's
initial/cleared value going forward.

Updated regression tests: `parcel_national_id_test.dart` (`"-1"` now asserts `isTrue`, blank/
whitespace-only still `isFalse`), `required_field_gaps_test.dart` (added a case confirming `"-1"`
produces no gap message, existing cases switched from `"-1"` to blank to still exercise the
required-message path).

flutter analyze: clean. flutter test: 334/334 passing.

---

## Sequencing summary

Phases 1 and 3 can start immediately and run in parallel. Phase 2 — the highest-risk, highest-value
phase — should start once Phase 1's schema lands, so the Flutter rebuild targets the final schema
rather than migrating twice. Phase 4 follows once 1–3 are stable.

**Phase 1 execution order (resolved 2026-08-06, see the classification table above):** every "Safe
before release" item (1, 2, 3-table, 7, 8, 9, 10) can be written and deployed together as one batch —
none has a dependency on another within that set. The `editable_fields` trigger ships warn-only in the
same batch; its promotion to reject-mode is a separate, later step gated on an observation window. The
`commit_import_batch` dedup guard (11) and the legacy id/client_id backfill (12) are each their own
single-item change, deployed independently with their own verification pass — never bundled into the
same deploy as the additive batch, so a problem with either is trivially isolated and rolled back
without touching the unrelated additive work.

## Gate discipline (carried forward from the app's own prior planning convention, applied platform-wide)

Every phase ends at a gate, not "it looks done": for Flutter, `flutter analyze` clean and `flutter test`
green plus a manual walkthrough of the phase's stated flow; for the Dashboard, typecheck + lint + unit
tests + the relevant E2E spec green; for the database, RLS and constraints verified by hand for every
role × table × operation touched. Do not start the next phase until the current one's gate is green.

---

## APP_UPDATES_CLAUDE.md — post-freeze feature batch

Implemented on top of the frozen v1 roadmap above; not itself part of the phase sequence, but cited
here since later code comments reference "APP_UPDATES_CLAUDE.md § N" as rationale.

- **Basins as first-class data**: `basins` Supabase table downloaded alongside a city's parcels
  (`CityDownloadResult`), cached in `CitySnapshot.basins`, surfaced via `HoldingsRepository
.activeBasins`/`basinByName`. `basin_picker.dart`'s `pickBasin`/`applyBasinPick` always derives
  `basinCode` from the picked `basinName` — never user-typed.
- **Add flow split**: `AddModeToggle` (شخص جديد / شخص موجود) gates `AddRecordScreen` when reached
  from a generic "+" entry point; "شخص موجود" shows `ExistingPersonSearch` (exact رقم الحيازة match)
  and inherits اسم الحائز/الرقم القومي/اسم المالك on confirm, blanking اسم الحوض/كود الحوض/المساحة/
  نوع المحصول/مراحل النمو/ملاحظات for fresh entry — mirrors `DetailScreen._addParcelForPerson`'s
  existing inheritance shape.
- **Navigation restructure**: `HomeTopBar` dropped the Wi-Fi/connectivity badge entirely; its three
  icons now open Basins (own route, `BasinsPage`)/City Tools/city-picker. Home's body is a flat,
  unfiltered `HoldingsRepository.allHoldings` list instead of basin-grouped cards.
- **`UsageType`** (`data/model/usage_type.dart`) is a typed enum view (`agricultural`/`buildings`/
  `fallow`) over `Parcel.usageType`'s existing Arabic-string storage — chosen over converting the
  field itself to avoid rewriting 8+ call sites for a codebase convention (string-typed option
  fields) that every sibling field already follows. `UsageTypeNotesSync` (`data/local/`) is the
  single bidirectional نوع الاستخدام↔ملاحظات implementation, called from both `AddRecordScreen` and
  `SeeMoreSection`/`ParcelDetailCard` so the two forms can't drift. نوع المحصول/مراحل النمو rows are
  conditionally omitted (not disabled) outside `agricultural`, including in `ClipboardFormatter`'s
  copy-all text.
- **Notes list**: `NotesListService` (SharedPreferences-backed, DI-registered in
  `holdings_module.dart`) layers user-added custom notes on top of `Parcel.notesOptions`' fixed
  built-in list; `add_note_dialog.dart`'s quick-pick now reads through it. `notes_settings_sheet.dart`
  (reachable from City Tools) is the add/remove UI — editing the list never touches notes already
  saved on a parcel.
- **مفوض dialog gap closed**: `SeeMoreSection`'s Detail-Screen توجل had been setting `isDelegate`
  directly, bypassing `showDelegateOwnerDialog` and its "must differ from اسم الحائز" validation —
  only `AddRecordScreen` went through the dialog. Both now share the same enable/disable shape:
  enabling opens the dialog and appends the "مفوض عنه {holder}" note; disabling reverts اسم المالك to
  اسم الحائز and strips any note starting with "مفوض عنه".
- **Search**: `HoldingSearchService.searchByHolderName` replaced its three-tier (full-name-start /
  word-start / contains-anywhere) scoring with a single startsWith-by-word-position scheme — the
  earliest matching word wins, no contains-anywhere fallback tier.
- **`land_number` (رقم الأرض) default changed from `"-1"` to `"0"`** in `AddRecordScreen`,
  `BasinScreen._addParcelForBasin`, `DetailScreen._addParcelForPerson`, and `LoadingBody
._openAddPerson`. Deliberately scoped to رقم الأرض only — رقم الحيازة (`holdingId`) keeps `"-1"` as
  its pending-record sentinel (`Parcel.isHoldingIdPending`), since a blanket `"-1"`→`"0"` rewrite
  would collide with `Parcel.isHoldingIdMissingOrZero`'s existing "0 means lost data" semantics for
  that field.

flutter analyze: clean. flutter test: 288/288 passing.
