# Hiyaza Finder — Local-First Architecture

This document is the canonical implementation contract for the Flutter app.

## Data ownership

- The remote backend is read-only and is accessed through `http` GET requests.
- The app never uses a Supabase SDK, authentication session, realtime channel, or
  remote write.
- Downloaded city datasets are persisted as local snapshots.
- Edits, added parcels, deletions, settings, custom crop types, and trackers are
  persisted locally and are scoped by city where applicable.
- Export is the boundary for taking local changes outside the app.

## Feature boundaries

Each feature follows this shape:

```text
data/model/   pure Dart models and enums
data/remote/  read-only HTTP data sources
data/local/   local stores and pure local services
data/repo/    repository contracts and implementations
logic/cubit/  state and orchestration
ui/           screens and widgets
```

Models must not import Flutter. Cubits depend on repository contracts. UI reads
state from Cubits and must not access storage or remote data sources directly.
Screens render and delegate; business rules belong in logic or local services.

## Persistence guarantees

- A failed download must not replace the last valid snapshot.
- The app remains usable offline after one successful city download.
- Local writes are durable before the UI reports success.
- City-scoped stores must not leak records between cities.
- Every mutable operation must have a corresponding local read path.

## Change gates

Each implementation phase must pass `flutter analyze` and its relevant tests
before the next phase begins. New behavior requires focused unit or widget tests.
Forbidden dependencies and remote writes are checked with repository searches.

Windows and Android are the required supported platforms.
