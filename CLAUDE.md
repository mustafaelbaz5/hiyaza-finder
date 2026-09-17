# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HiyazaFinder is a Flutter app for field workers to browse and edit land-holding (حيازة) records for
Egyptian agricultural associations (جمعيات), organized per city. Backend is Supabase (Postgres +
Auth). Core workflow: log in → pick a city → download its dataset → work fully offline in the field
→ edits/new records queue locally and sync back automatically once connectivity returns.

`APP_PLAN.md` is the canonical architecture/schema reference — read it before any structural change,
it documents *why*, not just *what*. `DASHBOARD_PLAN.md` describes the companion admin dashboard
(separate repo), which consumes the schema in `APP_PLAN.md` § 6 / `supabase/migrations/`.
`docs/REFACTOR_ROADMAP.md` is the de facto change history — code comments cite specific phases from
it as rationale for past decisions; update it when a change is significant enough to be cited later.

## Architecture

Clean architecture per feature, **inward-only dependencies**: `presentation/ → domain/ ← data/`.

- **`domain/`** — pure Dart, no `package:flutter`/`supabase_flutter`/`shared_preferences`. Entities,
  repository *interfaces*, domain services. If a class can't be unit-tested without a
  `WidgetTester` or the network, it's in the wrong layer.
- **`data/`** — implements the domain interfaces: Supabase data sources, local caches, the concrete
  repository, per-feature JSON mapper functions.
- **`presentation/`** — cubits + widgets. Depends only on domain interfaces, never `data/` directly.

Features live under `lib/features/` (`auth`, `cities`, `holdings`, `sync`, `about` — not every
feature has all three layers, e.g. `about` is presentation-only). Cross-cutting code lives under
`lib/core/`.

What isn't obvious from browsing the folders:

- **No Either/Result type anywhere** (no fpdart/dartz). Errors are thrown `AppException`s
  (`lib/core/errors/exceptions.dart`), not returned values. A parallel `Failure` hierarchy
  (`lib/core/errors/failure.dart`) exists but is dead on every live call path — don't build new
  code around it.
- **No DTO/model layer.** A domain entity carries its own `toJson`/`fromJson` rather than being
  wrapped by a separate `XxxModel`. Supabase row ↔ entity conversion is a standalone function in a
  `<feature>_mapper.dart` file, not a class method.
- **Cubits are usually constructed at the navigation call site** (`AppRouter.generateRoute`), not
  resolved from GetIt — DI wires repositories/services, not presentation state. The one documented
  exception is `CityPickerCubit` (`registerFactory` in `cities_module.dart`, so each screen open
  gets a fresh instance) — a deliberate exception, not license to register others without the same
  reasoning.
- **Routing is hand-rolled**, no go_router/auto_route: `lib/core/router/app_router.dart` is a
  `switch` on `RouteSettings.name`; arguments travel through `settings.arguments`, cast manually;
  every route shares one transition via a `_buildRoute<T>` helper.
- **No blanket StatelessWidget-by-default convention** — both `StatelessWidget` and
  `StatefulWidget` are common here, split by whether the widget owns a controller/animation/local
  mutable state, not by screen-vs-leaf-widget.

### Dependency injection

`lib/core/di/dependency_injection.dart` wires everything via GetIt, split into per-feature modules
under `lib/core/di/modules/`. Add new bindings to the relevant module, not the flat entry point.
`registerLazySingleton` is the default for domain services/stores/repositories; a repository is
typically exposed under each narrower interface it implements (e.g. `HoldingsReader`/
`HoldingsWriter` both resolving to the same `HoldingsRepository` singleton) so consumers can depend
on the narrow interface. A feature that owns sync operations registers its handler(s) onto the
shared `SyncRunner` singleton from its own module — the feature owns its wiring, not a central
sync module.

### The offline sync outbox (`lib/features/sync/`)

The core mechanism that makes the app work offline-first, and the one most likely to need care:

