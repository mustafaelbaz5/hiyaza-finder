# HiyazaFinder — Admin Dashboard Plan (Implementation-Ready)

> **Companion to `APP_PLAN.md`.** This is a **separate web project** (its own repo, its own
> deployment), built against the **same Supabase backend**. The canonical database schema, RLS
> policies, and enums live in `APP_PLAN.md` § "Database schema" — **read that first and treat it as
> the source of truth**. This document never redefines a table; it only says how the dashboard uses
> it and which *dashboard-only* tables it adds.
>
> **Build order:** the Flutter app (`APP_PLAN.md`) phases 0–3 ship first, so the schema is stable
> before dashboard work starts. See § "Phases".

---

## 1. Purpose & scope

The dashboard is the **control plane** for the entire HiyazaFinder system. The Flutter app is a
read-mostly field tool; everything authoritative happens here.

**In scope:**

| Capability | Why it exists |
|---|---|
| Admin authentication + roles | Only staff touch authoritative data |
| City (جمعية) lifecycle management | Cities are the unit everything is scoped to |
| Excel import pipeline | The only way authoritative data enters the system |
| Data explorer + correction | Fix bad rows without re-uploading a whole file |
| Review queue for app-added records | See and approve what the field team created |
| Audit trail | Answer "who changed this, and when" |
| Analytics & control center | Understand data quality, coverage, and team activity |
| User management | Create/disable field accounts, assign roles |

**Out of scope (explicitly):** anything the mobile app does in the field (search, copy-all
formatting, offline caching). The dashboard never duplicates field workflows.

---

## 2. Tech stack

Chosen for: strong typing end-to-end, first-class Supabase support, a mature component library that
gets a professional light/dark UI without designing one from scratch, and RTL/Arabic support.

| Concern | Choice | Why this one |
|---|---|---|
| Framework | **Next.js 15 (App Router) + React 19** | Server Components let heavy queries and the Excel parser run on the server, never shipping to the browser. Route Handlers give us a proper backend for the import pipeline without a second service. |
| Language | **TypeScript (strict mode)** | Non-negotiable — the schema types are generated from Supabase, so a column rename becomes a compile error, not a runtime surprise. |
| Styling | **Tailwind CSS v4** | Utility-first, no CSS file sprawl, excellent RTL support via logical properties (`ps-*`/`pe-*` instead of `pl-*`/`pr-*`). |
| Components | **shadcn/ui** (Radix primitives) | Components are copied into the repo, not imported from a black box — we own and can restyle them. Accessible by default, themable via CSS variables, which is what makes light/dark trivial. |
| Theming | **next-themes** | `class`-based dark mode, no flash-of-wrong-theme, respects OS preference with a manual override. |
| Server state | **TanStack Query v5** | Caching, background refetch, optimistic updates, request dedup. Do **not** hand-roll `useEffect` fetching. |
| Tables | **TanStack Table v8** | Headless — sorting/filtering/pagination logic separate from rendering. Essential: some cities have thousands of rows. |
| Forms | **react-hook-form + Zod** | One Zod schema per entity, reused for client validation, server validation, and TS type inference. Single source of truth. |
| Charts | **Recharts** | Composable React charts, themeable from the same CSS variables as the rest of the UI. |
| Excel parsing | **SheetJS (`xlsx`)**, **server-side only** | Runs in a Route Handler / Server Action. Never parse a 5MB workbook in the user's browser. |
| Backend | **Supabase JS v2** + **`@supabase/ssr`** | `@supabase/ssr` is the only correct way to do Supabase auth in the App Router (cookie-based sessions that work in Server Components and middleware). |
| Unit/integration tests | **Vitest + React Testing Library** | Fast, native ESM, same API surface as Jest. |
| E2E tests | **Playwright** | Each phase's gate is an E2E test that proves the phase works end-to-end. |
| Linting | **ESLint (typescript-eslint strict) + Prettier** | Enforced in CI, not optional. |
| Hosting | **Vercel** | Zero-config for Next.js; preview deploys per PR make the phase gates reviewable. |

