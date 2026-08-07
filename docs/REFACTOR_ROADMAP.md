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

| # | Item | Scope | Classification | Notes |
|---|---|---|---|---|
| 1 | `association_types` reference table (`DATABASE_REFERENCE.md` §4.1) | `create table association_types (...)`; seed 2 current values; `cities.association_type_code` new nullable column | **Safe before release** | Existing `association_type` enum untouched; Dashboard mgmt UI is separate follow-up work |
| 2 | `holding_edits.holding_type` discriminator (§4.2, §7.1) | `alter table holding_edits add column holding_type text not null default 'holding' check (...)` | **Safe before release** | Zero Flutter dependency (confirmed: zero `.rpc()` calls, column never read by any live query); old rows get an approximate default, see §7.1 caveat |
| 3 | `editable_fields` table + validation trigger (§4.3, §7.2) | `create table editable_fields (...)` + trigger, deployed **warn-only** first | **Safe before release** for the table + warn-only trigger; promotion to reject-mode is its own later step, treated as **Requires maintenance window** in spirit (needs an observation window against real traffic, not a timed rollout) | Do not enable rejection until a confirmed zero-unknown-key observation period |
| 4 | `added_holdings.reform_type` (§4.4) | — | **Already live** — no migration needed | Confirmed via column comment on the live schema |
| 5 | `city_top_holders` refresh automation (§4.5) | — | **Retired — moot** | Live-verified plain view, not materialized; no refresh step exists to automate |
| 6 | `persons` table (§4.6) | — | **Not building** | Superseded; `person_id` (already live) is the real, correct mechanism |
| 6b | `person_client_id` (§7.5, new finding) | — | **Not building; doc cleanup only** | Confirmed absent from live schema; delete/mark-abandoned the stale Flutter-repo migration file that introduced it |
| 7 | Completion state `completed_at`/`completed_by` (§4.7) | `alter table holdings/added_holdings add column completed_at timestamptz, add column completed_by uuid references profiles(id)` | **Safe before release**, but functionally inert until Flutter Phase 2 reads/writes it — tracked as **Safe after Flutter update** for when it becomes *meaningful*, even though the migration itself can ship immediately | Explicitly named as a current Flutter Phase 2 blocker in this doc's own prior status update |
| 8 | Soft delete `deleted_at`/`deleted_by` on `added_holdings` (§4.8) | `alter table added_holdings add column deleted_at timestamptz, add column deleted_by uuid references profiles(id)` | **Safe before release**; filter-usage is **Safe after Flutter update** | Existing queries keep returning these rows until Flutter Phase 2 adds `deleted_at is null` filters |
| 9 | Sync idempotency `operation_id`/`target_was_stale` (§4.9, §7 decision) | `alter table holding_edits add column operation_id uuid unique; add column target_was_stale boolean not null default false` | **Safe before release** | Repurposed as general retry-safety/staleness-detection infrastructure, independent of the abandoned offline outbox — see §7's alternatives-considered writeup for why this wasn't dropped |
| 10 | National ID format CHECK (§4.10, §7.6) | `check (national_id ~ '^\d{14}$' or national_id = '1111111111')` on `holdings`/`added_holdings`, added **`VALID`, not `NOT VALID`** | **Safe before release** | Live audit: only 1 non-conforming row per table, both the known placeholder — constraint is 100% compliant with current data once the placeholder is exempted, no need for the cautious `NOT VALID` path |
| 11 | `commit_import_batch` dedup guard (§7.4, new finding) | Add `on conflict (city_id, dedup_key) do nothing` to the existing insert, wire the already-present-but-hardcoded `rowsDuplicate` response field to the real count | **Requires maintenance window** | Confirmed live: the function currently has **zero** dedup guard — a behavior change to an existing, load-bearing function, not a new additive object; needs a deliberate test-import verification pass (duplicate/fresh/partial-overlap files) before shipping, and a small Dashboard follow-up to surface the now-real `rowsDuplicate` count |
| 12 | Legacy `id`/`client_id` backfill on `added_holdings` (§6) | `update added_holdings set id = client_id where id <> client_id` + repoint `holding_edits.holding_id` for affected rows | **Requires maintenance window**, explicit sign-off gated | Live-reconfirmed: exactly 353 rows. Deferred to Phase 4, not this phase — rewrites synced production rows and an append-only audit table's keys |
| 13 | `is_stale` column/index/filter cleanup | Drop the vestigial column, its index, and all `is_stale=false` filter clauses | **Optional cleanup** | Currently a functional no-op (nothing sets it `true` anymore); needs a full grep of every reader before removal, not urgent |

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
Item 11 touches the import *commit* function's dedup behavior, not the Excel column mapping/schema
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
- ✅ **Holder-status UI badge.** `ParcelDetailTopRow` now shows وراثة/مفوض badges from
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
     dataset untouched" keep passing unchanged — that invariant is real and correct for the *synchronous
     test double*, it's just no longer true for the production optimistic path, which is now covered by
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

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | Hide derived fields from manual entry | ⚠️ PARTIAL | `area_sqm` is already auto-calculated (`AreaCalculator.totalSqm`) whenever فدان/قيراط/سهم change, but is still rendered as its own tappable/editable `FieldRow` (`parcel_detail_card.dart`), duplicating the fraction field just above it and implying it's independently editable when it isn't. |
| 2/8 | Reorganize details screen, most-used info first | ⚠️ PARTIAL | A primary (`ResponsiveFieldsWrap`) vs. secondary (`SeeMoreSection`, collapsed) split already exists and is reasonable, but not formally reviewed for ordering, and not named `section_holder`/`section_extra` as the localization keys of the same name imply. |
| 3 | Copy ID = the only completion trigger, remove standalone Finish | ❌ MISSING | Copy ID already auto-completes (`_copyId` calls `setParcelCompleted(completed: true)`), but a fully independent Finish/Reopen button pair still exists (`ParcelDetailTopRow` → `DetailScreen._finishParcel`/`_reopenParcel`). Two independent paths write the same `completedAt` field today. |
| 4 | Emphasize primary action, de-emphasize secondary | ❌ MISSING | Delete/Reopen/Finish/Copy ID/Copy All/Add Parcel all use comparable tonal/outlined weight — no visual hierarchy. |
| 5 | Spacing/grouping/readability polish | ⚠️ PARTIAL | Rolled into #2/#8's reorganization pass rather than tracked separately. |
| 6 | Faster data entry, fewer taps | ⚠️ PARTIAL | Rolled into #1 (removing the redundant area_sqm tap target) and #3 (removing the now-redundant Finish tap once Copy ID covers it). |
| 7 | Floating Add Parcel action | ❌ MISSING | `DetailScreen` uses an inline `CustomTextButton.outlined` in the header (`detail_screen_header.dart`), not a FAB. `HomeScreen` already has a `FloatingActionButton.extended` precedent to follow (`home_screen.dart:392`). |
| 9 | Growth Stage field | ✅ DONE | Real end-to-end field already existed (`Parcel.growthStages`, both DB tables, `SeeMoreSection`/`AddRecordScreen` UI) but as unconstrained free text. User supplied the real business value list — converted to a real option enum (`Parcel.growthStageOptions`) matching the `usageTypeOptions`/`cropTypeOptions` pattern.

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
