# HiyazaFinder — Implementation Plan (ticket-level)

**Status:** Execution breakdown of `REFACTOR_ROADMAP.md`. Read `SYSTEM_DESIGN.md`,
`DATABASE_REFERENCE.md`, and `PROJECT_OBJECTIVES.md` first — this document assumes that context and
does not repeat the reasoning behind each decision, only the work.

**How to run this:** one ticket = one Claude Code session = one PR, gated before the next ticket
starts. Don't hand an agent a whole phase at once. Point a Flutter session at `hiyaza-finder` for
Phases 1 (DB) and 2, and a Dashboard session at `hiyaza-dashboard` for Phase 3 — run DB migrations
from the Flutter repo only (it's the canonical schema owner per `APP_PLAN.md`), then pull the same
migration files into `hiyaza-dashboard/supabase/migrations/` to keep both repos' migration history
identical.

**Gate, every ticket, no exceptions:** Flutter — `flutter analyze` clean + `flutter test` green +
manual walkthrough of the specific flow. Dashboard — typecheck + lint + unit tests + relevant E2E spec
green. Database — migration applies cleanly to a staging copy, RLS re-verified for any touched table,
existing app/Dashboard behavior unchanged.

---

## Phase 1 — Database (10 tickets, all additive, low risk)

| #    | Ticket                                                                                                                                                                                                       | Touches                                      | Gate                                                                                                        |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 1.1  | `association_types` table + seed (2 current values) + `cities.association_type_code` FK                                                                                                                      | new migration                                | Existing `cities.association_type` reads unaffected                                                         |
| 1.2  | `holding_edits.holding_type` discriminator column, default `'holding'`                                                                                                                                       | new migration                                | Existing rows all get the default, no nulls                                                                 |
| 1.3  | `editable_fields` table + seed from current editable-field list + write-time validation trigger on `holding_edits`                                                                                           | new migration                                | Existing edit payloads still insert successfully                                                            |
| 1.4  | `added_holdings.reform_type` column                                                                                                                                                                          | new migration                                | Reform-city field records now round-trip this value                                                         |
| 1.5  | Automate `city_top_holders` refresh (trigger or scheduled job on import commit)                                                                                                                              | migration + Dashboard import completion hook | Counts stay fresh without a manual step                                                                     |
| 1.6  | `persons` table + indexes + partial unique `(city_id, national_id)` + `external_refs` + nullable FK from `holdings`/`added_holdings` + backfill script (one `persons` row per distinct existing `person_id`) | new migration + one-off backfill script      | Backfill script dry-run reviewed before running against production                                          |
| 1.7  | `completed_at`/`completed_by` on `holdings` + `added_holdings`                                                                                                                                               | new migration                                | `reviewed` columns untouched                                                                                |
| 1.8  | `added_holdings.deleted_at`/`deleted_by`                                                                                                                                                                     | new migration                                | Every existing query listing `added_holdings` audited for a `deleted_at is null` filter                     |
| 1.9  | `holding_edits.operation_id` (unique) + `target_was_stale` + insert trigger                                                                                                                                  | new migration                                | Existing rows get `operation_id = null`, `target_was_stale = false`                                         |
| 1.10 | `national_id` 14-digit `CHECK` constraint on `holdings`/`added_holdings`/`persons`                                                                                                                           | new migration                                | Run against production data first — if existing rows violate it, decide `NOT VALID` + backfill vs. blocking |

**Explicitly not in this phase:** the legacy `id`/`client_id` backfill (Phase 4 — needs separate sign-off, rewrites synced production rows).

---

## Phase 2 — Flutter (16 tickets)

### Cleanup / refactor foundation (no schema dependency — can start immediately, in parallel with Phase 1)

| #   | Ticket                                                                                                                                       | Gate                                                                                                                                   |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 2.0 | Remove unused Firebase deps, pin all `pubspec.yaml` versions, delete dead `firebase_handler.dart`                                            | Builds clean, no behavior change                                                                                                       |
| 2.1 | Extract `ParcelQueryService`, `ParcelEditOverlay`, `BulkEditService`, `ClipboardFormatter` out of `HoldingsRepository` (behavior-preserving) | Same search results, same copy-all output, same bulk-edit behavior — new unit tests on all four, including the ورثة/مفوض prefix matrix |
| 2.2 | Introduce `KeyValueStore` interface; remove inline `SharedPreferences.getInstance()` calls                                                   | No behavior change, now mockable                                                                                                       |
| 2.3 | Split `HomeCubit` into `SessionCubit` / `CityCubit` / `SearchCubit`                                                                          | Each cubit independently unit-tested                                                                                                   |

### Sync infrastructure (needs 1.7/1.8/1.9 from Phase 1)

| #   | Ticket                                                                                                                                                          | Gate                                                                                                 |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| 2.4 | Build `core/sync/`: `SyncOperation` (pure data), `SyncOperationHandler` interface, `SyncRunner`, durable local queue, backoff, park-after-N-failures            | Unit tests: idempotent retry, backoff timing, failure parking                                        |
| 2.5 | Register holdings-feature handlers (`EditHolding`, `AddRecord`, `BulkEdit`) against `core/sync/` — zero imports from `core/sync/` into `features/holdings/`     | Kill app mid-flush, confirm no duplicate rows on restart                                             |
| 2.6 | Realtime domain-event translation layer (`ParcelChanged`/`PersonCreated`/`ParcelCompleted`) replacing direct `RealtimeSyncService` → `HoldingsRepository` calls | Two devices, one edits, other sees it live via the new path                                          |
| 2.7 | Reconnect flow wired as one sequence: flush → staleness check → refresh                                                                                         | Go offline, edit, re-import city from Dashboard, reconnect — device ends up on fresh data, not stale |

### New workflows (needs 1.6/1.7/1.8 from Phase 1)

| #    | Ticket                                                                                                               | Gate                                                                                                                                         |
| ---- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| 2.8  | Completion state: `ParcelCompletionService`, copy-ID triggers completion, manual reopen, active/completed list split | Completion syncs via outbox, visible on a second device                                                                                      |
| 2.9  | Person-centric navigation: person search/list, person detail screen showing all parcels                              | Opening a person shows every parcel correctly grouped via `persons` FK                                                                       |
| 2.10 | Atomic add-person / add-parcel rebuild: one use case, one sync op, duplicate-detection call (non-blocking warning)   | Create person+parcel offline, sync, verify one `persons` row + correctly linked parcel; concurrent-duplicate test with two simulated devices |
| 2.11 | Soft-delete-aware UI for added parcels (delete action + `deleted_at is null` everywhere)                             | Deleted parcel vanishes from every list immediately; row confirmed still in DB                                                               |

### UI/UX redesign

| #    | Ticket                                                                                        | Gate                                                        |
| ---- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| 2.12 | Progressive-disclosure parcel detail redesign (identifying info first, full detail on demand) | Manual walkthrough — fewer taps to identify correct parcel  |
| 2.13 | Sync-status badge (pending count, last sync, retrying/failed states, manual sync action)      | Visible state matches actual outbox state in every scenario |
| 2.14 | In-app lightweight per-city statistics (original/modified/added/reviewed counts)              | Matches Dashboard's own counts for the same city            |

### Retirement + hardening

| #    | Ticket                                                                                                                     | Gate                                                        |
| ---- | -------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| 2.15 | Retire Excel-picker legacy path (`file_picker`/`spreadsheet_decoder`, history screens, association-name-confirmation flow) | No reference to either package remains; app smaller         |
| 2.16 | Hardening: 24h offline soak test with 20+ queued ops, accessibility pass, empty/error states audited everywhere            | Full test suite green; soak test syncs cleanly on reconnect |

---

## Phase 3 — Dashboard (6 tickets, can run in parallel with Phase 2)

| #   | Ticket                                                                                                                                                                                   | Gate                                                                                |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 3.1 | `association_types` management UI (needs 1.1)                                                                                                                                            | Adding a type is a Dashboard action, zero deploy                                    |
| 3.2 | Holding Details page — base composition + association-type-conditional sections via small registry                                                                                       | Every field from `PROJECT_OBJECTIVES.md` §4 present, no raw-table inspection needed |
| 3.3 | Provenance (original/modified/added) surfaced in Holdings table, extending existing `isEdited` overlay with a source dimension                                                           | Filter by provenance works at 10k+ rows                                             |
| 3.4 | Per-user activity pulled into Users page from existing team-activity data                                                                                                                | No new data queries — presentation only                                             |
| 3.5 | Audit trail updated to use `holding_type` (needs 1.2) instead of guessing; new "orphaned/conflicting edits" filter over `target_was_stale` (needs 1.9), reusing existing review-queue UI | Seed a stale-target edit, confirm it surfaces in the filter                         |
| 3.6 | Home/City statistics upgrades from existing analytics views                                                                                                                              | Loads under 2s against seeded multi-city dataset                                    |

---

## Phase 4 — Cross-cutting closure (after 1–3 are stable)

| #   | Ticket                                                                                        | Notes                                                                                |
| --- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| 4.1 | Flutter captures the 3 export-gap fields (owner national ID, farmer-card names, growth stage) | Blocked on domain definition (esp. growth-stage enum) being agreed first             |
| 4.2 | Dashboard removes export fallback logic once 4.1 ships real data                              |                                                                                      |
| 4.3 | Legacy `id`/`client_id` backfill                                                              | **Requires your explicit go-ahead before running** — rewrites synced production rows |
| 4.4 | Per-city user scoping                                                                         | Only if still needed by this point                                                   |

---

## Sequencing

- **Start immediately, in parallel:** Phase 1 (DB) + tickets 2.0–2.3 (Flutter cleanup, no schema dependency) + all of Phase 3 that doesn't depend on 1.1/1.2/1.9 (i.e., 3.3, 3.4, 3.6 can start now; 3.1, 3.2, 3.5 wait on Phase 1).
- **After Phase 1 lands:** the rest of Phase 2 (2.4 onward) and the remaining Phase 3 tickets.
- **Last:** Phase 4.

## On timing

No reliable wall-clock number — it depends on your review cadence between PRs, not generation speed.
What's concrete: **10 DB tickets (small, mechanical) + 16 Flutter tickets (several genuinely large —
2.4, 2.9, 2.10, 2.12 especially) + 6 Dashboard tickets (small–medium) + 4 closure items ≈ 36 discrete,
independently-gated units of work.** Treat this as weeks of elapsed time once you include your own
review and testing between merges, not hours — the gate discipline exists specifically so Phase 2
(the daily-use production tool) never has more than one ticket's worth of unverified change in flight
at a time.
