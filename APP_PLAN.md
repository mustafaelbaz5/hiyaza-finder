# HiyazaFinder — App Plan v2: Server-Backed, Refactored, Multi-City

> Supersedes the offline-only architecture in `FLUTTER_APP_PLAN.md` (kept as v1 historical
> reference — its screens, search algorithm, and copy-all format still apply and are **reused**,
> just re-pointed at a server-backed data source). Companion document: `DASHBOARD_PLAN.md`.
>
> **This document is the canonical source for the database schema.** The dashboard project reads it
> from here. Schema changes happen here first.

---

## 1. Context

The app today works entirely from a locally-picked Excel file: one file = one dataset, loaded fully
into memory, edits stored in `SharedPreferences`, never synced anywhere. Two things change at once:

1. **Backend**: move to **Supabase** (Postgres + Auth + Storage), organized **per city/جمعية**.
2. **Codebase**: the current feature code has grown organically and needs a **structural refactor
   onto clean architecture + SOLID** before (and partly during) the backend migration. Bolting a
   sync layer onto the current `HoldingsRepository` would make a large class much larger — see § 5.

**Priority order (stated by the product owner):**

1. Refactor + Supabase schema + auth + city download (foundation).
2. **In-app add/edit-to-database** — the highest-value feature.
3. Everything else (dashboard, analytics).

**Tooling note:** the **Supabase MCP is connected**, so schema creation, migrations, RLS policies,
and seed data in § 6 can be applied directly rather than by hand in the dashboard UI. Apply the SQL
in § 6 as **numbered migration files** under `supabase/migrations/` so the dashboard project shares
the same history — never as ad-hoc statements.

---

## 2. Key decisions (locked in)

1. **New/added records live in a separate table** (`holdings` = authoritative import,
   `added_holdings` = app-created). The import stays immutable.
2. **Sync conflicts resolve last-write-wins by timestamp.** Single field team per city makes
   collisions unlikely; revisit only if it bites.
3. **Access scope is open** — any authenticated app user can download any published city. No
   per-user city assignment in v1 (schema leaves room for it).
4. **The local-Excel-picker flow is fully retired.** One flow: log in → pick a city → download →
   work offline.
5. **The app requires login** (Supabase Auth, email/password). Every add/edit is stamped with the
   user id — this is what makes the dashboard's audit trail possible.
6. **Downstream sync = re-download on next open / manual refresh.** No realtime subscriptions in v1.
7. **Excel structure is confirmed** from the real sample file — see § 4.
8. **"Add parcel for existing person" template** copies **all fields** from the person's most recent
   record **except** المساحة (فدان/قيراط/سهم — entered fresh) and رقم الأرض (defaults to `-1`).
   Everything else pre-fills and stays editable.
9. **(New) The refactor is not optional and not a separate project.** It happens as Phase 0 and is
   interleaved with the migration — each phase leaves the app working. No big-bang rewrite.
10. **(New) The domain layer knows nothing about Supabase, Excel, or Flutter.** This is the rule that
    makes the whole thing testable and lets the data source change again later without touching
    business logic.

---

## 3. Architecture principles

### 3.1 Layering (clean architecture, pragmatic)

Three layers per feature, with a **strict inward-only dependency rule**:

```text
presentation/ ──▶ domain/ ◀── data/
   (UI, cubits)   (entities,    (Supabase, local
                   repo             storage, Excel)
                   interfaces,
                   use cases)
```

- **`domain/`** — pure Dart. Entities, repository **interfaces** (abstract classes), use cases,
  domain services. **Imports nothing** but other domain code (no `package:flutter`, no `supabase`,
  no `shared_preferences`). If you can't unit-test it without a `WidgetTester` or a network, it's in
  the wrong layer.
- **`data/`** — implements the domain interfaces. DTOs/models with `fromJson`/`toJson`, remote and
  local data sources, the repository implementation that combines them.
- **`presentation/`** — cubits and widgets. Depends on domain **interfaces and use cases only**;
  never imports anything from `data/`.

Wiring happens once, in DI. That is the only place that knows `SupabaseHoldingsRepository` exists.

### 3.2 SOLID, made concrete for this codebase

- **SRP** — the current `HoldingsRepository` (411 lines) does file picking, disk caching, history
  management, parse orchestration, association-name persistence, edit overlay, search delegation,
  aggregation, and bulk edit. That's **eight** reasons to change. § 5 splits it into eight focused
  units. Rule going forward: **a class has one reason to change; a file stays under 300 lines; a
  method under 40.**
