# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

HiyazaFinder — a Flutter app for field workers to browse and edit land-holding (حيازة) records for
Egyptian agricultural associations (جمعيات), organized per city. Backend is Supabase (Postgres +
Auth). Data flow: log in → pick a city → download its dataset → work fully offline → edits/new
records queue locally and sync back when connectivity returns.

The canonical architecture and database-schema reference is **`APP_PLAN.md`** — read it before
making structural changes; it documents *why* the code is shaped the way it is, not just what it
does. `DASHBOARD_PLAN.md` describes the companion admin dashboard project (separate repo) and
depends on the schema defined in `APP_PLAN.md` § 6 / `supabase/migrations/`.

## Commands

Prefer `make <target>` (see `Makefile` for the full list) or the underlying Flutter/Dart commands directly:

```bash
make install              # flutter pub get
make generate              # dart run build_runner build --delete-conflicting-outputs (after touching hydrated_bloc/json models)
make dev                   # flutter run --flavor development --target lib/main_dev.dart
make prod                  # flutter run --flavor production --target lib/main_prod.dart

make test                  # flutter test
make test-verbose          # flutter test --reporter expanded
make test-file FILE=test/path/to/some_test.dart   # single test file
flutter test test/path/to/some_test.dart --plain-name "test name"  # single test case

make analyze                # flutter analyze — must be clean before considering work done
make format                 # dart format lib/ test/
```

There are two flavors (`development`/`production`, see `lib/main_dev.dart` / `lib/main_prod.dart`) —
they're currently identical aside from the flavor name; both load `.env` via `flutter_dotenv` for
`SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY`/`SUPABASE_SERVICE_ROLE_KEY`. `.env` is gitignored — never
commit it or print its contents into a file that gets committed.

**Gate before calling any change done:** `flutter analyze` clean and `flutter test` fully green. For
UI changes, also run the app and exercise the change — analyzer/tests confirm correctness, not that
a flow makes sense on screen.

## Architecture

Clean architecture per feature, **inward-only dependencies**:

```
presentation/ ──▶ domain/ ◀── data/
 (UI, cubits)    (entities,     (Supabase,
                  repo            local storage)
                  interfaces)
```

- **`domain/`** is pure Dart — no `package:flutter`, no `supabase_flutter`, no `shared_preferences`.
  Entities, repository *interfaces* (abstract classes), and domain services live here. If a class
  can't be unit-tested without a `WidgetTester` or the network, it's in the wrong layer.
- **`data/`** implements the domain interfaces: Supabase data sources, local caches, the concrete
  repository.
- **`presentation/`** (cubits + widgets) depends only on domain interfaces, never on `data/` directly.

Features live under `lib/features/`: `auth`, `cities`, `holdings`, `sync`, `about`. Each follows the
three-layer split above (not every feature has all three — e.g. `about` is presentation-only).
Cross-cutting code lives under `lib/core/` (`di`, `errors`, `router`, `themes`, `storage`,
`localization`, `networking`, `settings`, `widgets`).

### Dependency injection

`lib/core/di/dependency_injection.dart` wires everything via GetIt, split into per-feature modules
under `lib/core/di/modules/` (`core_module`, `auth_module`, `cities_module`, `holdings_module`,
`sync_module`). Add new bindings to the relevant module, not the flat entry point.

### The offline sync outbox (`lib/features/sync/`)

This is the core mechanism that makes the app work offline-first, and the one most likely to need
care when touched:

- Edits and new records are written to the **local dataset immediately** and a `SyncOperation` is
  enqueued in the *same call* — writes never wait on the network (`HoldingsRepository` in
  `lib/features/holdings/data/repository/`).
- `SyncOperation` (`lib/features/sync/domain/entities/sync_operation.dart`) is a sealed class with
  three variants: `EditHoldingOperation`, `BulkEditOperation`, `AddRecordOperation`. Each carries
  `attempts`/`lastAttemptAt`/`lastError` for retry/backoff bookkeeping.
- `SyncRunner` (`lib/features/sync/data/sync_runner.dart`) flushes the queue sequentially, applying
  exponential backoff (`SyncBackoff`) between retries; an operation that hits `syncMaxAttempts` is
  treated as permanently failed (still visible, no longer auto-retried) until the user retries it
  from the sync details sheet.
- `added_holdings` (Supabase table) is a separate table from the authoritative `holdings` import —
  new records created in the field never touch the immutable import; they get reviewed and
  optionally promoted server-side. Idempotency uses a client-generated UUID (`client_id`) so a
  retried sync never double-inserts.

### Database schema

`supabase/migrations/` holds the numbered, applied migrations — this is the source of truth for the
live schema. `APP_PLAN.md` § 6 documents the schema's intent and rationale; check both when making
schema changes, and add new migrations as further numbered files rather than editing applied ones.
Key tables: `cities`, `holdings` (immutable Excel import), `added_holdings` (field-created records,
`status` pending/approved/rejected), `profiles` (role-gated: admin/editor/viewer/field).

### Excel import format

The app itself no longer parses Excel (that's the dashboard project's job) — but the source format
is documented in `APP_PLAN.md` § 4 because it defines the domain field mapping column-for-column
(e.g. border directions I–L must be mapped by header text, not position, since their order differs
from the app's internal E/S/W/N convention). `الدير_ائتمان_مجمع.xlsx` is a real sample file used as
the format reference during the migration — it contains real PII; do not commit sample data files
containing real holder names/national IDs.

## Localization

Arabic (default, RTL) + English via `easy_localization`, translation files in `assets/lang/{ar,en}.json`
with matching nested key structures. UI strings should go through `.tr()`, not hardcoded — though a
number of older widgets still hardcode Arabic strings (a known, tracked gap, not a pattern to copy
in new code). When testing code that calls `.tr()` outside a widget tree (e.g. a domain service),
note that `.tr()` silently falls back to the raw key when no `EasyLocalization` widget has loaded
translations in that test process — assert against the real translated string via a widget-driven
test if the exact output matters (see `test/features/sync/domain/sync_operation_summary_test.dart`
for the pattern: a real `EasyLocalization` + `MaterialApp` wrapped around a throwaway widget,
pumped twice, loading translations from the actual `assets/lang/*.json` files off disk).

## Testing conventions

Tests mirror the `lib/` feature/layer structure under `test/`. Fakes over mocks for repository-level
interfaces (see `test/features/holdings/data/holdings_repository_add_local_parcel_test.dart` for the
`_FakeSyncQueue`/`_InMemoryKeyValueStore` pattern) — `mockito` is available but hand-written fakes
are preferred for the small interfaces in this codebase.