- Edits and new records are written to the **local dataset immediately** and a `SyncOperation` is
  enqueued in the *same call* — writes never wait on the network (`HoldingsRepository` in
  `lib/features/holdings/data/repository/`).
- `SyncOperation` (`lib/features/sync/domain/entities/sync_operation.dart`) is a sealed class — the
  only place in the app sealed classes are used for state (elsewhere, state uses the enum-status
  pattern, see Conventions). Check the file directly for the current variant list before relying on
  it; it grows as the sync feature grows and this doc has drifted from it before. Each variant
  carries `attempts`/`lastAttemptAt`/`lastError` for retry/backoff bookkeeping.
- `SyncRunner` (`lib/features/sync/data/sync_runner.dart`) flushes the queue sequentially with
  exponential backoff (`SyncBackoff`); an operation hitting `syncMaxAttempts` is treated as
  permanently failed (still visible, no longer auto-retried) until retried from the sync details
  sheet.
- `added_holdings` (Supabase table) is separate from the authoritative `holdings` import — new
  records created in the field never touch the immutable import; they're reviewed and optionally
  promoted server-side. Idempotency uses a client-generated UUID (`client_id`) so a retried sync
  never double-inserts.

### Database schema

`supabase/migrations/` holds the numbered, applied migrations — source of truth for the live
schema. `APP_PLAN.md` § 6 documents intent/rationale; check both when making schema changes, and
add new migrations as further numbered files rather than editing applied ones. Key tables:
`cities`, `holdings` (immutable Excel import), `added_holdings` (field-created records, `status`
pending/approved/rejected), `profiles` (role-gated: admin/editor/viewer/field).

### Excel import format

