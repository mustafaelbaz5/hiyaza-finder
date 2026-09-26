# Hiyaza Finder — Architecture Rules

> **Canonical engineering rules.** This document overrides any older plan
> that proposes Supabase Auth, realtime, synchronization, or remote writes.

## Product boundaries

- Hiyaza Finder is local-first on Android and Windows.
- Supabase is a read-only HTTP source for city downloads and app control.
- Every user mutation has a local persistence path and remains available
  offline after the first successful city download.
- Existing local data must be migrated safely; no refactor may reset it.

## Feature structure

Each feature uses only `data/model`, `data/remote`, `data/local`,
`data/repo`, `logic/cubit`, and `ui/widgets` as applicable.

- Models and pure policies have no Flutter imports.
- Remote sources perform read-only HTTP work.
- Repositories coordinate data sources and expose abstract contracts.
- Cubits depend on contracts, own orchestration, and emit immutable state.
- UI renders state and sends intents to Cubits only.

## Dependency and state rules

- UI must not access `getIt`, repositories, stores, HTTP clients, or files.
- Feature UI may depend only on its Cubits, public models, and core UI tools.
- Cross-feature communication uses a narrow public port; never another
  feature's local source or concrete repository.
- `setState` is reserved for ephemeral widget state such as controllers,
  focus, and animation. Shared, persisted, or asynchronous state belongs in a
  Cubit.
- Use `BlocSelector`/`buildWhen` for independently changing regions and
  `BlocListener` for navigation, dialogs, SnackBars, and other effects.

## Core rules

`core/data` contains reusable persistence, migration, file-cache, storage-key,
and read-only transport utilities only. It never owns Parcel, Jazla, City, or
other feature business rules.

- Local stores receive their dependencies through constructors.
- A migration reads legacy data, validates the new representation, writes it,
  then records completion. It never deletes a valid legacy value first.
- Shared widgets are extracted only after the same interaction appears in two
  or more features and can remain free of business logic.

## Maintainability and verification

- One main public class or widget per file.
- Target limits: widget ≤200 lines; screen, Cubit, repository ≤250 lines.
  A file up to 350 lines requires a documented reason and a follow-up split.
- New behavior needs unit tests; state transitions need Cubit tests; visible
  flows need widget tests.
- Every completed phase passes `dart format --set-exit-if-changed`,
  `flutter analyze`, `flutter test`, forbidden-import checks, and the relevant
  Android/Windows manual checklist.
