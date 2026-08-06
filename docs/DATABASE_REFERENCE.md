# HiyazaFinder — Database Reference

**Status:** Frozen v1 — permanent reference for the schema: current state, evaluation, and the
additive target design. **Correction (confirmed against the live Supabase project, `Hiyaza` /
`bbahuyqjptojlighriyy`):** this repo's `supabase/migrations/` folder is *not* the canonical migration
history — it has ~19 files that don't correspond by name or version to what's actually applied (63
migrations live, per `list_migrations`). The dashboard repo owns the real migration history; treat
this Flutter repo's `supabase/migrations/` folder as stale/for-reference-only until reconciled, and
consult the live schema or the dashboard repo for ground truth on anything schema-related.
**Companions:** `SYSTEM_DESIGN.md` (how the schema is used), `REFACTOR_ROADMAP.md` (when each change
lands).

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

### 2.7 `city_top_holders` (materialized view)
Per-holding parcel count per city, used by the app to show "عدد القطع في الحيازة." Requires manual
`REFRESH MATERIALIZED VIEW` today — automation target in §4.5.

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

## 4. Target schema — additive changes

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

### 4.5 `city_top_holders` refresh automation

Move from "Dashboard must remember to call `REFRESH MATERIALIZED VIEW`" to a trigger- or
scheduled-job-driven refresh after import completion. Mechanism to be chosen during implementation
(trigger on `import_batches` commit vs. a scheduled job); either closes the gap.

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

### 4.9 Sync idempotency

```sql
alter table holding_edits add column operation_id uuid unique;
alter table holding_edits add column target_was_stale boolean not null default false;
```

`operation_id` carries the client-generated `SyncOperation` id through to the database; a retried
flush after a lost server acknowledgment is `on conflict do nothing` instead of a duplicate row —
important now that every row is a user-visible audit-trail entry, not just a merge input.
`target_was_stale` is set by a trigger checking the target holding's `is_stale` at insert time, so an
edit that lands on a holding superseded by reimport while the device was offline is flagged for review
instead of silently orphaned (invisible in future downloads, since only non-stale holdings are
downloaded).

### 4.10 National ID format

Recommend a `CHECK` constraint (14-digit Egyptian national ID format) on `national_id` where present,
matching the client-side validation both apps already perform for UX — currently unenforced at the
database layer. Server-side is the authority; client-side is the fast-feedback layer (`SYSTEM_DESIGN.md`
§8).

---

## 5. What explicitly does not change

Excel import/export schema and behavior; the `holdings`/`holding_edits`/`added_holdings` core shape and
the immutable+overlay pattern; RLS structure and `current_role_is()`; `city_status`/`user_role`/
`record_status` enums; no hard constraint on area-math consistency.

---

## 6. Deferred, not forgotten (requires separate sign-off — touches live production data)

**Legacy `id`/`client_id` split.** 353 `added_holdings` rows predate the migration that made the app
supply `id` directly; their `id` still diverges from `client_id`, and their `holding_edits` rows are
keyed to `client_id`, not `id` — confirmed live in production, not hypothetical (see
`DASHBOARD_ID_ALIGNMENT.md`). Recommended resolution: `update added_holdings set id = client_id where
id <> client_id`, plus repointing the corresponding `holding_edits.holding_id`. Not included in the
automatic migration set because it rewrites already-synced production rows and an append-only audit
table — needs explicit go-ahead before it runs, tracked in `REFACTOR_ROADMAP.md` Phase 4.

**Three Flutter-side export data gaps** (`owner_national_id`, `holder_name_farmer_card`/
`owner_name_farmer_card`, `growth_stages`) — schema mostly exists already; the gap is the Flutter app
never sending these payload keys. Cross-repo dependency, sequenced with the Flutter rebuild (see
`FLUTTER_EXPORT_GAPS.md` for full detail).
