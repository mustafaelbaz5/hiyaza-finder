# Hiyaza Finder — Performance Refactor Plan

> **Canonical execution plan.** Follow [ARCHITECTURE_RULES.md](ARCHITECTURE_RULES.md)
> for all implementation decisions.

## Baseline and guardrails

1. Make the existing analyzer and test suite green before structural moves.
2. Record Profile-mode timings for a cached city of roughly 2,500 parcels:
   startup, search, open details, change usage/crop, copy, and list scroll.
3. Preserve copy output, local persistence, offline behavior, and routing
   unless a change is explicitly approved and covered by tests.

## Delivery phases

1. **Foundation:** centralize local persistence dependencies, add safe
   migration infrastructure, and remove legacy-document ambiguity.
2. **Parcel session and search:** publish immutable parcel snapshots from the
   repository, split active-city and search state, build indexes once per
   snapshot, and debounce search by 180ms.
3. **Details and editing:** add dedicated detail/editor Cubits, move field
   policies to pure services, and replace edit icons for usage/crop with quick
   sheets backed by local recent selections.
4. **Remaining Holdings flows:** split add-record, basins, review/bulk-edit,
   missing-holdings, and export orchestration into focused Cubits.
5. **Feature boundaries:** remove direct UI repository access across Cities,
   Crop Type, Jazla, and App Control; replace Holdings/Jazla cycles with ports
   and a lifecycle coordinator.
6. **Verification:** profile the priority field-review workflow on Android and
   Windows, run a native UX/accessibility review, and retire contradictory
   legacy documentation.

## Performance acceptance

- Search results update within 200ms after the 180ms debounce on the reference
  city, without rebuilding unrelated home regions.
- Detail edits update only their affected selectors and do not reload the city.
- Cached-city navigation makes no city-data HTTP request.
- No synchronous persistence, expensive sorting, or formatting runs from a
  list item's `build` method.
- Android and Windows retain RTL layout, keyboard safety, text scaling, and
  offline operation.
