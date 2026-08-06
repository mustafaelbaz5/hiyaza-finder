# HiyazaFinder — Project Objectives

**Status:** Frozen v1 — the primary business reference for the project. Living document: update it
when business goals change, and keep `SYSTEM_DESIGN.md`/`DATABASE_REFERENCE.md`/`REFACTOR_ROADMAP.md`
in sync with it rather than letting implementation drift away from stated intent.

---

## 1. Vision

HiyazaFinder is a data-collection-first platform for managing Egyptian agricultural land-holding
records at the association (جمعية) level. The database is the single source of truth; every action
taken anywhere in the system — an import, a field edit, a new parcel, a review completion — is
durable, auditable, and eventually visible in both the Dashboard and Excel export. **Nothing in the
system is temporary.**

## 2. User types

| Role | Surface | Purpose |
|---|---|---|
| `admin` | Dashboard | Full control: import, correct, review, manage users/cities, destructive actions |
| `editor` | Dashboard | Import, correct, review — no user management |
| `viewer` | Dashboard | Read-only, including analytics |
| `field` | Flutter app only | Collects data: search, edit, add, review-complete. Cannot access the Dashboard at all |

## 3. Main workflow (end to end)

Excel import (Dashboard, per city, tagged with an association type — Credit and Reform today, more
expected later) → data available in the Flutter app → field workers search, review, edit, add, and
complete records → all actions sync to the database → Dashboard staff see everything (review queue,
audit trail, analytics) → data exported back to Excel for external use.

## 4. Functional requirements

- **Search** by holder name, holding number, or parcel ID; results always reflect the latest data, not
  only what was cached at download time.
- **Person → parcels hierarchy**: opening a person shows all their parcels; a person always has at
  least one parcel, created atomically together — no duplicate people, no orphaned parcels.
- **Progressive disclosure** on parcel detail: identifying information first, full detail on demand.
- **Copy Parcel ID marks the parcel completed** — visually distinct, moves to a completed section,
  visible to other users, manually reopenable. See `SYSTEM_DESIGN.md` §10 for the completion state
  design.
- **Any field is editable**; edited values are visually distinguishable from original imported data.
- **Add a parcel for an existing person** (inherits shared identity fields; only parcel-specific fields
  entered fresh) and **add a brand-new person** (creates person + first parcel together) — both behave
  identically to imported data once saved.
- **Added parcels are visually distinguishable** from imported ones, show who/when added, and can be
  deleted where allowed — deletion is soft (removed from every view immediately; retained in the
  database for audit — see §6 below and `SYSTEM_DESIGN.md` §11).
- **Lightweight in-app statistics** per city (original / modified / added / reviewed counts) — not a
  Dashboard replacement.
- **Dashboard: complete system visibility** — home overview, per-city control center, a dedicated
  holding-details page, complete audit history, per-user activity analytics — without ever needing to
  inspect raw tables.
- **Import/export Excel workflow and schema are stable and production-critical** — must not change
  behavior.

## 5. Non-functional requirements

- **Speed**: the field app is optimized for hundreds of records per day — minimal taps, minimal
  scrolling, minimal navigation.
- **Resilience**: field work must never be lost to poor connectivity; background sync is continuous and
  its state is always visible to the user (loading / saving / retrying / synced / failed).
- **Consistency**: every device eventually converges on the same data, via Realtime or next sync.
- **Maintainability**: feature-based clean architecture, SOLID, isolated business logic, small focused
  files/classes, on both the Flutter and Dashboard codebases.
- **Extensibility**: new fields, screens, workflows, entity types, and association types are addable
  with minimal changes — registries/data-driven configuration over branching code
  (`SYSTEM_DESIGN.md` §3).
- **Localization**: Arabic-first, RTL, throughout both apps.

## 6. Business rules

| Rule | Detail |
|---|---|
| Association-type field gating | `cities.association_type` (Credit/Reform today, extensible — `DATABASE_REFERENCE.md` §4.1) gates which fields (`credit_type` vs. `reform_type`) are relevant per city |
| Imported data is immutable | `holdings` never changes after import; all corrections are append-only `holding_edits` overlays, from either app, merged at read time |
| Field-added records are reviewed before full promotion | Doesn't block the field worker from continuing to use the record locally while review is pending |
| Excel schema and behavior are frozen | Unless explicitly renegotiated — the import/export pipeline is the one part of the system this project does not redesign |
| Deleting an added parcel is a soft delete | Removed from every app/Dashboard view immediately; the row and its edit history are retained in the database. Chosen specifically to resolve the conflict between "delete it immediately" and "nothing is temporary" (see `SYSTEM_DESIGN.md` §11) |
| Completion and review are separate, non-conflicting states | `completed_at`/`completed_by` = field worker done collecting; `reviewed`/`reviewed_at`/`reviewed_by` = staff has checked data quality. Different roles, different meanings, both real (`SYSTEM_DESIGN.md` §10) |
| Duplicate-person prevention | Structural where `national_id` is known (unique per city); flagged-for-review where it isn't, since two offline devices genuinely cannot know about each other's in-flight creation (`SYSTEM_DESIGN.md` §11) |

### 6.1 Shared validation rules

Rules implemented on both the client (fast feedback, works offline) and the server (actual authority)
have one documented source here, specifically to prevent the two codebases' understanding of a rule
from drifting apart silently (`SYSTEM_DESIGN.md` §8):

| Rule | Applies to | Client-side | Server-side |
|---|---|---|---|
| National ID: 14 digits | `national_id`, future `owner_national_id` | Format check on input | `CHECK` constraint (`DATABASE_REFERENCE.md` §4.10) |
| Person atomicity | Person + first-parcel creation | Single form/flow, can't submit half | `persons` FK (`DATABASE_REFERENCE.md` §4.6) makes an orphaned parcel-without-person structurally impossible |
| Association-type field gating | `credit_type` vs. `reform_type` visibility | Form shows only relevant fields | `association_types` table is the source of truth for which types exist; field-gating logic itself is correctly a presentation concern, not a DB rule |
| Holding-number immutability post-import | `holding_id_number` | Field rendered read-only | No write path exists outside Dashboard-assigned promotion |
| Editable-field set | `holding_edits.payload` keys | Form only exposes known-editable fields | `editable_fields` table + write-time trigger validation (`DATABASE_REFERENCE.md` §4.3) |

## 7. Current limitations (at the time this document was written)

`reform_type` missing from `added_holdings`; soft FK ambiguity in `holding_edits.holding_id`;
legacy `id`/`client_id` split affecting 353 historical records; no Flutter-side offline sync queue
despite one having been previously designed and never built; `HoldingsRepository` (646 lines) and
`ParcelDetailCard` (~500 lines) as god-classes; no dedicated Holding Details page on the Dashboard;
three Flutter-side export data gaps (owner national ID, farmer-card names, growth stage);
`city_top_holders` requiring manual refresh. All tracked with resolutions in `DATABASE_REFERENCE.md`
and `REFACTOR_ROADMAP.md` — this list exists so nobody has to rediscover them from scratch.

## 8. Future roadmap (explicitly postponed, not forgotten)

Additional association types beyond Credit and Reform; per-city user scoping (roles are currently
global); automated quality snapshots; closing the three export data gaps once Flutter captures the
fields; the legacy id/`client_id` production backfill (needs separate sign-off); conflict-detection UI
beyond last-write-wins (currently acceptable given single-team-per-city usage);
`holding_edits` retention/archival strategy once table size becomes a measured concern; possible
external "farmer card" system integration (`persons.external_refs` reserves the schema space for this
already).