- **OCP** — `BulkEditableField` already models "which field is being bulk-edited" as an enum +
  extension rather than a switch scattered across the UI; keep that pattern. New sync operation
  types plug into the outbox via a sealed class, not by editing a growing `if` chain.
- **LSP** — `HoldingsRepository` becomes an abstract interface. `SupabaseHoldingsRepository` (real)
  and `FakeHoldingsRepository` (tests) are interchangeable. Any test that needs to mock HTTP means
  the abstraction leaked.
- **ISP** — split the fat repository interface by **use**: `HoldingsReader` (search, basins,
  parcels-for-holding), `HoldingsWriter` (update, bulk apply, add), `CityCatalog` (list/download
  cities), `SyncQueue`. A widget that only reads depends only on the reader.
- **DIP** — cubits depend on use cases, use cases depend on interfaces. **`Supabase.instance` and
  `SharedPreferences.getInstance()` appear in exactly one file each** (their respective data
  sources). Today `SharedPreferences.getInstance()` is called inline in ~8 places inside
  `HoldingsRepository` — that must all go behind a `KeyValueStore` interface.

### 3.3 Clean-code rules

1. **No business logic in widgets.** A widget renders state and reports intent. Formatting logic
   (like `_formatForClipboard`) moves to a domain service (`ClipboardFormatter`) so it can be
   unit-tested — right now it's untestable inside a widget.
2. **Errors are values, not exceptions,** across layer boundaries: use cases return
   `Result<T, Failure>` (the repo already has `core/errors/failure.dart` — use it consistently).
   Today `HoldingsFilePickCancelled` is thrown for control flow; that goes away.
3. **Immutable state.** `HomeState` stays immutable with `copyWith`. The repository must stop
   mutating `_parcels[i]` in place — that hidden mutation is why `refreshData()` had to be added.
4. **Every entity has stable identity.** Today `Parcel.id` is the **list index** (`i.toString()`)
   assigned at load time — it changes if the file changes, and is meaningless to the server. It
   becomes the **server UUID** (or a locally-generated UUID for offline-created records).
5. **No magic strings.** Table names, storage keys, and column names live in one constants file.
6. **`const` everywhere it's possible**, `final` on all fields, prefer expression bodies.
7. **Dead code is deleted, not commented out.** `dependency_injection.dart` currently has a
   commented-out Dio/AuthRepository block — remove it.

### 3.4 Dependency cleanup (do this first — it's 10 minutes)

`pubspec.yaml` currently declares **both** Firebase (`firebase_core`, `firebase_auth`,
`cloud_firestore`, `firebase_storage`) **and** Supabase. Firebase is unused. Remove all four plus
`lib/core/errors/handlers/firebase_handler.dart`. Also: replace every `any` version constraint with
a real caret constraint — `any` makes builds non-reproducible.

---

## 4. Sample Excel structure (`الدير_ائتمان_مجمع.xlsx`)

Inspected directly (unzipped the `.xlsx`, read the sheet XML). **This is the format the dashboard's
importer targets** — the app no longer parses Excel at all once Phase 4 lands.

**Workbook — 9 sheets, all with an identical 20-column layout:**

- `جميع البيانات` ("All Data") — **the only sheet to parse.** 1,202 data rows in the sample.
- 7 basin-name sheets (`البشيط`, `السرو الشرقى`, `السواخ`, `الشياخه`, `المقبيه`, `داير الناحية`,
  `طلعت`) — each is just `جميع البيانات` filtered to one اسم الحوض. **Redundant; skip.**
- `بيانات ناقصة` ("Missing data") — same 20 columns, pre-filtered to rows with placeholder/zero
  values (281 of 1,202, ~23%). A ready-made cross-check for the dashboard's data-quality board, but
  the rules should be **recomputed from the database** so they work for files lacking this sheet.

**Row layout:** row 1 = `القطاع : الائتمان الزراعي` (sector), row 2 =
`الجمعية الزراعية : الدير -الائتمان الزراعي` (association). **Row 3 is the header row**, data starts
row 4. The importer must **locate the header row by matching known labels**, not hardcode row 3.

**Columns A–T:**

