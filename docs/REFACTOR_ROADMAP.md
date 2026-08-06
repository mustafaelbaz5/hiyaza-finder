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

**Blocked on Phase 1 DB work (`completed_at`/`completed_by`, not yet applied live):**

- **Details-screen tabs** (Original/Added/Modified/Reviewed/Pending). `detail_screen.dart` has zero tab
  infrastructure today. Needs richer per-parcel status than the current single `reviewed` boolean
  provides — cannot be meaningfully built until `completed_at` lands.

**Explicitly open decisions — flagged, NOT yet approved for implementation:**

Each of these was raised during the planning audit as a "new-sounding" requirement that, if built,
would reverse a decision this project already made and documented. They are recorded here so the
tension stays visible; none should be implemented without the user separately approving the reversal.

- **Search: cache-first + live DB + merge.** Would reverse the fully local-first search model
  `SYSTEM_DESIGN.md` §13 is built around (in-memory city snapshot, zero remote calls, the basis of its
  whole scalability argument). Confirmed today: search is 100% local.
- **"No manual refresh."** Would mean removing the manual pull-to-refresh/refresh-icon actions in
  `home_screen.dart`/`detail_screen.dart`, which directly use `HoldingsRepository.syncNow()` — a pattern
  Phase 2's own realtime-polish work just relied on. Conflicts with the current, intentional design.
- **Background operations (continue after leaving screen, retry, queue).** This is the offline sync
  outbox model that `SYSTEM_DESIGN.md` §5 already documents as deliberately abandoned this project in
  favor of online-first (every write awaits its Supabase call synchronously; confirmed zero
  fire-and-forget writes exist today). Re-introducing it reverses that decision.
- **In-app activity center per city.** Larger in scope than `PROJECT_OBJECTIVES.md` §4's explicit
  "lightweight... not a Dashboard replacement" boundary for in-app stats.

**Dependencies:** the "buildable now" items have none. Details-screen tabs depend on Phase 1's
`completed_at`/`completed_by`. The four open-decision items depend on explicit user sign-off before
they're even scheduled.

**Complexity:** low–medium for the buildable items (mostly wiring existing, already-tested lower
layers into new UI); details-screen tabs are medium once unblocked; the open-decision items are
each a real scope/architecture decision, not an estimate.

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
