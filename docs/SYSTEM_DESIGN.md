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

One consistent shape, reused for edits, additions, and completions alike:

1. **Local optimistic event** — the write lands in local state and the UI reflects it before any
   network round-trip.
2. **Durable enqueue** — the write becomes a `SyncOperation`, survives app restarts, is retried until
   it succeeds or is parked.
3. **Server persistence** — the operation lands as a real row (`holding_edits` insert, `added_holdings`
   insert, a completion-state update), idempotently (§9).
4. **Trigger-driven propagation** — a DB trigger bumps `cities.data_version` (freshness signal) and,
   where applicable, writes an `audit_feed` entry (Dashboard visibility) — populated by the database,
   not application code, so it can't be bypassed by a code path that forgets to log.
5. **Translation** — the raw Postgres row change is translated into a domain event (`ParcelChanged`,
   `PersonCreated`, `ParcelCompleted`) in exactly one place. No feature handler ever parses a raw table
   row directly.
6. **Realtime broadcast** — subscribed clients receive the domain event and patch local state through
   the same per-feature handler that applied the local optimistic event in step 1. One code path
   handles "I made this change" and "someone else made this change" — not two.

---

## 7. Realtime flow

Subscriptions stay scoped to the active city (correct for the offline-work model; multi-city
simultaneous work is explicitly out of scope — see §12). The dispatch mechanism is generic: instead of
a realtime service calling concretely into a specific feature's repository, it publishes the domain
events from §6 step 5, and any registered feature handler can consume them. A future feature needing
live updates registers a handler instead of the realtime service growing a new hardcoded call.

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

Every write that goes through the sync outbox carries the operation's client-generated id
(`operation_id`) through to the database (`holding_edits.operation_id`, unique). A retried flush after
a lost server acknowledgment is `on conflict do nothing`, not a second row. This matters more than it
would in a system without a user-facing audit trail: a phantom duplicate edit isn't just harmless
noise once every row is a visible entry in someone's audit timeline (per the Dashboard's History &
Activity vision) — it's a misleading one.

`added_holdings.client_id` (already unique) provides the same guarantee for record creation.

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

Entering `Completed` goes through the same sync-outbox path as any other write (§5) — it must survive
bad connectivity and propagate via Realtime, per the business vision's requirement that other users
immediately see a parcel has been processed. Modeled as its own domain service in the Flutter app, not
logic embedded in a widget or smeared across a search cubit.

---

## 11. Add-person / add-parcel workflow

One atomic operation, one `SyncOperation`, one local-state update — never two steps that could
partially fail and leave an orphaned person or parcel. Once synced, an added record is addressable
identically to an imported one everywhere in the system.

**Duplicate-person prevention, two layers, because the honest answer differs by data availability:**
- Where `national_id` is captured, a partial unique index (`persons(city_id, national_id) where
  national_id is not null`) makes an *exact* duplicate structurally impossible.
- Where it isn't (a brand-new person, offline, two devices, no shared ID yet), structural prevention
  across two devices that don't know about each other isn't possible. Instead: a server-side fuzzy
  name-match check at sync time flags — never blocks — a probable duplicate, surfaced through the same
  review-queue pattern the Dashboard already has for `added_holdings`. Detection, not silent
  prevention, is the honest design for the offline case.

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