| Col | Header | Cell type | Domain field | Notes |
|---|---|---|---|---|
| A | رقم الحيازة | text | `holdingIdNumber` | Not unique — repeats loosely (`101`, `42`, `0148`), inconsistent zero-padding |
| B | اسم الحائز | text | `holderName` | |
| C | الرقم القومي | text | `nationalId` | 14 digits when present |
| D | رقم الارض | **number** | `landNumber` | Stored as text in the domain — **coerce** |
| E–G | فدان / قيراط / سهم | number | `feddan`/`qirat`/`sahm` | |
| H | المساحه بالمتر | number | `totalSqm` | Can be fractional (`2260.74`) |
| I–L | الشرقى / الغربى / القبلى / البحرى | text | `borderEast/West/South/North` | **Order differs** from the app's E/S/W/N — map by header text, never by position |
| M | رقم الصفحة | **number** | `pageNumber` | **Coerce** to text |
| N | كود الحوض | **number**, often blank | `basinCode` | Frequently empty — **coerce**, default `-1` |
| O | اسم الحوض | text | `basinName` | |
| P | **الجمعيه** | text | `associationName` | **A real per-row column.** The current app *derives* this from the filename and prompts the user to confirm it — that entire flow is deleted (see § 5) |
| Q | الأداره | text | `administration` | |
| R | المديريه | text | `directorate` | |
| S | **عدد القطع بالحيازة** | number | *(not stored)* | Precomputed parcel count. Derivable via `COUNT(*)`; use it as an **import validation check** instead |
| T | **الرقم الموحد للحيازة** | text | `unifiedNumber` | e.g. `06-3230-00323905-001159` — a stable official identifier, **better than رقم الحيازة for upserts** |

**Open:** whether every city's file uses this exact layout. The importer must fail loudly on an
unrecognized shape rather than guess.

---

## 5. Refactoring the existing code

Concrete, file-by-file. Everything here is a **behavior-preserving** move except where noted.

### 5.1 Splitting `HoldingsRepository` (411 lines → 8 focused units)

| Current responsibility | Becomes | Layer | Fate |
|---|---|---|---|
| `loadFromPickedFile()` — file picking | *(deleted)* | — | Retired with decision #4 |
| `_cacheBytes()` — copying workbooks to disk | `HoldingsSnapshotCache` (city JSON, not xlsx) | data | Rewritten |
| history: `getHistory`, `_rememberInHistory`, `_saveHistory`, `removeHistoryEntry` | *(deleted)* | — | Replaced by the city picker |
| `compute(_parseHoldingsBytes)` — parse orchestration | *(deleted)* | — | Parsing moves to the dashboard |
| `deriveAssociationName`, `confirmAssociationName` | *(deleted)* | — | Column P supplies it (§ 4) |
| `_applyEdit`, `updateParcel`, `resetParcel`, `_edits` | `ParcelEditOverlay` | domain | Kept, extracted |
| `search`, `availableBasins`, `basinHoldingCounts`, `parcelsForHolding` | `ParcelQueryService` | domain | Kept, extracted |
| `bulkApplyField` | `BulkEditService` | domain | Kept, extracted |
| *(new)* remote fetch | `SupabaseHoldingsDataSource` | data | New |
| *(new)* offline queue | `SyncOutbox` | data | New |

`HoldingsRepository` survives as a **thin coordinator** implementing the domain interfaces —
target **under 120 lines**.

Two UI files also delete cleanly: `association_name_sheet.dart` and `history_screen.dart` /
`history_tile.dart` / `cached_file_entry.dart` go with the flows they served.

### 5.2 Existing assets to reuse, not rebuild

The `core/` layer is in better shape than the feature layer and already anticipates Supabase:

- **`core/errors/`** is essentially ready — `ErrorHandler`, `SupabaseHandler` (handles
  `AuthException`/`PostgrestException`/`StorageException`), a full `AppException` taxonomy, and a
  matching `Failure` hierarchy. This is exactly the `Result<T, Failure>` foundation § 3.3 calls for;
  **wire it up rather than writing a new one.** Two cleanups while you're there: delete
  `handlers/firebase_handler.dart` and the dead `// Future: FirebaseHandler` comment, and fix
  `_toFailure`, which returns `NotFoundException` where it means `NotFoundFailure`.
- **`core/networking/network_info.dart`** already wraps `internet_connection_checker` — that's the
  sync outbox's flush trigger, no new dependency needed.
- **`core/themes/`**, `core/router/`, `core/settings/` (font/theme switching), and the shared dialog
  widgets carry over untouched.

### 5.3 Things that must change (not just move)

1. **`Parcel.id` stops being the list index.** `_finalizeLoad` currently assigns
   `id: i.toString()`. It becomes the server `uuid` (or a client-generated `uuid v4` for records
   created offline). Every edit keyed by that id — this is a **correctness prerequisite** for sync.