**Locale:** the dashboard UI is **Arabic, RTL** (`<html lang="ar" dir="rtl">`). Use the same
`Tajawal` font as the mobile app for visual continuity. Numbers stay Western-Arabic (`0-9`) to match
what the app copies. All Tailwind spacing uses **logical properties** so nothing breaks if an LTR
locale is ever added.

---

## 3. Architecture principles

### 3.1 SOLID, translated to React/TypeScript

These aren't decorative — each maps to a concrete rule the reviewer can check:

- **Single Responsibility** — a file has one reason to change.
  - `app/**/page.tsx` files **only compose**: fetch data, render a feature component. No business
    logic, no inline Supabase queries, no more than ~40 lines.
  - A component either **fetches** or **renders**, never both. Container/presentational split.
  - The import pipeline is not one function: `readWorkbook` → `locateHeaderRow` → `mapRows` →
    `validateRows` → `persistBatch` are five separately testable units.

- **Open/Closed** — extend without editing.
  - The **column mapping is data, not code**. A city's Excel layout is a `ColumnMapping` object
    (`{ holdingIdNumber: 'رقم الحيازة', holderName: 'اسم الحائز', ... }`) registered in a
    `mappingRegistry`. A new file layout = a new mapping entry, **zero changes to the parser**.
  - Analytics widgets implement a common `MetricDefinition` interface and are registered in an
    array. Adding a metric never touches the dashboard page.

- **Liskov Substitution** — every data-access module is defined by an **interface first**
  (`HoldingsRepository`, `CityRepository`, `AuditRepository`). `SupabaseHoldingsRepository` and
  `InMemoryHoldingsRepository` (used in tests) are freely interchangeable. If a test needs to mock
  `fetch`, the abstraction is wrong.

- **Interface Segregation** — no component receives an object bigger than it uses. A
  `<HoldingRow>` takes the ~6 fields it renders, not the whole 20-column row. Hooks are narrow:
  `useCityList()`, not `useEverything()`.

- **Dependency Inversion** — features depend on **interfaces**, the Supabase client is injected.
  - **Hard rule: `createClient()` is called in exactly two files** (`lib/supabase/server.ts`,
    `lib/supabase/client.ts`). Everywhere else receives a repository. This is what makes the whole
    app testable without a live database.

### 3.2 Clean-code rules (enforced, not aspirational)

1. **No `any`.** `strict: true`, `noUncheckedIndexedAccess: true`. Types for DB rows are
   **generated** (`supabase gen types typescript`) and committed — never hand-written.
2. **Zod at every boundary.** Anything crossing a trust boundary (form input, uploaded file, URL
   search params, API response) is parsed by a Zod schema before use.
3. **Errors are values.** Data-access functions return `Result<T, AppError>`, they don't throw.
   Only React error boundaries deal with thrown errors.
4. **No magic strings.** Table names, storage buckets, role names, and query keys live in
   `lib/constants.ts` and `lib/query-keys.ts`.
5. **Function length ≤ 40 lines, file length ≤ 250 lines.** Past that, split. Enforced by ESLint.
6. **Every exported function has a JSDoc line** saying *why* it exists, not what it does.
7. **Colocate tests**: `foo.ts` → `foo.test.ts` beside it.

---

## 4. Project structure

Feature-first, not type-first. Everything about "import" lives under `features/import/` — you never
hunt across five top-level folders to change one feature.

