# Parcel Activity Filter — Active Parcels and Zero-Area Records

## Status

In implementation. This document is the source of truth for separating operational parcels from retained zero-area reference records. No zero-area record may be deleted, migrated away, or excluded from storage by this feature.

## Product goal

Agricultural association data can contain cancelled or zeroed parcel rows. Those rows often retain useful holder identity data, but they must not inflate operational parcel counts, basin progress, or area-driven work flows.

The app must make active parcels the normal daily view while keeping zero-area records easy to reveal when a field worker needs to identify a person and add a new parcel for them.

## Classification rule

`totalSqm` is a derived presentation value. Classification uses only the source agricultural units:

```text
active     = feddan > 0 OR qirat > 0 OR sahm > 0
zero-area  = feddan <= 0 AND qirat <= 0 AND sahm <= 0
```

Null values are treated as zero. Missing borders never change activity status. Legacy negative values are never considered active; creation and editing continue to reject negative area input.

## User experience

### Home

- The city card presents `active parcels`, then the complete record count, then a quiet zero-area count.
- Search defaults to **Active parcels** for a newly opened city.
- A compact filter control opens three explicit choices: active parcels, all records, and zero-area records. This is intentionally not a switch because the surface has three valid modes.
- When active search returns no result but zero-area records match, the empty state offers a one-tap action to reveal the matching zero-area records without clearing the query.

### Basins

- Every basin card shows active parcel count, total record count, and zero-area count.
- Basin completion progress uses active holdings only.
- A basin detail page has a visibility segment (`Active`, `All`, `Zero-area`) in addition to the existing completion filter. Visibility applies to all basin results and counters in that page.

### Data preservation

- Zero-area records remain available through `All` and `Zero-area` filters.
- They remain searchable when explicitly requested and can be used as the source for adding a new parcel for the same person.
- Existing exports retain their current data scope unless an export-specific filter is introduced later.

## Architecture

```text
parcel_catalog/
  data/model/parcel_activity_status.dart
  data/model/parcel_activity_summary.dart
  data/model/parcel_visibility_filter.dart
  data/local/parcel_activity_classifier.dart
  data/local/parcel_activity_index.dart
  data/local/parcel_visibility_preferences.dart

parcel_search/
  logic/cubit/parcel_search_cubit.dart
  logic/cubit/parcel_search_state.dart
  ui/widgets/parcel_visibility_filter_button.dart

home/
  HomeCubit derives activity summaries only from catalog snapshots.
  HomeMainCard renders the city-level summary.

basins/
  BasinsCubit uses cached catalog-derived basin summaries.
  BasinHoldingsCubit owns visibility and completion filters.
```

The classifier is pure Dart. Widgets never inspect area fields directly. Repository snapshot changes rebuild derived indexes once; search and UI consume those indexes rather than rescanning the dataset in `build`.

## State and persistence

- Home search visibility is saved per city under `parcel_visibility_filter::<cityId>`.
- The initial preference is `activeOnly`.
- Basin detail visibility starts at `activeOnly` for each opened basin and is scoped to that page, so changing it does not unexpectedly alter Home search.
- A parcel add, delete, local edit, bulk edit, cache load, or city switch publishes a new catalog snapshot. Derived activity counts and search results then update automatically.

## Performance constraints

- Build active/zero indexes once for each catalog snapshot.
- Do not calculate activity counts inside widget `build` methods.
- Do not perform remote requests because a filter changed.
- Keep existing search debounce behavior.
- Use `BlocSelector`/small `BlocBuilder` scopes for summary and result regions.
- Avoid continuous animation; filter changes may use a short, theme-consistent transition only.

## Implementation phases

1. Add classification models, pure classifier, cached activity index, and unit tests.
2. Extend catalog reader/query contracts with visibility-aware queries and activity summaries.
3. Add city-scoped search preference and integrate visibility into `ParcelSearchCubit`.
4. Update Home city summary, filter control, and zero-area matching empty state.
5. Extend basin summaries and refactor basin detail filtering into `BasinHoldingsCubit`.
6. Add translations, widget tests, performance checks, and Android/Windows manual verification.

## Acceptance criteria

- A parcel is active only when at least one agricultural area unit is positive.
- Home exposes active, total, and zero-area counts without deleting any record.
- Home search defaults to active-only and can reveal matching zero-area records without retyping.
- Basin cards and basin detail use active parcel counts and active-only progress.
- Basin visibility affects every displayed basin result and counter.
- Area edits update counts and results immediately through catalog snapshots.
- No filter operation performs a database/network request.
- Arabic RTL, English copy, dark mode, narrow screens, and Windows remain usable.
- `dart format --set-exit-if-changed`, `flutter analyze`, and focused tests pass.