2. **Stop mutating `_parcels` in place.** `updateParcel`/`bulkApplyField` write into the list
   directly, which is why `HomeCubit.refreshData()` had to exist. Replace with immutable
   replacement + a stream/emit, and `refreshData()` can go.
3. **`SharedPreferences` goes behind a `KeyValueStore` interface** (one implementation, injected).
   ~8 inline `getInstance()` calls disappear.
4. **`_formatForClipboard` moves out of `ParcelDetailCard`** into
   `domain/services/clipboard_formatter.dart`. The وراثة/مفوض prefix rules are real business logic
   with three interacting states — they deserve unit tests, and cannot have them inside a widget.
5. **`HomeCubit` splits.** It currently drives loading, search, basin filtering, and refresh. Split
   into `SessionCubit` (auth), `CityCubit` (selection/download/staleness), and `SearchCubit`
   (query/filter/results). Each gets its own small state class.
6. **DI gets modules** — `registerCoreModule()`, `registerHoldingsModule()`,
   `registerSyncModule()` — instead of one flat function that will keep growing.

### 5.4 Target structure

```text
lib/
├── core/                          # unchanged in spirit; cleaned up
│   ├── di/  (modular)  errors/  network/  router/  theme/  utils/  widgets/
│   └── storage/key_value_store.dart          # NEW — the only SharedPreferences user
│
├── features/
│   ├── auth/
│   │   ├── domain/    entities/app_user.dart, repositories/auth_repository.dart,
│   │   │              usecases/{sign_in,sign_out,watch_session}.dart
│   │   ├── data/      supabase_auth_repository.dart, models/app_user_model.dart
│   │   └── presentation/  cubit/session_cubit.dart, screens/login_screen.dart
│   │
│   ├── cities/
│   │   ├── domain/    entities/city.dart, repositories/city_repository.dart,
│   │   │              usecases/{list_cities,download_city,check_staleness}.dart
│   │   ├── data/      supabase_city_data_source.dart, city_snapshot_cache.dart
│   │   └── presentation/  cubit/city_cubit.dart, screens/city_picker_screen.dart
│   │
│   ├── holdings/
│   │   ├── domain/
│   │   │   ├── entities/parcel.dart              # pure — no json, no flutter
│   │   │   ├── repositories/{holdings_reader,holdings_writer}.dart
│   │   │   ├── services/{parcel_query_service,parcel_edit_overlay,
│   │   │   │             bulk_edit_service,clipboard_formatter,
│   │   │   │             area_calculator,arabic_normalizer,
│   │   │   │             holding_search_service}.dart
│   │   │   └── usecases/{search_holdings,update_parcel,bulk_apply_field,
│   │   │                 add_person,add_parcel_for_person}.dart
│   │   ├── data/      models/parcel_model.dart (json), holdings_repository_impl.dart,
│   │   │              supabase_holdings_data_source.dart
│   │   └── presentation/  cubit/search_cubit.dart, screens/…, widgets/…   # mostly unchanged
│   │
│   ├── sync/
│   │   ├── domain/    entities/sync_operation.dart (sealed), repositories/sync_queue.dart
│   │   ├── data/      sync_outbox_impl.dart, sync_runner.dart
│   │   └── presentation/  widgets/sync_status_badge.dart
│   │
│   └── about/                      # unchanged
└── main_{dev,prod}.dart
```

**Widgets that do not change at all** (they take a `Parcel` and render it): `ParcelDetailCard`,
`FieldRow`, `ToggleFieldRow`, `SeeMoreSection`, `CopyAllButton`, `BorderCompass`,
`RecommendationList/Tile`, `basin_filter_sheet`, `choice_dialog`, `text_input_dialog`,
`crop_type_picker`, `FileStatusScreen`. **This is the payoff of the current widget decomposition —
roughly 20 UI files survive the migration untouched.**

---

## 6. Database schema (canonical)

Apply via the Supabase MCP as numbered migrations. **`DASHBOARD_PLAN.md` depends on this exactly.**