```text
hiyaza-dashboard/
├── src/
│   ├── app/                          # Next.js routes — THIN, composition only
│   │   ├── layout.tsx                # <html dir="rtl">, ThemeProvider, QueryProvider
│   │   ├── (auth)/
│   │   │   └── login/page.tsx
│   │   └── (dashboard)/              # auth-guarded group
│   │       ├── layout.tsx            # sidebar + topbar shell
│   │       ├── page.tsx              # overview / analytics home
│   │       ├── cities/
│   │       │   ├── page.tsx
│   │       │   └── [cityId]/
│   │       │       ├── page.tsx      # city detail
│   │       │       ├── holdings/page.tsx
│   │       │       ├── import/page.tsx
│   │       │       └── quality/page.tsx
│   │       ├── review/page.tsx
│   │       ├── audit/page.tsx
│   │       ├── analytics/page.tsx
│   │       ├── users/page.tsx
│   │       └── settings/page.tsx
│   │
│   ├── features/                     # ← the real code lives here
│   │   ├── auth/
│   │   │   ├── api/                  # repository impls
│   │   │   ├── components/
│   │   │   ├── hooks/
│   │   │   ├── schemas/              # zod
│   │   │   └── types.ts
│   │   ├── cities/
│   │   ├── import/
│   │   │   ├── api/
│   │   │   ├── components/
│   │   │   ├── core/                 # PURE logic — no React, no Supabase
│   │   │   │   ├── locate-header-row.ts
│   │   │   │   ├── column-mapping.ts       # ColumnMapping type + registry
│   │   │   │   ├── map-rows.ts
│   │   │   │   ├── validate-rows.ts
│   │   │   │   └── *.test.ts               # 100% covered — this is the risky part
│   │   │   └── hooks/
│   │   ├── holdings/
│   │   ├── review/
│   │   ├── audit/
│   │   ├── analytics/
│   │   │   ├── metrics/              # one file per MetricDefinition
│   │   │   ├── components/
│   │   │   └── registry.ts
│   │   └── users/
│   │
│   ├── components/
│   │   ├── ui/                       # shadcn primitives (generated)
│   │   └── shared/                   # DataTable, PageHeader, EmptyState, StatCard…
│   │
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── server.ts             # ONE of two createClient call sites
│   │   │   ├── client.ts             # the other
│   │   │   ├── middleware.ts         # session refresh
│   │   │   └── database.types.ts     # GENERATED — do not edit
│   │   ├── result.ts                 # Result<T, E>
│   │   ├── errors.ts                 # AppError taxonomy
│   │   ├── query-keys.ts
│   │   └── constants.ts
│   │
│   ├── server/                       # server-only utilities (import runner, exports)
│   └── styles/globals.css            # CSS variables: light + dark palettes
│
├── supabase/migrations/              # SQL migrations (shared convention with the app)
├── e2e/                              # Playwright specs, one per phase gate
└── ...config files
```

**Dependency direction (never violated):**

```text
app/ ──▶ features/ ──▶ lib/
              │
              └──▶ features/*/core/   (pure, depends on nothing)
```

`lib/` never imports from `features/`. `features/*/core/` imports **nothing** — that's what makes it
trivially unit-testable.

---

## 5. UI/UX design system

The dashboard must look professional out of the box and support light + dark.

### 5.1 Theming

- Colors defined **once** as CSS variables in `globals.css`, in both `:root` and `.dark` blocks
  (shadcn's convention: `--background`, `--foreground`, `--primary`, `--muted`, `--destructive`,
  `--border`, …). Every component consumes `bg-background`, `text-foreground` — **never a hardcoded
  hex or a `dark:` variant on a color**. This means the entire theme is one file.
- `next-themes` with `attribute="class"`, `defaultTheme="system"`, `enableSystem`, and
  `disableTransitionOnChange`. Theme toggle in the topbar cycling light → dark → system.
- Pull the accent color from the mobile app's `AppColors` so both products feel like one system.

### 5.2 Layout

- **Persistent right-side sidebar** (RTL) with sections: نظرة عامة، المدن، المراجعة، سجل النشاط،
  التحليلات، المستخدمون، الإعدادات. Collapsible to icons.
- **Topbar**: current city selector (a global scope switcher — most pages are city-scoped), global
  search, theme toggle, user menu.
- **Content**: `PageHeader` (title + description + primary action) then content. Consistent on
  every page — build it once as a shared component.

### 5.3 Non-negotiable UI states

Every data view implements **four** states — a missing state is a bug, not a polish item:

1. **Loading** — skeletons matching the final layout (not a centered spinner).
2. **Empty** — icon + explanation + the action that fixes it ("لا توجد بيانات — ارفع ملف Excel").
3. **Error** — what failed + a retry button.
4. **Loaded**.

### 5.4 Data table baseline

One shared `<DataTable>` built on TanStack Table, used by holdings/review/audit alike:
server-side pagination (never fetch 10k rows), column sort, per-column filters, column
show/hide, row selection with a bulk-action bar, sticky header, CSV/Excel export, and a URL-synced
state so a filtered view is shareable by link.

---

## 6. Feature specifications

### 6.1 Auth & roles

- Supabase Auth, email/password. `@supabase/ssr` cookie sessions.
- **Next.js middleware** guards `(dashboard)/*` — unauthenticated → `/login`. Middleware refreshes
  the session on every request; without this, sessions silently expire in Server Components.
- Roles on `profiles.role`, enum: `admin` | `editor` | `viewer` | `field` (see `APP_PLAN.md`).
  - `admin` — everything, including user management and destructive actions.
  - `editor` — import, correct data, review the queue. No user management.
  - `viewer` — read-only, including analytics. Useful for stakeholders.
  - `field` — the **mobile app** role. Cannot log into the dashboard at all.
- **Authorization is enforced by RLS in Postgres, not by hiding buttons.** The UI hides what a role
  can't do as a courtesy; the database is what actually stops it. Every role gate needs both.

### 6.2 City management

- List cities with: name, governorate/directorate, holdings count, last import date, data-quality
  score, status badge.
- Create/edit a city; **archive** (soft) rather than delete — deleting a city with holdings must be
  impossible.
- **City status**: `draft` (invisible to the app) → `published` (app can download) → `archived`.
  This is important: it stops a half-imported city from reaching the field team.
- City detail page = tabbed: Overview · Holdings · Imports · Quality · Activity.

### 6.3 Excel import pipeline

The highest-risk feature — treat it accordingly. Confirmed against the real sample file
`الدير_ائتمان_مجمع.xlsx`; see `APP_PLAN.md` § "Sample Excel structure" for the full 20-column
breakdown.

**Known facts about the source format:**

- **Only the `جميع البيانات` sheet is parsed.** The 7 basin-name sheets and the `بيانات ناقصة`
  sheet are redundant filtered views of the same rows — importing them would duplicate data. Skip
  them by name, and log which sheets were skipped in the import summary.
- **The header row is row 3**, not row 1 (rows 1–2 are metadata: sector label, association label).
  **Do not hardcode row 3** — `locateHeaderRow()` scans the first ~10 rows for the one containing
  the most known header labels. This is the OCP escape hatch for files that shift.
- Row 2 carries the association name, which is *also* on every data row in column P — prefer the
  per-row column, fall back to row 2.
- `land_number`, `page_number`, `basin_code` arrive as **numeric** cells and must be coerced to
  text (the app displays and copies them as strings).
- Column S (`عدد القطع بالحيازة`) is a precomputed per-holding parcel count — **don't store it**,
  it's derivable. **Do** use it as a validation check: if the imported row count for a holding
  doesn't match, flag the batch.
- Column T (`الرقم الموحد للحيازة`) is a stable official identifier — import it as `unified_number`.

**Pipeline stages** (each a separately tested pure function in `features/import/core/`):

```text
upload → readWorkbook → locateHeaderRow → resolveMapping → mapRows
       → validateRows → previewSummary → [USER CONFIRMS] → persistBatch
```

**The preview step is mandatory.** Nothing is written to `holdings` until the user sees: rows
found, rows valid, rows rejected (with reasons, downloadable as CSV), columns matched/unmatched,
detected association name, detected basin list, and a **diff vs. the current data** (X new, Y
changed, Z rows in the DB not in this file). Blind imports are how a city's data gets silently
destroyed.

