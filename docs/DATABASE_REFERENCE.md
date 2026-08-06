# HiyazaFinder — Database Reference

**Status:** Frozen v2 — permanent reference for the schema: current state, evaluation, and the
additive target design. **Correction (confirmed against the live Supabase project, `Hiyaza` /
`bbahuyqjptojlighriyy`):** this repo's `supabase/migrations/` folder is *not* the canonical migration
history — it has ~19 files that don't correspond by name or version to what's actually applied (60
migrations live as of 2026-08-06, per `list_migrations`, most recent
`20260804222449_inherit_person_id_from_parent_holding`). The dashboard repo owns the real migration
history; treat this Flutter repo's `supabase/migrations/` folder as stale/for-reference-only until
reconciled, and consult the live schema or the dashboard repo for ground truth on anything
schema-related.
**v2 update (2026-08-06):** every open ambiguity from v1 has been resolved by direct live-database
query (`list_migrations`, `execute_sql` against `bbahuyqjptojlighriyy` — read-only, nothing executed
beyond `SELECT`s and catalog introspection). See §4 for the resolved decisions and §7 for live-verified
facts. No schema changes have been applied; this document remains design-only.
**Companions:** `SYSTEM_DESIGN.md` (how the schema is used), `REFACTOR_ROADMAP.md` (when each change
lands, now with Safe-before-release / Safe-after-Flutter-update / Requires-maintenance-window /
Optional-cleanup classification per migration).

---

## 1. Overview

Central authority for all HiyazaFinder data across the Flutter field app and the Next.js admin
dashboard. Postgres via Supabase; RLS enforces role-based access (`admin`/`editor`/`viewer`/`field`);
Realtime is enabled on the tables both apps need to stay live-synced.

**Design pattern (unchanged, foundational):** authoritative import (`holdings`) is immutable;
corrections are an append-only overlay (`holding_edits`); field-created records live in a separate
table (`added_holdings`) reviewed before full promotion. Nothing is ever overwritten — this is what
makes complete audit traceability achievable at all. Every addition below extends this pattern; none
of them replace it.

---

## 2. Current tables (as applied)

### 2.1 `profiles`
User identity and role. Auto-created via `on_auth_user_created` trigger on `auth.users` insert.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK, FK→`auth.users` | |
| `display_name`, `email` | text | |
| `role` | `user_role` enum (`admin`\|`editor`\|`viewer`\|`field`) | Gates every RLS policy via `current_role_is()` |
| `is_active` | boolean | `false` immediately blocks the user everywhere |
| `created_at` | timestamptz | |

### 2.2 `cities`
Scopes all other data — one row per جمعية/village. Unit of download, offline work, and staleness
tracking.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `name` | text, unique (case-insensitive) | |
| `directorate`, `administration` | text | |
| `status` | `city_status` enum (`draft`\|`published`\|`archived`) | Only `published` is downloadable by field users |
| `data_version` | bigint | Bumped by trigger on any data change; the app's staleness signal |
| `association_type` | → `association_types.code` (see §4.1, target design) | Gates credit/reform-specific fields |
| `created_by`, `created_at`, `updated_at` | | |

### 2.3 `holdings`
Authoritative, immutable Excel import. Never edited directly by the app — corrections go through
`holding_edits`.

Key columns: `city_id`, `import_batch_id`, `holding_id_number`, `unified_number` (unique per city where
not null — the stable dedup key), `holder_name`, `national_id`, `land_number`, `basin_name`,
`basin_code`, `association_name`, `administration`, `directorate`, four `border_*` fields, `feddan`,
`qirat`, `sahm`, `total_sqm`, `person_id`, `owner_name`, `crop_type`, `notes`, `credit_type`,
`reform_type`, `usage_type`, `is_inheritance`, `is_delegate`, `reviewed`/`reviewed_at`/`reviewed_by`,
`is_stale`, `imported_at`.

Indexes: `(city_id)`, `(city_id, holding_id_number)`, `(city_id, basin_name)`, GIN trigram on
`holder_name`, unique `(city_id, unified_number)` where not null, `(city_id, reviewed)`.