```sql
-- ============ 001_enums.sql ============
create type user_role     as enum ('admin', 'editor', 'viewer', 'field');
create type city_status   as enum ('draft', 'published', 'archived');
create type record_status as enum ('pending', 'approved', 'rejected');

-- ============ 002_profiles.sql ============
create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  email        text not null,
  role         user_role not null default 'field',
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

-- Auto-create a profile whenever a user signs up.
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, display_name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', new.email), new.email);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users for each row execute function handle_new_user();

-- ============ 003_cities.sql ============
create table cities (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,                    -- اسم الجمعية / القرية
  directorate text,                             -- المديرية
  administration text,                          -- الإدارة
  status      city_status not null default 'draft',
  data_version bigint not null default 1,       -- bumped on any data change; app compares this
  created_by  uuid references profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index cities_name_unique on cities (lower(name));

-- ============ 004_import_batches.sql ============
create table import_batches (
  id            uuid primary key default gen_random_uuid(),
  city_id       uuid not null references cities(id) on delete restrict,
  file_name     text not null,
  storage_path  text,
  status        text not null default 'pending',
  rows_total    int not null default 0,
  rows_imported int not null default 0,
  rows_rejected int not null default 0,
  rejection_log jsonb,
  mapping_used  jsonb,
  imported_by   uuid not null references profiles(id),
  created_at    timestamptz not null default now(),
  committed_at  timestamptz
);

-- ============ 005_holdings.sql ============
-- Authoritative Excel import. IMMUTABLE from the app's perspective.
create table holdings (
  id                uuid primary key default gen_random_uuid(),
  city_id           uuid not null references cities(id) on delete restrict,
  import_batch_id   uuid references import_batches(id) on delete set null,

  holding_id_number text,              -- A  رقم الحيازة   (not unique!)
  unified_number    text,              -- T  الرقم الموحد للحيازة
  holder_name       text,              -- B
  national_id       text,              -- C
  land_number       text,              -- D  (numeric in source → text here)
  page_number       text,              -- M  (numeric in source → text here)
  basin_name        text,              -- O
  basin_code        text default '-1', -- N  (numeric/blank in source → text here)
  association_name  text,              -- P
  administration    text,              -- Q
  directorate       text,              -- R
  border_east       text,              -- I
  border_west       text,              -- J
  border_south      text,              -- K
  border_north      text,              -- L
  feddan            int not null default 0,   -- E
  qirat             int not null default 0,   -- F
  sahm              int not null default 0,   -- G
  total_sqm         numeric(12,2),            -- H

  is_stale          boolean not null default false,  -- absent from the latest import
  imported_at       timestamptz not null default now()
);

create index holdings_city_idx        on holdings (city_id);
create index holdings_holding_id_idx  on holdings (city_id, holding_id_number);
create index holdings_basin_idx       on holdings (city_id, basin_name);
create index holdings_holder_trgm     on holdings using gin (holder_name gin_trgm_ops);
create unique index holdings_unified_unique
  on holdings (city_id, unified_number) where unified_number is not null;

-- ============ 006_holding_edits.sql ============
-- Append-only correction overlay. Mirrors the app's existing edit-snapshot model.
create table holding_edits (
  id               uuid primary key default gen_random_uuid(),
  holding_id       uuid not null references holdings(id) on delete cascade,
  city_id          uuid not null references cities(id) on delete cascade,
  payload          jsonb not null,        -- Parcel.toEditableJson() shape
  edited_by        uuid not null references profiles(id),
  edited_at        timestamptz not null default now(),
  client_edited_at timestamptz,           -- device clock; drives last-write-wins
  device_id        text
);
create index holding_edits_holding_idx on holding_edits (holding_id, edited_at desc);
create index holding_edits_city_idx    on holding_edits (city_id, edited_at desc);

-- Latest edit per holding — what the app downloads.
create view holding_edits_latest as
select distinct on (holding_id) * from holding_edits
order by holding_id, coalesce(client_edited_at, edited_at) desc;

-- ============ 007_added_holdings.sql ============
-- Records created in the field. Same shape as holdings + provenance + review status.
create table added_holdings (
  id                uuid primary key default gen_random_uuid(),
  city_id           uuid not null references cities(id) on delete cascade,
  client_id         uuid not null,          -- generated offline; makes sync idempotent
  parent_holding_id uuid references holdings(id) on delete set null,  -- set for "add parcel to person"

  holding_id_number text,                   -- null for a brand-new person
  unified_number    text,
  holder_name       text not null,
  owner_name        text,
  national_id       text,
  land_number       text default '-1',
  page_number       text,
  basin_name        text,
  basin_code        text default '-1',
  association_name  text,
  administration    text,
  directorate       text,
  border_east       text, border_west text, border_south text, border_north text,
  feddan            int not null default 0,
  qirat             int not null default 0,
  sahm              int not null default 0,
  total_sqm         numeric(12,2),
  crop_type         text,
  notes             text,
  credit_type       text not null default 'ملك',
  usage_type        text not null default 'زراعة',
  is_inheritance    boolean not null default false,
  is_delegate       boolean not null default false,

  status              record_status not null default 'pending',
  rejection_reason    text,
  promoted_holding_id uuid references holdings(id) on delete set null,
  created_by          uuid not null references profiles(id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create unique index added_holdings_client_id_unique on added_holdings (client_id);
create index added_holdings_review_idx on added_holdings (city_id, status, created_at desc);

-- ============ 008_triggers.sql ============
-- Any data change bumps the city's data_version, which is the app's staleness signal.
create function bump_city_version() returns trigger
language plpgsql as $$
begin
  update cities set data_version = data_version + 1, updated_at = now()
  where id = coalesce(new.city_id, old.city_id);
  return coalesce(new, old);
end $$;

create trigger holdings_bump       after insert or update or delete on holdings
  for each statement execute function bump_city_version();
create trigger holding_edits_bump  after insert on holding_edits
  for each row execute function bump_city_version();
create trigger added_holdings_bump after insert or update on added_holdings
  for each row execute function bump_city_version();
```