**Persistence** is one transaction writing an `import_batches` row plus the `holdings` rows, so a
failed import leaves nothing behind. Every `holdings` row carries its `import_batch_id`, which makes
**rollback** possible: revert a city to its previous batch. That safety net is worth the one extra
column.

**Re-import behavior:** upsert on `(city_id, unified_number)` — new rows inserted, existing rows
updated, rows absent from the new file marked `is_stale` rather than deleted (a field user may
have edits attached to them).

### 6.4 Data explorer & correction

- Full holdings table for a city, all 20 columns, with the shared `<DataTable>`.
- Inline edit → writes a `holding_edits` row (never mutates `holdings`), exactly like the app does.
  Same overlay mechanic on both sides means one mental model.
- **Bulk edit** mirroring the app's existing `bulkApplyField`: select rows (or filter to a basin) →
  apply a value to one field → confirm with an affected-count preview.
- Export current view to Excel/CSV.

### 6.5 Review queue

- Table over `added_holdings` (records the field team created) with `status`:
  `pending` | `approved` | `rejected`.
- Actions: approve (optionally assigning an official رقم الحيازة, which is null for app-added
  people — see `APP_PLAN.md`), edit-then-approve, reject with a reason.
- **Approving promotes the row into `holdings`** and marks the `added_holdings` row `approved` with
  a pointer to the created holding. This is the moment app-added data becomes authoritative.
- Since sync is last-write-wins, review is about **visibility and correction**, not gatekeeping —
  the app shows the record either way; approval is what makes it official.

### 6.6 Audit trail

- Unified chronological feed over `holding_edits` + `added_holdings` + `import_batches` + city/user
  changes, joined to `profiles` for human names.
- Filters: city, user, date range, action type, entity.
- Each entry expands to a **field-level diff** (before → after). This is the whole point — "who
  changed this" is useless without "from what, to what".
- Immutable: no edit, no delete, ever.

### 6.7 Analytics & control center

The user's explicit ask: *see analytics across all data and cities, and have the features needed to
control and see everything.* Split into four boards.

**Board 1 — System overview (all cities)**

| Metric | Answers |
|---|---|
| Total cities (by status) | How much of the governorate is onboarded? |
| Total holdings / parcels / distinct people | System size |
| Total area (فدان/قيراط/سهم + م²) under management | Scale in domain terms |
| Cities never imported / stale > 90 days | What needs attention now |
| System-wide data-quality score | Overall health |
| Active field users (7d / 30d) | Is the tool actually being used? |
| Pending reviews | Work waiting on an admin |

**Board 2 — Per-city drill-down**

Holdings & parcels count, basin breakdown (count + area per حوض), area distribution, completeness
per field, top holders by area, import history, edit activity, and app-added record counts.

**Board 3 — Data quality** *(this is the "empty/missing data" report, done properly)*

- **Completeness matrix**: every field × % populated, per city — one heatmap that instantly shows
  which city is missing what.
- **Rule-based issue detection**, each rule its own registered module (OCP):
  - Missing/zero national ID, or one failing the 14-digit Egyptian format check
  - Placeholder border values (`0`) — this is what the source file's `بيانات ناقصة` sheet flags
  - Zero or absent area across all of فدان/قيراط/سهم
  - `basin_code` empty (frequent in the sample)
  - Duplicate `unified_number` within a city
  - `total_sqm` inconsistent with فدان/قيراط/سهم (recompute and compare)
  - Parcel count mismatch vs. column S
- Cross-check against the source file's own `بيانات ناقصة` sheet where present, but **compute the
  rules live from `holdings`** so the report stays correct for files that lack that sheet.
- Every issue row links straight to the correction UI, and is exportable as a work list.

**Board 4 — Team activity**

Per-user: records added, edits made, cities touched, last-active, approval rate. Plus a timeline of
activity per city, and a leaderboard. This is what tells you whether the field team is working.

**Control features these boards require** (build them — the analytics are decoration without them):