### 2.4 `holding_edits`
Append-only correction log — mirrors both apps' edit-overlay model exactly.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `holding_id` | uuid | Points at `holdings.id` or `added_holdings.id` — see §4.2 for the discriminator fix |
| `city_id` | uuid, FK→`cities` cascade | |
| `payload` | jsonb | `Parcel.toEditableJson()` shape — validated against `editable_fields`, see §4.3 |
| `edited_by` | uuid, FK→`profiles` | |
| `edited_at` | timestamptz | |
| `client_edited_at` | timestamptz | Device clock; drives last-write-wins |
| `device_id` | text | Present, not yet used by any feature |

RLS: readable by any authenticated user; insert-only where `edited_by = auth.uid()`; **no update/delete
policy exists — append-only by construction.**

View `holding_edits_latest`: `DISTINCT ON (holding_id)`, ordered by `coalesce(client_edited_at,
edited_at) DESC` — one row per holding, the correction both apps merge on read.

### 2.5 `added_holdings`
Field-created records awaiting review. Same shape as `holdings` plus provenance and review status.

Key columns mirror `holdings`, plus: `client_id` (unique — idempotency key for offline retries),
`parent_holding_id` (set for "add parcel to existing person"), `status`
(`pending`\|`approved`\|`rejected`), `rejection_reason`, `promoted_holding_id`, `created_by`,
`created_at`, `updated_at`, `reviewed`/`reviewed_at`/`reviewed_by`.

**Known, confirmed gap:** no `reform_type` column, unlike `holdings` — field records created in a
reform-type city silently lose that value. Closed in §4.4.

### 2.6 `import_batches`
Dashboard's Excel import audit trail — file name, row counts, rejection log, column mapping used,
`imported_by`, `committed_at`.

### 2.7 `city_top_holders` (plain view — corrected 2026-08-06)
Per-holder parcel count per city, used by the app to show "عدد القطع في الحيازة." **Live-verified via
`pg_get_viewdef`: this is a plain view, not a materialized view — the earlier "materialized view,
needs manual REFRESH" claim (Flutter repo migration `20260801000011_city_top_holders.sql`) was never
what's actually live and is now known-stale, not just suspected-stale.** Live definition:

```sql
SELECT city_id, holder_name, national_id, count(*) AS holdings_count,
       COALESCE(sum(feddan), 0::numeric) AS total_feddan, holding_id_number
FROM holdings
WHERE is_stale = false AND holder_name IS NOT NULL
GROUP BY city_id, holding_id_number, holder_name, national_id;
```