> **Note on `holdings_bump`:** it is `for each statement`, deliberately — a 1,202-row import must
> bump the version once, not 1,202 times. **Correction applied in the actual migration files**
> (`supabase/migrations/`): a statement-level trigger has no `NEW`/`OLD` record to read, so
> `bump_city_version()` as written above only works for the two `for each row` triggers.
> `holdings_bump` uses a separate `bump_city_version_statement()` function that reads affected
> `city_id`s from `REFERENCING OLD TABLE/NEW TABLE` transition tables instead — see the migration
> files for the corrected version.

### 6.1 Row Level Security

**Every table gets RLS. The UI hiding a button is not security.**

```sql
alter table profiles       enable row level security;
alter table cities         enable row level security;
alter table holdings       enable row level security;
alter table holding_edits  enable row level security;
alter table added_holdings enable row level security;
alter table import_batches enable row level security;

create function current_role_is(roles user_role[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and is_active and role = any(roles)
  );
$$;

-- profiles: read own; admins read/write all
create policy profiles_self_read on profiles for select
  using (id = auth.uid() or current_role_is(array['admin','editor','viewer']::user_role[]));
create policy profiles_admin_write on profiles for all
  using (current_role_is(array['admin']::user_role[]))
  with check (current_role_is(array['admin']::user_role[]));

-- cities: field users see published only; staff see all
create policy cities_read on cities for select using (
  status = 'published'
  or current_role_is(array['admin','editor','viewer']::user_role[])
);
create policy cities_write on cities for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));

-- holdings: everyone authenticated reads published cities; only staff write
create policy holdings_read on holdings for select using (
  exists (select 1 from cities c where c.id = city_id and (
    c.status = 'published'
    or current_role_is(array['admin','editor','viewer']::user_role[])))
);
create policy holdings_write on holdings for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));

-- holding_edits: any active user may append; nobody may update or delete (append-only)
create policy holding_edits_read on holding_edits for select using (auth.uid() is not null);
create policy holding_edits_insert on holding_edits for insert
  with check (edited_by = auth.uid());

-- added_holdings: field users insert/update their own pending rows; staff manage all
create policy added_holdings_read on added_holdings for select using (auth.uid() is not null);
create policy added_holdings_insert on added_holdings for insert
  with check (created_by = auth.uid());
create policy added_holdings_update_own on added_holdings for update
  using (created_by = auth.uid() and status = 'pending');
create policy added_holdings_staff on added_holdings for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));

create policy import_batches_staff on import_batches for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));
```

**Deliberate consequences worth understanding:** `holding_edits` has no update/delete policy, so it
is append-only *by construction* — the audit trail cannot be rewritten. `field` users can't see
draft cities, so a half-imported city can never reach the field team.

### 6.2 رقم الحيازة for app-added records

رقم الحيازة is government-assigned; the app has no authority to invent one. For a **brand-new
person**, leave `holding_id_number` null and display `بدون رقم — جديد` until the dashboard assigns
one at approval. For **a new parcel for an existing person**, copy their existing number — the
person is already official, only the parcel is new.

---

## 7. New features