1. City publish/unpublish — gate what reaches the app.
2. Import rollback to a previous batch.
3. Bulk correction from a quality work list.
4. User management: invite, disable, change role, force sign-out.
5. Data export per city (Excel/CSV), for backup and for handing data back to the authority.
6. Scheduled/manual **data-quality snapshot** written to a table, so trends over time are real
   history rather than a live number that only reflects today.
7. Notifications/badges for pending reviews and failed imports.

**Implementation note:** every metric is a Postgres **view** or RPC function, never client-side
aggregation over fetched rows. Start with plain views; promote to materialized views (refreshed
after each import) only when a board is measurably slow. Do not add an analytics service.

### 6.8 User management

Invite by email, assign role, disable/re-enable, view per-user activity, force password reset.
`admin` only, enforced by RLS.

---

## 7. Dashboard-only tables

Everything else is in `APP_PLAN.md`. These exist purely for the dashboard:

```sql
-- One row per Excel import. Makes rollback and import history possible.
create table import_batches (
  id             uuid primary key default gen_random_uuid(),
  city_id        uuid not null references cities(id) on delete restrict,
  file_name      text not null,
  storage_path   text,                       -- original file kept in Supabase Storage
  status         text not null default 'pending',   -- pending|previewing|committed|failed|rolled_back
  rows_total     int  not null default 0,
  rows_imported  int  not null default 0,
  rows_rejected  int  not null default 0,
  rejection_log  jsonb,                      -- [{row, column, reason}]
  mapping_used   jsonb,                      -- the ColumnMapping actually applied
  imported_by    uuid not null references profiles(id),
  created_at     timestamptz not null default now(),
  committed_at   timestamptz
);

-- Point-in-time data-quality snapshot, so quality trends are real history.
create table quality_snapshots (
  id           uuid primary key default gen_random_uuid(),
  city_id      uuid not null references cities(id) on delete cascade,
  captured_at  timestamptz not null default now(),
  overall_score numeric(5,2) not null,
  field_completeness jsonb not null,   -- {"national_id": 0.94, "basin_code": 0.11, ...}
  issue_counts jsonb not null          -- {"missing_national_id": 12, ...}
);
```

`holdings` gains `import_batch_id uuid references import_batches(id)` and
`is_stale boolean default false` — both defined in `APP_PLAN.md`'s canonical schema so the app and
dashboard agree.

---

## 8. Phases

**Each phase ends at a gate. The gate is not "it looks done" — it is: typecheck passes, lint passes,
unit tests pass, the phase's Playwright E2E spec passes, and the feature was manually walked
through. Do not start the next phase until the gate is green.**

### Phase 0 — Foundation
Next.js + TS strict + Tailwind + shadcn init. `globals.css` light/dark variables. RTL layout shell
(sidebar + topbar + theme toggle). Supabase clients (`server.ts`/`client.ts`) + middleware. Generated
`database.types.ts`. `Result`/`AppError`. Shared `DataTable`, `PageHeader`, `EmptyState`, `StatCard`.
ESLint/Prettier/Vitest/Playwright configured and running in CI.

> **Gate:** app builds, both themes render correctly with no layout breakage in RTL, CI is green on
> an empty test suite, and a placeholder page renders through the shell.

### Phase 1 — Auth & cities
Login page, middleware guard, `profiles` + role plumbing, sign-out. City CRUD, status lifecycle,
city detail shell, global city switcher.

> **Gate:** E2E — log in as `admin`, create a city, see it listed, log out, get redirected from a
> protected route. Plus: a `viewer` cannot reach the create-city action, **and** a direct API call
> as `viewer` is rejected by RLS.

### Phase 2 — Excel import ⚠️ highest risk
`features/import/core/` built pure and test-first against the real
`الدير_ائتمان_مجمع.xlsx` as a fixture. Upload UI, preview screen with the full summary + diff,
commit-in-a-transaction, `import_batches` history, rollback.

> **Gate:** E2E — upload the real sample file, preview reports **1,202 rows** from the
> `جميع البيانات` sheet (and reports the 8 other sheets as skipped), commit it, verify the row count
> in `holdings`, verify a spot-checked row matches the file exactly (Arabic text intact, no encoding
> damage, numerics coerced to text where required), then roll back and verify the city is empty.
> Unit coverage on `core/` ≥ 90%.

