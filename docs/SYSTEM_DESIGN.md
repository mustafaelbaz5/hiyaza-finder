# HiyazaFinder — System Design

**Status:** Frozen v1 — permanent architectural reference for the entire platform.
**Companions:** `PROJECT_OBJECTIVES.md` (business vision this design serves), `DATABASE_REFERENCE.md`
(schema detail), `REFACTOR_ROADMAP.md` (how we get from today's implementation to this design).

Every future feature, refactor, or architectural decision should be evaluated against this document
rather than reconstructed from conversation history. If a decision here needs to change, change this
document — don't let implementation drift silently away from it.

---

## 1. Platform overview

HiyazaFinder is three components sharing one Supabase Postgres database, with clearly separated
responsibilities:

| Component | Owns | Never does |
|---|---|---|
| **Flutter app** | Field data collection: search, review, edit, add people/parcels, mark work complete. Fast, resilient to bad connectivity. | Bulk import, analytics, user/city management |
| **Dashboard** | Control plane: import, correction at scale, review queue, audit, analytics, user/city management, export. | Field capture workflows |
| **Supabase/Postgres** | Source of truth, authorization (RLS), durability, the freshness signal, cross-app consistency. | Presentation logic |

Neither app talks to the other directly. All coordination happens through shared database tables and
one freshness signal (`cities.data_version`).

---

## 2. The one pattern everything else is built on

**Immutable base + append-only overlay, merged at read time.** `holdings`/`added_holdings` rows are
never overwritten; every correction from either app is a new `holding_edits` row; the current value is
base + latest overlay. This is the foundation for auditability — nothing is ever destroyed — and for
both apps sharing one mental model of "what is the current state of this record." Every extension in
this document (completion state, provenance, new association types) is designed to fit this pattern,
not bypass it. This is the one piece of the existing architecture explicitly **not** being redesigned.

---

## 3. Extensibility principle: registries, not branches

Both existing codebases already independently discovered the same solution to "how do we keep adding
things without editing core code": the import pipeline's `ColumnMapping` registry, the analytics
`MetricDefinition`/quality-rules registries, and the Flutter app's `BulkEditableField` enum+extension.
This becomes the platform's standard extensibility mechanism, applied consistently:

- New association types → a row in the `association_types` table, not an enum value + redeploy.
- New sync operation types → a new `SyncOperationHandler` registered by its owning feature, not a new
  case in a shared sealed class belonging to a different feature.
- New Dashboard analytics/reports/exports → a new registered definition, not a new branch in a shared
  component.
- Holding Details page sections that vary **by association type** (a real, current need — Credit and
  Reform cities already show different fields) → registered, conditional sections.

**Deliberately scoped, not applied everywhere:** the registry pattern is not used for hypothetical
future needs with no current signal. Holding Details is otherwise plain composition; a general
"section registry" for a single page with one consumer would be indirection with no payoff. Apply the
pattern where a second, real variation already exists — not preemptively.

---

## 4. Data ownership

| Data | Owner (writer of record) | Readers |
|---|---|---|
| `holdings` (import) | Dashboard only | Both apps |
| `holding_edits` | Both apps (append-only) | Both apps |
| `added_holdings` | Flutter app (create), Dashboard (review/promote) | Both apps |
| `persons` | Flutter app (create-on-first-parcel), Dashboard (correction) | Both apps |
| `import_batches`, `quality_snapshots`, `audit_feed` | Dashboard only | Dashboard only |
| `profiles` | Supabase Auth (create), Dashboard (role/status) | Both apps (own profile), Dashboard (all) |

No table has two independent, uncoordinated writers of the *same field*. Where both apps can affect a
holding's data, they do it through the identical `holding_edits` overlay mechanism — never through
separate code paths.

---

## 5. Synchronization flow

**Status: superseded by the actual implementation — online-first, no outbox.** The original design
below (§5, §5.1, §5.2) called for an offline-first local queue (`SyncOperation`/`SyncOperationHandler`/
`SyncRunner`) as the highest-priority piece of the Flutter rebuild. That was never built, and a later
commit explicitly removed the sync-outbox tests that had been scaffolded for it. The app's actual,
intentional design is **online-first**: every write method on `HoldingsRepository` (`addLocalParcel`,
`deleteLocalParcel`, `updateParcel`, `setParcelReviewed`, `bulkApplyField`, now delegating to
`ParcelSyncService` — see `lib/features/holdings/data/services/parcel_sync_service.dart`) awaits its
Supabase call directly and only mutates in-memory/local-cache state once the server has confirmed the
write. A failed write throws and leaves local state untouched, for the caller to catch and surface an
error — there is no local-first deferral, no durable queue, and no reconnect-triggered flush. This
paragraph, not the outbox description that follows, is the current source of truth; §5.1/§5.2 are kept
below only as a historical record of the originally-designed (and abandoned) alternative.

**Original design (not implemented, kept for history):**

```
Flutter write (edit / add / complete)
  → written to local snapshot immediately (UI updates instantly)
  → SyncOperation enqueued in the same call, durable local storage
  → outbox flush (on connectivity regained / app resume / manual) processes the queue
      in order, idempotent by client-generated operation id, exponential backoff
  → success: server row inserted/updated (idempotent — see §9) → trigger bumps
      cities.data_version → Realtime broadcasts the change
  → failure: retried up to N times, then parked as a visible "failed" item —
      never silently retried forever, never silently dropped
```

### 5.1 SyncOperation is data; execution is a separate, registered concern

`SyncOperation` is a pure, serializable data description (`type`, `entityId`, `payload`, `createdAt`,
`attempts`) — it does not know how to execute itself. A `SyncOperationHandler` — one per operation
type, registered by the feature that owns that operation — knows how to execute it.
`SyncRunner` (generic infrastructure, lives in `core/sync/`, has zero imports from any feature) looks
up the handler for an operation's `type` from a registry and calls `handler.execute(operation)`.

This keeps the extensibility principle (§3) honest: a future feature needing durable sync registers
its own handler and never touches `core/sync/` or any other feature's code. It also keeps `core/sync/`
a Single-Responsibility module — it schedules and retries, it does not know what any particular
operation *means*.

### 5.2 Reconnect is one sequence, not two independently-triggered checks

*Reconnect → flush outbox → staleness check → prompt/refresh* is one ordered flow, not "flush
whenever" plus "check staleness on app open" as two things that can drift apart. A device that comes
back online mid-session, flushes its queue, and then keeps working against a now-outdated base
snapshot (because the Dashboard re-imported that city while it was offline) is a real gap otherwise —
this ordering closes it.

---

## 6. Event flow

**Status: partially superseded, per §5's online-first correction.** Steps 1–2 below describe the
never-built outbox and don't reflect the actual flow. The real shape, reused for edits, additions, and
completions alike:

1. **Server round-trip first** — `ParcelSyncService` (`lib/features/holdings/data/services/
   parcel_sync_service.dart`) awaits the Supabase write directly; there is no local-optimistic step and
   no durable enqueue ahead of it.
2. **Server persistence** — the write lands as a real row (`holding_edits` insert, `added_holdings`
   insert, a completion-state update).
3. **Local state update** — only once the server has confirmed the write does `HoldingsRepository`
   mutate its in-memory dataset/local cache. A failed write throws before this step runs, leaving local
   state exactly as it was.
4. **Trigger-driven propagation** — a DB trigger bumps `cities.data_version` (freshness signal) and,
   where applicable, writes an `audit_feed` entry (Dashboard visibility) — populated by the database,
   not application code, so it can't be bypassed by a code path that forgets to log.
5. **Translation** — the raw Postgres row change is translated into a `Parcel` by `holdingRowToParcel`/
   `addedHoldingRowToParcel` (`lib/features/cities/data/holding_row_mapper.dart`) in exactly one place.
   No feature handler ever parses a raw table row directly.
6. **Realtime broadcast** — subscribed clients receive the mapped `Parcel` and patch local state via
   `ParcelChangeHandler` (`lib/features/sync/domain/parcel_change_handler.dart`) — the same interface
   `HoldingsRepository` implements for its own local writes' bookkeeping, so "I made this change" and
   "someone else made this change" both funnel through one contract.

---

## 7. Realtime flow

Subscriptions stay scoped to the active city (correct for the offline-work model; multi-city
simultaneous work is explicitly out of scope — see §12). `RealtimeSyncService`
(`lib/features/sync/data/realtime_sync_service.dart`) depends on the `ParcelChangeHandler` interface
rather than the concrete `HoldingsRepository`, so it isn't hardcoded to one feature's class — but this
is currently a single interface with a single implementation/consumer, not a registry of many handlers
keyed by event type. If a second feature needs its own realtime handling, extending this to an actual
registry (dispatch by table/event type to whichever handler is registered) is the natural next step —
not yet needed, per the extensibility principle's own "don't build for one consumer" rule (§3).

**The one place allowed to know about every feature at once** is the composition root — the
dependency-injection setup that wires which handler serves which operation type / domain event. This
is a deliberate, documented exception to "features don't know about each other," not a coupling leak
that was missed.

---

## 8. Validation flow

Two layers, deliberately not merged into one, because they serve different purposes:

- **Client-side** (Flutter form validators / Dashboard Zod schemas) — fast feedback, works offline,
  never authoritative on its own.
- **Server-side** (Postgres constraints, RLS, trigger-enforced rules) — the actual authority; nothing
  is trusted just because the client accepted it.

Where a rule exists on both sides (e.g., national ID format), it is documented once, in
`PROJECT_OBJECTIVES.md`'s business-rules table, as the reference both implementations must match. This
isn't a DRY violation — client and server validation exist for different reasons (UX speed vs.
integrity) — but the *rule itself* has one documented source of truth even though it is implemented
twice, specifically to prevent the two apps' understanding of a rule from drifting apart silently.