### 7.1 Login
Supabase Auth email/password, session persisted by `supabase_flutter`. `SessionCubit` exposes
`authenticated`/`unauthenticated`; the router redirects on that. Arabic error messages for the
common failures (wrong password, no network, disabled account).

### 7.2 City picker & download
Lists `published` cities. Selecting one downloads `holdings` + `holding_edits_latest` +
approved `added_holdings` for that city, merges them into `Parcel`s, and writes a **local snapshot**
(JSON file via `path_provider`, not `SharedPreferences` — a 1,200-row city is too big for prefs).
Shows progress; must be resumable/retryable on a flaky connection.

### 7.3 Staleness check
On app open, fetch `cities.data_version` for the active city and compare with the snapshot's stored
version. If the server is ahead, show a non-blocking banner with a "تحديث البيانات" action. **Never
auto-download on a metered connection without asking** — field users are on mobile data.

### 7.4 Add new person (search found nothing)
Triggered from the no-results state: `لا يوجد نتائج → إضافة بيانات جديدة`. Uses the same field set
as the detail card, `Parcel`'s existing defaults (نوع الائتمان=ملك، نوع الاستخدام=زراعة،
وراثة/مفوض=false، كود الحوض=`-1`), `holding_id_number` null. Saves to the local snapshot immediately
(usable offline) and enqueues an `AddRecord` sync operation.

### 7.5 Add parcel for existing person
From the detail screen: `إضافة قطعة أرض جديدة لنفس الشخص`. Pre-filled per decision #8, with
`parent_holding_id` set so the dashboard can see the link. Same save/enqueue path.

### 7.6 Sync status (new, small, important)
A badge in the top bar showing pending-operation count, last-sync time, and a manual "مزامنة الآن".
Without visible sync state, users can't tell whether their work is safe — this is not optional
polish.

---

## 8. Offline sync

```dart
sealed class SyncOperation {
  final String id;            // client-generated uuid → idempotency key
  final DateTime createdAt;
  final int attempts;
}
final class EditHolding    extends SyncOperation { ... }  // → holding_edits insert
final class AddRecord      extends SyncOperation { ... }  // → added_holdings upsert on client_id
final class BulkEditRecords extends SyncOperation { ... } // → batched holding_edits insert
```

- **Storage:** local JSON file (same store as the snapshot). SQLite only if the queue ever needs
  querying — it doesn't yet, so don't add the dependency.
- **Idempotency:** every operation carries a client uuid; `added_holdings.client_id` is unique, so a
  retry after a timeout can never create a duplicate. This is the single most important sync detail.
- **Flush triggers:** connectivity regained (`internet_connection_checker` is already a dependency),
  app resume, manual action. Sequential, in order, with exponential backoff.
- **Failure handling:** an operation failing 5× is parked as "failed" and surfaced in the UI rather
  than retried forever or silently dropped. Silent data loss is the worst outcome here.
- **Writes are local-first**: the use case writes the snapshot **and** enqueues, then returns. The UI
  never waits on the network.

---

## 9. Phases

**Each phase ends at a gate: `flutter analyze` clean, `flutter test` green, the phase's stated
manual check performed, and the app still runs. Do not start the next phase until the gate is
green.**

> ⚠️ **Standing instruction: do not run `flutter build windows` / `flutter build apk` or any
> platform build unless explicitly asked.** Verification is `flutter analyze` + `flutter test`.

### Phase 0 — Refactor (no behavior change, no backend)
Remove Firebase deps + pin versions (§ 3.4). Introduce `core/storage/key_value_store.dart`. Create
the `domain/data/presentation` folders. Extract `ParcelQueryService`, `ParcelEditOverlay`,
`BulkEditService`, `ClipboardFormatter` out of the repository and the detail card. Define the
repository interfaces. Modularize DI. Split `HomeCubit`.

> **Gate:** the app behaves **identically** to today — same search results, same copy-all output,
> same bulk edit. New unit tests for the four extracted services, including the وراثة/مفوض prefix
> matrix (all four combinations) and the copy-all line grouping, all green.

### Phase 1 — Supabase schema
Apply migrations 001–008 + RLS via the MCP. Seed: one admin, one field user, one city, and the real
`الدير_ائتمان_مجمع.xlsx` data (import it manually/by script for now — the dashboard importer comes
later).

> **Gate:** RLS verified by hand — a `field` user can read published holdings, cannot read a draft
> city, cannot update `holdings`, cannot delete a `holding_edits` row.

### Phase 2 — Auth + city download
`supabase_flutter` init, login screen, `SessionCubit`, router guard, city picker, snapshot download
+ local cache, staleness banner.