### Phase 3 — Data explorer & correction
Holdings table for a city (server-side pagination/sort/filter), inline edit → `holding_edits`, bulk
edit, export.

> **Gate:** E2E — filter to a basin, edit a field, confirm a `holding_edits` row was created and the
> `holdings` row was **not** mutated, confirm the merged value renders. Table stays responsive at
> 10k+ rows.

### Phase 4 — Review queue & audit trail
`added_holdings` queue with approve/edit/reject, promotion into `holdings`, unified audit feed with
field-level diffs and filters.

> **Gate:** E2E — seed an app-added record, approve it, verify it appears in `holdings` and the
> audit trail shows who/when/what with a correct before→after diff.

### Phase 5 — Analytics & control center
The four boards, all metrics as Postgres views/RPCs, the quality rule registry, quality snapshots,
and the seven control features from § 6.7.

> **Gate:** E2E — every board loads under 2s against a seeded multi-city dataset; the quality board's
> issue counts for the sample city are **verified by hand against the source file's `بيانات ناقصة`
> sheet**; publish/unpublish visibly changes what the app's city list returns.

### Phase 6 — User management & polish
Invite/disable/role changes, notifications for pending reviews and failed imports, accessibility
pass (keyboard nav, focus rings, contrast in both themes), responsive/tablet layout, empty/error
state audit across every page.

> **Gate:** full E2E suite green; axe accessibility scan clean on every route in both themes.

---

## 9. Testing strategy

| Layer | Tool | What's tested | Target |
|---|---|---|---|
| `features/*/core/` (pure logic) | Vitest | Parsing, mapping, validation, quality rules, area math | **≥ 90%** — this is where real bugs live |
| Repositories | Vitest + local Supabase | Queries return the right shape; RLS actually blocks | Every method |
| Components | RTL | Renders the 4 states, fires the right callbacks | Shared + complex only |
| Routes/flows | Playwright | The per-phase gates above | One spec per phase |
| RLS policies | SQL tests (`pgTAP` or plain SQL asserts) | Each role × each table × each operation | **Every policy** |

**Test data:** commit the real `الدير_ائتمان_مجمع.xlsx` as a fixture, plus deliberately broken
variants (missing column, shifted header row, empty sheet, corrupt file, wrong sheet names). The
importer must fail *loudly and specifically* on each — never silently mis-map.

**Never mock Supabase with `vi.mock('@supabase/supabase-js')`.** Use the repository interfaces —
that's the entire reason they exist.

---

## 10. Conventions & definition of done

**Branching:** `main` is deployable. One branch per phase, PR with a Vercel preview.

**Commits:** Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`).

**A feature is done when:**
1. Types generated and committed, no `any`, typecheck clean.
2. Lint clean, no disabled rules without a comment explaining why.
3. Unit tests for logic, E2E for the flow, all green.
4. All four UI states implemented.
5. Works in **both** light and dark, and in RTL.
6. RLS policy written **and tested** — never rely on the UI hiding an action.
7. Loading is non-blocking, errors are actionable.
8. No file over 250 lines, no function over 40.

**Environment:** `.env.local` with `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` (**server-only — never prefixed `NEXT_PUBLIC_`, never imported into a
client component**). Commit a `.env.example`.

---

## 11. Still open

- Whether every city's Excel follows the same 20-column `جميع البيانات` layout confirmed from
  `الدير_ائتمان_مجمع.xlsx`. The mapping registry (§ 3.1) exists precisely so this can vary — but the
  importer must **fail loudly** on an unrecognized shape rather than guess.
- Whether `editor`/`viewer` need per-city scoping later (v1: roles are global). The schema leaves
  room for a `user_cities` join table without a migration headache.
- Retention policy for uploaded source files in Storage — keep indefinitely for now (they're small
  and they're the audit ground truth).