**Deliberately not enforced as a hard DB constraint:** `feddan`/`qirat`/`sahm` vs. `total_sqm`
consistency. Partial, in-progress field data is normal during active collection; a hard constraint
would block legitimate incomplete records. This stays a *soft* rule (the Dashboard's quality board
flags it) — a conscious choice, not an oversight.

---

## 9. Idempotency

**Status: partially superseded, per §5's online-first correction** — there is no sync outbox/flush to
retry, so the "retried flush" scenario below doesn't arise the way originally described. What's
actually live: `holding_edits.client_op_id` (confirmed via the live schema, not `operation_id` as
originally named here) carries a client-generated id through to the database, and
`added_holdings.client_id` (unique) provides the same guarantee for record creation — both still
useful for detecting an accidental double-submit from the UI layer itself, just not for a queue-replay
scenario that no longer exists.

---

## 10. Review / completion workflow

Two distinct, permanent, non-conflicting states — not one ambiguous flag:

- **`completed_at` / `completed_by`** — **field-worker** signal: "I copied this parcel's ID, I'm done
  collecting it." Drives the app's active/completed split.
- **`reviewed` / `reviewed_at` / `reviewed_by`** — **staff/Dashboard** signal: "an admin has checked
  this record's data quality." A distinct workflow, owned by a different role, running independently.