> **Gate:** log in, pick the seeded city, download it, kill the network, restart the app — full
> search/detail/bulk-edit works offline from the snapshot.

### Phase 3 — Sync up existing edits ⭐ the priority feature
`SyncOutbox` + `SyncRunner` + sync-status badge. Point the existing edit flow at the outbox.

> **Gate:** edit a field offline → badge shows 1 pending → reconnect → it flushes → a
> `holding_edits` row exists in Supabase with the right `edited_by` → re-download on another device
> shows the correction. Kill the app mid-flush and confirm **no duplicate rows** (idempotency).

### Phase 4 — Add new person / add parcel
Both add flows (§ 7.4, § 7.5) with the shared form, plus `AddRecord` sync operations.

> **Gate:** create a person offline, create a second parcel for an existing person, sync both,
> verify `added_holdings` rows with the correct `parent_holding_id`, null vs. copied
> `holding_id_number`, and correct `client_id` idempotency on a forced retry.

### Phase 5 — Retire the Excel path
Delete `holdings_excel_parser.dart`, `file_picker`/`spreadsheet_decoder` deps, history screens,
`cached_file_entry.dart`, `association_name_sheet.dart`, and the file-status screen's
association-editing section (association now comes from the server).

> **Gate:** no reference to `file_picker` or `spreadsheet_decoder` remains; app is smaller; every
> flow still works.

### Phase 6 — Hardening
Failed-operation UI, conflict surfacing, metered-connection handling, Arabic error messages
everywhere, empty/error state audit, widget tests on the detail card, accessibility pass.

> **Gate:** full test suite green; a deliberate 24-hour offline session with 20 queued operations
> syncs cleanly on reconnect.

---

## 10. Testing strategy

| Layer | What's tested | Target |
|---|---|---|
| `domain/services/` | Search ranking & Arabic normalization, area math, **clipboard formatting incl. the وراثة/مفوض matrix**, bulk-edit application, edit-overlay merge | **≥ 90%** — pure functions, no excuse |
| `domain/usecases/` | Orchestration + failure paths, against fake repositories | Every use case |
| `data/` | JSON ↔ entity mapping (esp. numeric→text coercions from § 4), outbox persistence/idempotency | Every model + the outbox |
| Cubits | State transitions incl. error and offline states | Every cubit |
| Widgets | The detail card renders/edits correctly; the 4 UI states | Complex widgets only |
| RLS | Each role × table × operation | **Every policy** |

**Fakes over mocks.** `FakeHoldingsRepository` implementing the domain interface beats a
`mockito` mock — that's what the interfaces are for. Keep `mockito` only for platform channels.

**Fixtures:** commit a trimmed JSON snapshot derived from the real sample city, so tests run against
realistic Arabic data (RTL text, `ة`/`ه` variants, empty `basin_code`, zero-area rows).

---

## 11. Conventions & definition of done

**A feature is done when:**

1. `flutter analyze` clean — zero warnings, no `// ignore:` without a justifying comment.
2. Domain logic unit-tested; the flow works offline **and** online.
3. Layer boundaries respected — `presentation/` imports nothing from `data/`; `domain/` imports no
   Flutter/Supabase.
4. No file over 300 lines, no method over 40.
5. Loading / empty / error / loaded states all handled, in Arabic.
6. Works in both light and dark theme, RTL correct.
7. Anything writing to the server goes through the outbox — no direct network call from a cubit.
8. RLS policy exists and was tested for the tables touched.

**Commits:** Conventional Commits, kept **small and single-purpose** — one logical change per
commit (e.g. "remove unused Firebase deps" and "extract ParcelQueryService" are two commits, not
one). Never bundle an unrelated fix into a refactor commit just because it was touched in the same
session; split them even if it means committing more often. **Branching:** one branch per phase.

---

## 12. Still open

- Whether every city's Excel matches the 20-column layout in § 4 (the dashboard's mapping registry
  absorbs variation; the importer must fail loudly on surprises).
- Default template for "add new person" when there's nothing to copy from — currently `Parcel`'s
  constructor defaults; sanity-check against real field workflow once observed.
- Whether `editor`/`viewer` need per-city scoping later — schema leaves room for a `user_cities`
  join table.
- Whether the app should ever *edit* an `added_holdings` record after approval, or treat it as
  promoted-and-frozen. Current assumption: once promoted to `holdings`, edits go through
  `holding_edits` like any other record.
