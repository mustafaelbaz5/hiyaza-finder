# HiyazaFinder — Refactor Roadmap

**Status:** Frozen v1 — the implementation roadmap. Sequenced to protect production at every step: the
import/export pipeline and Excel schema are never touched, and each phase is independently shippable
and revertable. See `SYSTEM_DESIGN.md` for the architecture being built toward, `DATABASE_REFERENCE.md`
for full schema detail, and `PROJECT_OBJECTIVES.md` for the business goals every phase serves.

---

## Phase 1 — Database: additive schema evolution

**Objective:** close every confirmed structural gap without breaking anything currently live.

**Scope:**
```sql
-- association types (DATABASE_REFERENCE.md §4.1)
create table association_types (...); -- seed with current 2 values
alter table cities add column association_type_code text references association_types(code);

-- holding_edits discriminator (§4.2)
alter table holding_edits add column holding_type text not null default 'holding'
  check (holding_type in ('holding', 'added_holding'));

-- shared field-name source of truth + payload validation (§4.3)
create table editable_fields (...);
-- + validation trigger on holding_edits

-- reform_type gap (§4.4)
alter table added_holdings add column reform_type text;

-- city_top_holders refresh automation (§4.5)

-- persons table (§4.6)
create table persons (...);
alter table holdings add column person_id_fk uuid references persons(id); -- or repoint existing person_id
alter table added_holdings add column person_id_fk uuid references persons(id);
create index holdings_person_idx on holdings (person_id);
create index added_holdings_person_idx on added_holdings (person_id);

-- completion state (§4.7)
alter table holdings add column completed_at timestamptz, add column completed_by uuid references profiles(id);
alter table added_holdings add column completed_at timestamptz, add column completed_by uuid references profiles(id);

-- soft delete (§4.8)
alter table added_holdings add column deleted_at timestamptz, add column deleted_by uuid references profiles(id);

-- sync idempotency (§4.9)
alter table holding_edits add column operation_id uuid unique;
alter table holding_edits add column target_was_stale boolean not null default false;

-- national ID format (§4.10)
-- CHECK constraint, 14-digit format, where national_id is not null
```

**Dependencies:** none — can start immediately.

**Complexity:** low. Every item is additive: new tables, new nullable columns, new indexes. No existing
row is rewritten, no existing constraint tightened, no existing column's meaning changes.

**Risks:** low. The one item with real risk — the legacy `id`/`client_id` backfill — is deliberately
excluded from this phase (see Phase 4).

**Notes:** Excel import/export schema and behavior are out of scope for this phase, and for every phase.

---

## Phase 2 — Flutter: architecture rebuild, sync outbox, and sync/realtime decoupling

**Objective:** bring the app's real code in line with the target architecture, and — the
highest-priority item — build a working, durable offline sync outbox (previously fully designed,
never implemented), plus the new review/completion and add-person/add-parcel workflows.

**Scope:**
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

**Dependencies:** Phase 1's `persons`, `completed_at`/`completed_by`, `deleted_at`/`deleted_by`,
`operation_id`, `target_was_stale` columns.

**Complexity:** highest in this roadmap — this is the daily-use production tool.

**Risks:** regression risk in a tool people depend on every day. Mitigate with a strict
"each phase leaves the app working" discipline (no big-bang rewrite) and a parallel-run period before
full cutover. A meaningful set of presentational widgets are expected to survive this rebuild largely
untouched (they render a `Parcel`; they don't know how it got there).

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
- Per-city user scoping, if still needed by this point.
- Begin `holding_edits` retention/archival planning if table size has become a measured concern.

**Dependencies:** Phases 1–3 complete.

**Complexity:** low — mostly follow-through on already-scoped items.

**Risks:** low; the one higher-stakes item (the legacy-id backfill) is explicitly gated on sign-off,
not defaulted.

---

## Sequencing summary

Phases 1 and 3 can start immediately and run in parallel. Phase 2 — the highest-risk, highest-value
phase — should start once Phase 1's schema lands, so the Flutter rebuild targets the final schema
rather than migrating twice. Phase 4 follows once 1–3 are stable.

## Gate discipline (carried forward from the app's own prior planning convention, applied platform-wide)

Every phase ends at a gate, not "it looks done": for Flutter, `flutter analyze` clean and `flutter test`
green plus a manual walkthrough of the phase's stated flow; for the Dashboard, typecheck + lint + unit
tests + the relevant E2E spec green; for the database, RLS and constraints verified by hand for every
role × table × operation touched. Do not start the next phase until the current one's gate is green.