**State transitions (field-worker completion):**

```
Open ──(copy Parcel ID)──▶ Completed ──(manual reopen)──▶ Open
```

Entering `Completed` goes through the same online-first write path as any other write (§5,
`ParcelSyncService.syncMarkReviewed`) — the app awaits server confirmation before reflecting it
locally, and it propagates to other devices via Realtime (§7). "Survive bad connectivity" here means
"the write throws and the UI shows an error if offline," not queued-for-later-retry, since there is no
outbox.

---

## 11. Add-person / add-parcel workflow

**Status: `persons` table premise superseded.** This section originally called for a dedicated
`persons` table (see `DATABASE_REFERENCE.md` §4.6, similarly corrected). That was never built; the
live mechanism is `holdings.person_id`/`added_holdings.person_id` — a generated, trigger-maintained
grouping id (see the live schema's own column comment: "Generated grouping id for a person's parcels
— one shared id per real national_id, an independent id per placeholder/NULL national_id row"), backed
app-side by `Parcel.personId`/`Parcel.pendingGroupId` (`lib/features/holdings/domain/entities/
parcel.dart`) rather than a foreign key into a `persons` table. Treat this as the real mechanism, not a
gap to close.

One atomic operation, one server round-trip (`ParcelSyncService.syncAddParcel`), one local-state
update — never two steps that could partially fail and leave an orphaned person or parcel. Once
synced, an added record is addressable identically to an imported one everywhere in the system.

**Duplicate-person prevention:** unlike the originally-planned partial unique index on a `persons`
table, duplicate prevention today is whatever the live `person_id`-assignment trigger
(`assign_person_id()`, confirmed on `added_holdings`) does at insert time — this doc doesn't have
independent confirmation of its exact matching behavior; check the live migration/trigger definition
(dashboard-repo-owned, per `DATABASE_REFERENCE.md`'s corrected §6) rather than assuming the
national-id-unique-index design below is what's actually enforced.

**Deletion:** soft-delete (`deleted_at`/`deleted_by` on `added_holdings`). The field worker's
experience is identical to a hard delete — the parcel disappears from every view immediately — but the
row and its edit history remain, satisfying "nothing is temporary" for records that existed and were
later removed. Every query listing `added_holdings` filters `deleted_at is null`.

---

## 12. Auditability

Guaranteed structurally, not by convention: append-only `holding_edits`/`persons` history,
`completed_at`/`completed_by` and `reviewed_at`/`reviewed_by` stamped writes, `audit_feed` populated by
triggers, `target_was_stale` flagging edits that landed on a since-superseded holding (§13.2) instead
of silently disappearing, and soft-delete instead of hard-delete for added records. The Dashboard's
audit trail is a read view over data the system cannot help but produce.

---

## 13. Scalability and known ceilings

Stated as concrete thresholds, not vague reassurance:

1. **Full-city-snapshot-in-memory** is sound up to roughly the low tens of thousands of holdings per
   city (current largest sample city: ~1,200 rows — real headroom, not unlimited). If a city
   approaches that ceiling, the fallback is basin-scoped download instead of whole-city — the domain
   already partitions by basin, so this is a different download granularity, not a new concept.
2. **`unified_holdings_export`'s 20k-row cap** (Dashboard) is fine today; worth revisiting as a
   background/async export job before total system holdings approach it.
3. **`holding_edits` grows forever** by design (append-only). Not urgent, but a project meant to run
   for years needs a retention/archival story eventually — year-based partitioning is the standard
   answer, deferred until table size is actually a measured problem.
4. City-scoped Realtime channels, trigram search, and server-side pagination are all appropriate at
   current and reasonably-projected scale; no changes recommended.

**Explicit, conscious scope boundary:** one active city at a time per device. Nothing in the business
vision requires simultaneous multi-city work, and the assumption is baked reasonably deep (one local
snapshot, one realtime channel). Named here so a future reader knows this was a decision, not an
oversight.

---

## 14. Offline/online edge cases addressed by this design

| Scenario | Resolution |
|---|---|
| Device reconnects after being offline during a re-import | §5.2 — flush is followed by a mandatory staleness check, not a separate app-open-only check |
| A queued edit's target holding went stale while the device was offline | `holding_edits.target_was_stale` flag set at insert time; surfaced in the Dashboard's review-queue pattern rather than silently merging into nothing |
| Retried sync operation after a lost server acknowledgment | `operation_id` uniqueness (§9) — no duplicate rows, no duplicate audit entries |
| Two field workers create the "same" new person concurrently, offline | §11 — structural prevention where `national_id` exists, flagged detection otherwise |
| A sync operation fails repeatedly | Parked as a visible failed item after N attempts — never retried forever, never silently dropped |

---

## 15. Forward-compatibility, taken cheaply now

`persons.external_refs jsonb not null default '{}'` — a future external system integration (the
Dashboard's own documentation already hints at a possible "farmer card" system link) gets a home
without a schema change when it arrives. Costs nothing today; committed to no specific integration
shape.