It includes `holding_id_number` and is stable as of this check — the historical churn (redefined at
least 6 times per live `list_migrations`: `drop_and_recreate_city_top_holders_view`,
`fix_city_top_holders_inner_join`, `city_top_holders_add_holding_id`, `fix_city_top_holders_view`,
`restore_city_top_holders_holding_id_number`, plus the dashboard repo's own edits) is resolved — no
further "automation" work is needed since it's a plain view with no refresh step to automate. §4.5
below is retired as moot, not deferred.

### 2.8 Enums
`user_role` (`admin`\|`editor`\|`viewer`\|`field`), `city_status`
(`draft`\|`published`\|`archived`), `record_status` (`pending`\|`approved`\|`rejected`). All three stay
enums — see §4.1 for why `association_type` doesn't.

### 2.9 Row-Level Security
Every table has RLS enabled. `current_role_is(roles user_role[])` (a `SECURITY DEFINER` function
checking `profiles.role` and `is_active`) backs every policy. `holding_edits` has no update/delete
policy anywhere — append-only is a database guarantee, not an app convention.

---

## 3. Evaluation

### 3.1 Verdict

**The schema is fundamentally sound and is not being redesigned.** The immutable-import +
append-only-overlay pattern is exactly right for durability and traceability, and it's already shared
correctly between both apps. What follows is a set of targeted, additive migrations closing specific,
confirmed gaps — no breaking changes to any existing table's meaning, and the Excel import/export
schema and behavior are explicitly untouched.

### 3.2 What's already correct (not changing)

- Indexing on `holdings` (city+holding_id, city+basin, trigram on holder_name, unique
  city+unified_number) matches actual query patterns.
- RLS coverage is complete and the `current_role_is()` pattern is clean and reusable for any new
  table.
- `data_version` as the freshness primitive — simple, correct, kept as-is.
- `city_status`, `user_role`, `record_status` stay enums. No stated or implied growth requirement for
  any of them; converting them to reference tables would be speculative complexity with no
  corresponding need.
- `feddan`/`qirat`/`sahm` vs. `total_sqm` consistency stays a **soft**, Dashboard-quality-board rule,
  not a hard constraint — partial in-progress field data is normal and a hard constraint would block
  legitimate incomplete records.

---

## 4. Target schema — additive changes (resolved 2026-08-06, see §7 for justification detail)

### 4.1 `association_type`: enum → reference table

**Why:** more association types beyond Credit and Reform are expected. An enum value requires a schema
migration (`ALTER TYPE ... ADD VALUE`) *and* an app redeploy to actually use it — friction the
registry principle (`SYSTEM_DESIGN.md` §3) exists to eliminate.

```sql
create table association_types (
  code       text primary key,   -- 'agricultural_credit', 'agricultural_reform', ...
  label_ar   text not null,
  label_en   text,
  sort_order int not null default 0
);
```

`cities.association_type` becomes `association_type_code text references association_types(code)`,
seeded with the two current values — existing rows need zero changes. A future third type is one
`insert`, reviewed by staff through the Dashboard, no migration or redeploy.

### 4.2 `holding_edits.holding_id` — discriminator column

**Why:** the column can point at `holdings.id` or `added_holdings.id`; a single real FK across two
tables isn't possible without a much larger redesign (a shared parent table) not justified by the
payoff. Today the ambiguity is implicit and both apps guess independently — already drifted once (see
§4.6).

```sql
alter table holding_edits add column holding_type text not null default 'holding'
  check (holding_type in ('holding', 'added_holding'));
```

Makes the ambiguity explicit and queryable; both apps' merge logic stops guessing.

### 4.3 `editable_fields` — single source of truth + payload validation

**Why:** the Dashboard and Flutter app each hand-maintain their own list of which fields are editable
(`EDIT_PAYLOAD_KEY_MAP` on the Dashboard side) — nothing fails loudly if one side adds a field and the
other forgets, and `holding_edits.payload` (jsonb) has no server-side validation of its keys, so a
typo'd key from either app silently fails to merge with no error anywhere.

```sql
create table editable_fields (
  field_name       text not null,
  applies_to_table text not null check (applies_to_table in ('holdings', 'added_holdings')),
  added_at         timestamptz not null default now(),
  primary key (field_name, applies_to_table)
);
```

Both apps generate/validate their editable-field lists from this table. A trigger on `holding_edits`
validates incoming `payload` keys against it for the target's table, rejecting unknown keys at write
time instead of silently dropping them.

### 4.4 `added_holdings.reform_type` — **done, confirmed live**

Confirmed via the live schema (`holdings`/`added_holdings` both carry `reform_type text`, nullable,
column comment: "Reform type — referenced by holding_edits payload and the export pipeline but never
backed by a column until now"). The gap described here is closed; no further action needed.

### 4.5 `city_top_holders` refresh automation — **retired, moot (resolved 2026-08-06)**

Live-verified via `pg_get_viewdef`: `city_top_holders` is a plain view, not a materialized view (see
§2.7). Plain views have no refresh step — this item described a problem that doesn't exist in the
live schema. No action needed. (The materialized-view claim traced back to a Flutter-repo-only
migration file, `20260801000011_city_top_holders.sql`, that was superseded by later dashboard-repo
work and never reflects the live object.)

### 4.6 `persons` table — **superseded, not built; `person_id` is the real mechanism**

This section originally proposed a dedicated `persons` table (design kept below for history). That was
never implemented. The live schema instead has `holdings.person_id` / `added_holdings.person_id` —
confirmed via `list_tables` as a plain `uuid`, not an FK — described by its own column comment as a
"Generated grouping id for a person's parcels — one shared id per real national_id, an independent id
per placeholder/NULL national_id row," assigned automatically on `added_holdings` insert by a trigger
(`assign_person_id()`). `holdings_person_idx`/`added_holdings_person_idx`-style indexes on `person_id`
do exist live (confirmed via applied migrations `20260804222202_index_person_id` and others in that
same date range). Treat `person_id` as the real, intentional mechanism — not a gap to close — and
consult the live schema/dashboard-repo migrations (§6) rather than this section's original design if
you need the exact assignment/uniqueness semantics, since this doc was not kept in sync with that
trigger's actual behavior.

**Resolved 2026-08-06 — `person_client_id` does not exist live; there is no duplicate mechanism.**
A prior audit pass flagged `person_client_id` (from the Flutter-repo-only migration
`20260805000020_person_client_id.sql`) as a possible second, competing grouping mechanism. Direct
`information_schema.columns` query against the live database shows **only `person_id` exists** on
`holdings`/`added_holdings` — `person_client_id` was never applied to production. That migration file
is stale/unapplied, exactly like the `city_top_holders` materialized-view file above. **Decision: do
not build `person_client_id`.** `person_id` is the sole, correct grouping mechanism; the Flutter-repo
migration file should be deleted or clearly marked unapplied/abandoned the next time that repo's
migrations folder is touched, so it stops implying a second mechanism exists.

<!-- Original design, not implemented — kept for history:

**Why:** `person_id` today is a bare, unconstrained uuid copied client-side with no backing table and
no consistency enforcement — two rows with the same `person_id` could disagree on `holding_id_number`
and nothing would catch it. The business vision makes "person" the primary navigation and creation
unit (open a person → see all their parcels; a person is always created atomically with their first
parcel; no duplicate people, ever) — a floating grouping key enforced only by client goodwill can't
make that guarantee.

```sql
create table persons (
  id            uuid primary key default gen_random_uuid(),
  city_id       uuid not null references cities(id) on delete cascade,
  display_name  text not null,
  national_id   text,
  external_refs jsonb not null default '{}',   -- home for future integrations (e.g. farmer-card system)
  created_by    uuid references profiles(id),
  created_at    timestamptz not null default now()
);
create index persons_city_idx on persons (city_id);
create index persons_holder_trgm on persons using gin (display_name gin_trgm_ops);
create unique index persons_city_national_id_unique
  on persons (city_id, national_id) where national_id is not null;
```

`holdings.person_id` and `added_holdings.person_id` become nullable FKs to `persons.id`. Rollout is
additive and non-destructive: create the table, add the FK as nullable, backfill one `persons` row per
distinct existing non-null `person_id`; rows with `person_id is null` keep working under today's
ambiguous grouping until touched, at which point the app can prompt to link/create a person. No
existing row is rewritten or deleted.

The partial unique index on `(city_id, national_id)` structurally prevents exact duplicate people
where a national ID is known. Where it isn't (a brand-new person, captured offline on two devices that
don't know about each other), structural prevention isn't possible — see `SYSTEM_DESIGN.md` §11 for
the fuzzy-match detection fallback.

Add matching indexes for the new primary navigation query ("show all parcels for this person"):
```sql
create index holdings_person_idx       on holdings (person_id);
create index added_holdings_person_idx on added_holdings (person_id);
```

-->

### 4.7 Completion state (field-worker workflow — distinct from `reviewed`)

```sql
alter table holdings       add column completed_at timestamptz, add column completed_by uuid references profiles(id);
alter table added_holdings add column completed_at timestamptz, add column completed_by uuid references profiles(id);
```

`reviewed`/`reviewed_at`/`reviewed_by` are **not** repurposed and **not** deprecated — they become the
staff/Dashboard data-quality-review signal, a distinct workflow from field-worker completion. See
`SYSTEM_DESIGN.md` §10 for the full reasoning.

### 4.8 Soft delete for `added_holdings`

```sql
alter table added_holdings add column deleted_at timestamptz, add column deleted_by uuid references profiles(id);
```

A field worker deleting an added parcel removes it from every app/Dashboard view immediately
(`deleted_at is null` filter on every query) while the row and its full `holding_edits` history remain
in the database — satisfying both "delete it, I don't want to see it anymore" and "nothing is
temporary, everything is durable," which otherwise directly conflict. Confirmed as the chosen direction
over a true hard delete.

### 4.9 Sync idempotency — **resolved: keep, but repurposed as general-purpose, not outbox-specific**

```sql
alter table holding_edits add column operation_id uuid unique;
alter table holding_edits add column target_was_stale boolean not null default false;
```

**Decision (2026-08-06): keep both columns, deploy them.** This item was originally scoped for the
offline sync outbox (`SyncOperation`/`SyncOperationHandler`), which `SYSTEM_DESIGN.md` §5 confirms was
abandoned in favor of an online-first model — so the literal justification text above ("carries the
client-generated `SyncOperation` id") is stale. But the columns' value does not depend on the outbox
existing:

- `operation_id` is a generically useful idempotency key for *any* future retry path (even an
  online-first `await` can be retried by the caller after a timeout with an ambiguous outcome — network
  drops after the server commits but before the client sees the response is a real failure mode
  independent of whether there's a durable local queue). Nullable + unique costs nothing if unused.
- `target_was_stale` answers a question ("did this edit land on data that was already stale at write
  time") that is meaningful regardless of sync architecture — it's about server-side state at the moment
  of insert, not about any client queue.

Alternative considered: drop this item entirely since its original justification is gone. Rejected
because the columns are zero-cost when unpopulated (nullable, default-only) and the underlying problem
(retry-safety, stale-write detection) is real and architecture-independent — removing them now would
just mean re-adding them later under a different name once a retry path is actually built. Ship as
inert, additive infrastructure; the app is not required to populate them yet.

### 4.10 National ID format — **resolved: `NOT VALID` is safe now; live data confirms it**

Live audit query (`bbahuyqjptojlighriyy`, 2026-08-06) against all 15,238 `holdings` and 764
`added_holdings` rows with a non-null `national_id`: exactly **one row per table** fails a 14-digit
check, and both are the same value, `'1111111111'` — the known placeholder sentinel both apps already
use intentionally for "no real national ID," not dirty data. This means:

- The 14-digit `CHECK` must **allow the placeholder explicitly**, or every future placeholder-ID row
  (a common, intentional case, not an edge case) would be rejected. Constraint shape:
  `national_id ~ '^\d{14}$' or national_id = '1111111111'`.
- With the placeholder allowed, the live data is **already 100% compliant** — the constraint can be
  added `VALID` (fully enforced immediately), not just `NOT VALID`, with zero risk to existing rows.
  `NOT VALID` is unnecessary caution once the placeholder is exempted; validate it fully from day one.

---

## 5. What explicitly does not change

Excel import/export schema and behavior; the `holdings`/`holding_edits`/`added_holdings` core shape and
the immutable+overlay pattern; RLS structure and `current_role_is()`; `city_status`/`user_role`/
`record_status` enums; no hard constraint on area-math consistency.

---

## 6. Deferred, not forgotten (requires separate sign-off — touches live production data)

**Legacy `id`/`client_id` split.** **Live-reconfirmed 2026-08-06: exactly 353 rows**
(`select count(*) from added_holdings where id <> client_id` = 353, matching the doc's prior estimate
exactly). These rows predate the migration that made the app supply `id` directly; their `id` still
diverges from `client_id`, and their `holding_edits` rows are keyed to `client_id`, not `id` — confirmed
live in production, not hypothetical (see `DASHBOARD_ID_ALIGNMENT.md`). Recommended resolution:
`update added_holdings set id = client_id where id <> client_id`, plus repointing the corresponding
`holding_edits.holding_id`. Not included in the automatic migration set because it rewrites
already-synced production rows and an append-only audit table — needs explicit go-ahead before it runs,
tracked in `REFACTOR_ROADMAP.md` Phase 4, classified **Requires maintenance window** (not safe as a
background/online operation given it touches an append-only audit table's keys — run inside one
transaction with a captured before/after snapshot for rollback).

**Three Flutter-side export data gaps** (`owner_national_id`, `holder_name_farmer_card`/
`owner_name_farmer_card`, `growth_stages`) — schema mostly exists already; the gap is the Flutter app
never sending these payload keys. Cross-repo dependency, sequenced with the Flutter rebuild (see
`FLUTTER_EXPORT_GAPS.md` for full detail).

---

## 7. Remaining architecture decisions, resolved 2026-08-06

Every item below was previously flagged as an open ambiguity. Each has now been decided from live data
or documented design principles — none required business input that couldn't be inferred from
`PROJECT_OBJECTIVES.md`/`SYSTEM_DESIGN.md`'s existing stated goals (audit traceability, additive-only
production safety, registry-not-branch extensibility).

### 7.1 `holding_type` discriminator on `holding_edits` — decision: build it

**Alternatives considered:**
1. **Do nothing** — keep guessing which table `holding_id` points at from context (both apps currently
   do this independently). Rejected: this is the confirmed root cause of the legacy 353-row ambiguity
   (§6) and will recur for any future third table that needs an edit overlay.
2. **A real polymorphic FK via a shared parent table** (`holdable_records` that both `holdings` and
   `added_holdings` reference) — the "correct" normalized-relational answer. Rejected: this is a
   genuine breaking redesign of two core tables' identity, explicitly out of scope per §5 ("core shape
   does not change") and disproportionate to the problem — a discriminator column solves the actual
   pain (ambiguous joins) without touching either table's structure.
3. **A `holding_type` text column with a CHECK, default `'holding'`** — additive, one column, no
   existing row's meaning changes. **Chosen.**

**Justification:** matches the existing extensibility principle (`SYSTEM_DESIGN.md` §3 — "registries,
not branches" — a discriminator is the minimal structural answer, not a redesign) and closes a
confirmed, already-observed integrity gap at the lowest possible cost. Classified **Safe before
release** (see §migration-strategy below) — no Flutter dependency, confirmed via the zero-`.rpc()`
grep and the fact this column is never read by any live query today.

**Caveat carried forward:** old rows get the default `'holding'`, which is only an approximation for
whichever old rows actually point at `added_holdings`. This is why the legacy id/client_id backfill
(§6) is listed as a prerequisite for *fully* trusting this column on historical data — new rows are
unambiguous from day one regardless.

### 7.2 `editable_fields` + payload validation — decision: build it, deploy warn-only first

**Alternatives considered:**
1. **Do nothing** — keep two independently hand-maintained key lists (Dashboard's
   `EDIT_PAYLOAD_KEY_MAP`, Flutter's `Parcel.toEditableJson()`). Rejected: this is the confirmed root
   cause of the camelCase bug that already shipped to production once (`20260804210000`); "already
   happened once" is a stronger signal than typical speculative risk.
2. **A rejecting trigger from day one.** Rejected as the *first* step — confirmed live risk: if the
   seed list misses even one key either app currently sends, that app's writes start failing outright,
   which is a worse outcome than the bug it's meant to prevent, for a production app that can't be
   force-upgraded.
3. **A warn-only trigger first (logs unknown keys, e.g. to `admin_actions` or Postgres logs, without
   rejecting), promoted to reject-mode only after a confirmed observation window with zero unknown-key
   events.** **Chosen.**

**Justification:** delivers the shared-source-of-truth value (one table both apps' tooling can generate
their key lists from) immediately, while sequencing the actually-risky part (rejection) behind an
observation period — consistent with the user's stated preference for reversible, low-blast-radius
steps. Classified **Safe before release** for the table + warn-only trigger; the switch to reject-mode
is a separate, later step classified **Requires maintenance window** in spirit (not because it needs
downtime, but because it needs a deliberate go/no-go check against real traffic first, not a blind
timed rollout).

### 7.3 `city_top_holders` — decision: no schema change needed

Resolved by live query, not design judgment (§2.7, §4.5): it is already a plain, stable view with
`holding_id_number` present. The only recommended action is **process**, not schema: stop editing this
view speculatively (it was touched 6+ times historically for what were, in the end, largely
back-and-forth fixes) — any future change should be preceded by exactly the kind of direct
`pg_get_viewdef` check performed here, not another docs-only edit.

### 7.4 `commit_import_batch` — decision: add a dedup guard, classified as its own migration

Live-verified (`pg_get_functiondef`): the current function has **no duplicate-import guard at all** —
every record in `p_records` is inserted unconditionally inside a per-row exception-handling loop, with
no `ON CONFLICT` and no pre-check against `dedup_key`/`unified_number`. This is a confirmed gap, not a
suspicion.

**Alternatives considered:**
1. **Leave as-is.** Rejected: duplicate imports of the same source file (a realistic operator mistake —
   re-running an import after an ambiguous "did it work?" UI moment) currently produce silent duplicate
   `holdings` rows with no error and no warning, directly undermining the "authoritative import" claim
   in §2.3.
2. **`ON CONFLICT (city_id, dedup_key) DO NOTHING`, counted as a new `rowsDuplicate` summary bucket**
   (the response shape already has this field, currently hardcoded to `0` — visible in the live
   function body). **Chosen** — `dedup_key` already exists as a generated column precisely for this
   purpose (§2.3), and the RPC's own return shape was already designed for this counter, just never
   wired up.
3. **A stricter unique constraint instead of RPC-level `ON CONFLICT`.** Rejected for this pass: a hard
   unique constraint changes error semantics for any other write path and is a bigger surface than the
   problem requires; `ON CONFLICT DO NOTHING` inside the already-existing per-row exception handler is
   the minimal fix matching the function's existing structure.

**Justification:** this is a **behavior fix inside an existing function**, not a new table/column — it
is additive in effect (adds a `DO NOTHING` guard, wires an already-present output field) but touches
live logic every import run depends on, so it is classified **Requires maintenance window** — not
because Postgres requires downtime for a `CREATE OR REPLACE FUNCTION`, but because the user's own rule
("no absolute guarantee old Flutter/Dashboard continues working ⇒ defer") applies in spirit: this needs
a deliberate test import run (duplicate + fresh + partial-overlap file) against a staging-equivalent
check before going live, not a same-day-as-everything-else additive rollout. Flutter has zero
dependency on this RPC (confirmed, §1.6); Dashboard's import UI is the only consumer and would need its
"rows duplicate" summary display wired to the now-real `rowsDuplicate` field — a small, low-risk
Dashboard follow-up, not a blocker to shipping the guard itself.

### 7.5 `person_client_id` — decision: do not build; retire the stale migration reference

Resolved by live query (§4.6): the column does not exist in production. There is nothing to reconcile
because there is no second mechanism — only `person_id`. No schema action needed. Documentation action:
the Flutter repo's `20260805000020_person_client_id.sql` should be deleted or explicitly marked
"never applied, superseded" the next time that repo's migrations folder is touched, so it stops
implying a live column that isn't there.

### 7.6 National ID placeholder handling — decision: exempt `'1111111111'` explicitly in the CHECK

Resolved by live audit (§4.10): the single non-conforming value per table is the known placeholder, not
dirty data. Decision already stated in §4.10; recorded here for completeness of the "every ambiguity
resolved" tracking. No further alternatives were meaningfully in play — the placeholder is a documented,
intentional convention on both sides, not a design choice this session is making unilaterally.

---

## 8. Live-verified facts snapshot (2026-08-06, read-only — nothing executed beyond `SELECT`/catalog introspection)

For traceability: this is the exact evidence base §7's decisions rest on, captured once so future
sessions don't need to re-run these checks to trust the decisions above.

- **Live migrations:** 60 applied, most recent `20260804222449_inherit_person_id_from_parent_holding`
  (`list_migrations` against `bbahuyqjptojlighriyy`).
- **`city_top_holders`:** plain view (`relkind = 'v'`), definition captured in full in §2.7.
- **`commit_import_batch`:** full body captured via `pg_get_functiondef`; confirmed no `ON CONFLICT`,
  no pre-insert dedup check, `rowsDuplicate` hardcoded to `0` in the return payload.
- **Row counts:** `holdings` 15,239; `holding_edits` 26,214; `added_holdings` 765; `cities` 11;
  `profiles` 8; `import_batches` 26; `quality_snapshots` 0; `admin_actions` 3.
- **National ID format:** 1 non-conforming row in `holdings`, 1 in `added_holdings`, both value
  `'1111111111'` — out of 15,238/764 non-null values respectively.
- **Legacy id/client_id split:** exactly 353 rows where `added_holdings.id <> added_holdings.client_id`
  — matches the previously-documented estimate exactly.
- **`person_client_id`:** confirmed absent from `information_schema.columns` on both `holdings` and
  `added_holdings` — only `person_id` (nullable `uuid`) exists on either table.
- **`holding_edits` columns (live):** `id`, `holding_id`, `city_id`, `payload`, `edited_by`,
  `edited_at`, `client_edited_at`, `device_id`, `client_op_id` — matches this doc's §2.4 description
  exactly, no drift found.
- **Tables present (public schema):** `profiles`, `cities`, `import_batches`, `holdings`,
  `holding_edits`, `added_holdings`, `quality_snapshots`, `admin_actions` — matches §2 exactly, no
  extra or missing tables found live vs. documented.