The app itself no longer parses Excel (the dashboard project's job) — the source format is
documented in `APP_PLAN.md` § 4 because it defines the domain field mapping column-for-column (e.g.
border directions I–L must be mapped by header text, not position, since their order differs from
the app's internal E/S/W/N convention). `الدير_ائتمان_مجمع.xlsx` is a real sample file used as the
format reference during migration — it contains real PII; never commit sample data files with real
holder names/national IDs.

## Tech Stack

- **Language**: Dart, SDK `>=3.0.0 <4.0.0`
- **Framework**: Flutter, two flavors (`development`/`production` — `lib/main_dev.dart`/
  `lib/main_prod.dart`, currently identical aside from flavor name)
- **Backend**: `supabase_flutter ^2.16.0` (Postgres + Auth)
- **State management**: `bloc ^9.2.1`, `flutter_bloc ^9.1.1`, `hydrated_bloc ^11.0.0` — plain
  `Cubit`, not the event-driven `Bloc`, not `freezed`
- **Routing**: hand-rolled `Navigator`/`onGenerateRoute` (`core/router/`) — no go_router/auto_route
- **Dependency injection**: `get_it ^9.2.1`
- **Local storage**: `flutter_secure_storage ^10.3.1`, `shared_preferences ^2.5.5`,
  `path_provider ^2.1.6`
- **Localization**: `easy_localization ^3.0.8` — Arabic (default, RTL) + English
- **UI**: `flutter_screenutil ^5.9.3`, `google_fonts ^8.1.0`, `flutter_svg ^2.2.4`,
  `flutter_animate ^4.5.2`, `flutter_native_splash ^2.4.4`
- **Utilities**: `equatable ^2.1.0`, `uuid ^4.5.1`, `url_launcher ^6.3.2`,
  `internet_connection_checker ^3.0.1`
- **Voice search (Android only)**: `speech_to_text ^7.4.0`, `permission_handler ^12.0.3`
- **Env config**: `flutter_dotenv ^6.0.1` — loads `.env` for
  `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY`/`SUPABASE_SERVICE_ROLE_KEY` (gitignored — never commit
  it or print its contents into a committed file)
- **Testing**: `flutter_test`, `test ^1.31.0`, `mockito ^5.6.4` (available, not preferred — see
  Conventions)
- **Codegen**: `build_runner ^2.15.1` (`hydrated_bloc`/JSON models)
- **No Either/Result type**: fpdart/dartz are not dependencies — errors are thrown, not returned.

**Commands** (prefer `make <target>`, see `Makefile` for the full list):

```bash
make install    # flutter pub get
make generate    # dart run build_runner build --delete-conflicting-outputs (after touching hydrated_bloc/json models)
make dev         # flutter run --flavor development --target lib/main_dev.dart
make prod        # flutter run --flavor production --target lib/main_prod.dart
make test        # flutter test
make test-file FILE=test/path/to/some_test.dart   # single test file
flutter test test/path/to/some_test.dart --plain-name "test name"  # single test case
make analyze     # flutter analyze — must be clean before considering work done
make format      # dart format lib/ test/
```

**Gate before calling any change done:** `flutter analyze` clean and `flutter test` fully green. For
UI changes, also run the app and exercise the change — analyzer/tests confirm correctness, not that
a flow makes sense on screen.

## Conventions

### Error handling

No Either/Result type — errors are thrown, not returned. `AppException` (abstract, `implements Exception`, `message`/`statusCode`) has concrete subclasses (`ServerException`, `CacheException`,
`NetworkException`, `UnauthorizedException`, `ValidationException`, etc. — `lib/core/errors/exceptions.dart`).
`ErrorHandler.handleException(error)` (`lib/core/errors/error_handler.dart`) is the single
conversion point — call it from a data source's `catch` block; it classifies the raw error
(Supabase `AuthException`/`PostgrestException`/`StorageException`, connectivity errors) and throws
the matching `AppException` (return type `Never`). Repositories generally don't catch at all — they
let the exception propagate, or `rethrow` after a `debugPrint` (see `HoldingsRepository`'s "fail
loudly, leave local state untouched" pattern). Cubits catch `on AppException catch (e)` first
(surface `e.message`), then a broad `catch (e)` fallback (`e.toString()`) only as a last resort. No
custom logger exists — logging is plain `debugPrint(...)`.

### State management

A state is one **flat `Equatable` class with an enum `status` field**, not a class-per-state
hierarchy — e.g. `HomeState`/`HomeStatus {loading, noFile, loaded, error}`,
`SessionState`/`SessionStatus {unauthenticated, authenticating, authenticated}`. Every state
exposes `copyWith`; where a field must be explicitly resettable to `null` (vs. left unchanged), use
the existing `_unset` sentinel-object pattern (`home_state.dart`, `Parcel.copyWith`). Common states
get named factory constructors (`SessionState.unauthenticated()`, `HomeState.initial()`).
`HydratedCubit` is used exactly once in the app — `AppSettingsCubit` (`lib/core/settings/cubit/`)
for theme/locale. Every other cubit extends plain `Cubit`; domain/data-heavy state persists through
`KeyValueStore` or the repository layer, not Hydrated auto-persistence. A cubit subscribing to a
repository stream holds it as `late final StreamSubscription`, cancelled in an overridden `close()`.

### Entities & mappers

No `XxxModel extends XxxEntity` layer. An entity (e.g.
`lib/features/holdings/domain/entities/parcel.dart`) is its own serialization boundary —
`toJson`/`fromJson` for the full local-cache round-trip, plus a narrower
`toEditableJson`/`fromEditableJson` for the persisted "edit overlay" diff. Supabase-row ↔ entity
conversion is a standalone top-level function per direction in a `<feature>_mapper.dart` file:
`parcelToAddedHoldingsRecord`, `holdingRowToParcel`, `addedHoldingRowToParcel`
(`lib/features/holdings/data/added_holdings_mapper.dart`), `toAppUser(User?)`
(`lib/features/auth/data/supabase_user_mapper.dart`).

### Widgets

Style through `AppTextStyles.fontXXWeight` statics and `context.customColors` (the `CustomColors`
theme extension) — never inline `TextStyle`/`Colors.x` for anything the theme already covers.
Reusable `BuildContext` extensions live in `core/utils/extensions/context_ext.dart`:
`context.theme`/`textTheme`/`colorScheme`/`customColors`/`isDarkMode`,
`context.screenSize`/`isKeyboardVisible`, `context.currentLocale`/`isArabic`,
`context.push`/`pop`/`pushNamed`/`pushAndRemoveAll`, and
`context.showSnackBar`/`showErrorSnackBar`/`showSuccessSnackBar` — these clear any existing
snackbar first, unlike calling `ScaffoldMessenger.of(context).showSnackBar` directly. Use
`rw(...)`/`verticalSpacing(...)` from `core/utils/spacing.dart` for responsive sizing instead of raw
`SizedBox`/hardcoded pixels. Because the app is Arabic/RTL-first, widgets set `textAlign` explicitly
rather than relying on ambient `Directionality`.

### Localization

Arabic (default, RTL) + English via `easy_localization`, translation files in
`assets/lang/{ar,en}.json` with matching nested key structures. UI strings should go through
`.tr()`, not hardcoded — though a number of older widgets still hardcode Arabic strings (a known,
tracked gap, not a pattern to copy in new code). `.tr()` silently falls back to the raw key when no
`EasyLocalization` widget has loaded translations in that process — assert against the real
translated string via a widget-driven test if exact output matters (see
`test/features/sync/domain/sync_operation_summary_test.dart` for the pattern: a real
`EasyLocalization` + `MaterialApp` wrapped around a throwaway widget, pumped twice, loading
translations from the actual `assets/lang/*.json` files off disk).

### Testing

Tests mirror the `lib/` feature/layer structure under `test/`. Fakes over mocks for
repository-level interfaces (see
`test/features/holdings/data/holdings_repository_add_local_parcel_test.dart` for the
`_FakeSyncQueue`/`_InMemoryKeyValueStore` pattern) — `mockito` is available but hand-written fakes
are preferred for the small interfaces in this codebase.

### Naming & lint

One class per file, `snake_case` filename. Repository interfaces in `domain/repositories/`,
implementations in `data/repository/`. Cubits in `presentation/cubit/` as `<name>_cubit.dart` +
`<name>_state.dart`. Mapper functions in one `data/<feature>_mapper.dart` per feature, not per
entity. `analysis_options.yaml` builds on `flutter_lints` plus `prefer_const_constructors`,
`prefer_final_locals`, `prefer_final_parameters`, `always_specify_types`,
`use_key_in_widget_constructors`, `avoid_dynamic_calls` — write new parameters as `final` by
default. `always_specify_types` is downgraded to non-blocking
(`analyzer.errors.always_specify_types: ignore`) but followed as a style norm anyway; every other
rule in that list is enforced and fails `flutter analyze` on violation.

## Do

- Keep dependencies inward-only: `presentation → domain ← data`; never import `data/` into
  `presentation/`, or Flutter/Supabase into `domain/`.
- Check `lib/core/` for an existing helper (`context_ext.dart`, `spacing.dart`, `NetworkInfo`,
  `KeyValueStore`, `SecureStorage`) before writing a new one.
- Write local-first: update local storage **and** enqueue a `SyncOperation` in the same call,
  before any network round-trip.
- Let a failed local write throw/rethrow rather than silently leaving stale local state.
- Give a new kind of field mutation its own `SyncOperation` variant, and register its handler from
  the owning feature's own DI module.
- Add new migrations as further numbered files in `supabase/migrations/`; treat applied ones as
  immutable.
- Keep Supabase ↔ entity conversion in one small function per direction, in the feature's
  `data/<feature>_mapper.dart`.
- Shape a new cubit's state as one flat `Equatable` class with an enum `status` field and a
  `copyWith`; cancel any `StreamSubscription` it opens in an overridden `close()`.
- Convert raw errors to `AppException` at the data-source boundary via
  `ErrorHandler.handleException`; catch `on AppException` first in cubits and surface `e.message`.
- Route every user-facing string through `.tr()` with matching keys in both `assets/lang/ar.json`
  and `assets/lang/en.json`.
- Run `make generate` after touching `hydrated_bloc` state or a JSON-serializable entity.
- Consult `APP_PLAN.md` before any structural or schema change — it carries the *why*, not just the
  *what* — and update `docs/REFACTOR_ROADMAP.md` when the change is significant enough to be cited
  later.
- Prefer hand-written fakes over `mockito` for small repository-level interfaces in tests.
- Run `flutter analyze` and `flutter test` before calling any change done; for UI changes, also run
  the app and exercise the change by hand.
- When adding a new feature: build `domain/` first (entity + repository interface), then `data/`
  (implementation + mapper), wire it into a per-feature DI module, then `presentation/`
  (cubit → screens/widgets), then route it in `AppRouter`/`Routes`. Localize strings and add tests
  as you go rather than after.

## Don't

- Don't import `data/` into `presentation/`, or Flutter/Supabase/shared_preferences into `domain/`.
- Don't wrap an entity in a separate `XxxModel`/DTO class — extend the entity's own
  `toJson`/`fromJson` instead.
- Don't introduce an Either/Result type (fpdart/dartz) — this codebase throws `AppException`s; a
  Result type in one corner would fragment the error-handling convention every cubit relies on.
- Don't build a new code path around returning `Failure` objects — that hierarchy exists but isn't
  the live pattern.
- Don't register a new cubit in GetIt by default — construct it at the navigation site in
  `AppRouter.generateRoute`. `CityPickerCubit` is a deliberate, documented exception; don't extend
  it without the same reasoning.
- Don't add DI bindings to the flat `dependency_injection.dart` — use the feature's own module.
- Don't block a local write on network availability — the sync queue exists precisely so writes
  never wait on connectivity.
- Don't let a field-created record touch the immutable `holdings` import table directly — it
  belongs in `added_holdings`, reviewed/promoted separately.
- Don't swallow an exception in a repository to return a "safe" default — offline correctness
  depends on the sync layer knowing a write actually failed.
- Don't edit an already-applied migration file — add a new numbered migration instead.
- Don't commit `.env`, its contents, or any sample data file with real holder names/national IDs
  (e.g. never commit a populated copy of `الدير_ائتمان_مجمع.xlsx`).
- Don't build a class-per-state hierarchy (`XxxLoading`/`XxxLoaded`/`XxxError`) for a new cubit —
  use the single-class-plus-status-enum shape every existing cubit uses.
- Don't extend `HydratedCubit` for domain- or data-heavy state — reserved for small, app-wide
  settings (theme/locale).
- Don't call `ScaffoldMessenger.of(context).showSnackBar` directly — use
  `context.showXxxSnackBar` so existing snackbars are cleared first instead of stacking.
- Don't hardcode a `TextStyle`/`Color` literal where a theme token already covers the case.
- Don't introduce a logging package for a single call site — this codebase uses plain
  `debugPrint`.
- Don't assume `.tr()` output in a non-widget test — it silently falls back to the raw key without
  a loaded `EasyLocalization` widget.
- Don't hardcode a new Arabic string directly in a widget — the handful that already do this are a
  known gap, not a pattern to extend.
- Don't default to `StatelessWidget` on the assumption it's the house style — pick based on
  whether the widget actually needs controller/animation/local state; this codebase mixes both.
- Don't consider a change complete without a clean `flutter analyze` and fully green
  `flutter test`.
- Don't trust this file's description of enumerated code symbols (e.g. `SyncOperation`'s variant
  list) without a quick grep first — these drift as the code evolves faster than the doc does.
