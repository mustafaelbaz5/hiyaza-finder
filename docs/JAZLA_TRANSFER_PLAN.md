# Jazla Transfer — Export and Import Between Devices

## Status

Planned. This document defines the agreed implementation for a future release; it does not authorize changing the current Jazla data flow yet.

## Purpose

Allow a user to export one Jazla from one installation of Hiyaza Finder and import it into another installation of the same app. The imported Jazla must preserve its parcel order, reviewed state, defaults, and parcel information for offline use.

The transfer is local-first. It does not call Supabase, require authentication, or create remote writes.

## Non-negotiable scope boundary

An imported Jazla belongs to exactly one city and one association. It may only be imported while that same city and association are active in the receiving app.

The association match is evaluated in this order:

1. `cityId` must match.
2. `associationCode` must match when both sides have a value.
3. `associationType` must match.
4. A normalized Arabic association name must match as a human-readable safety check.

The exported association name is displayed in the UI, but a stable ID or association code is the primary identity whenever available. No local data is written when validation fails.

## User journeys

### Export

1. The user opens a Jazla.
2. The user opens the Jazla actions sheet and chooses **Export Jazla**.
3. The app prepares a portable `.hiyaza-jazla` file.
4. A confirmation view shows the Jazla, association, city, parcel count, and a privacy notice.
5. The operating-system share/save flow opens.

### Import

1. The user first opens the city and association that own the Jazla.
2. From the Jazla list AppBar, the user chooses **Import Jazla**.
3. The user selects a `.hiyaza-jazla` file.
4. The app validates the file fully before writing anything.
5. A preview sheet shows the source city, association, Jazla name, basin, parcel count, area, and export time.
6. If city and association match, the user confirms import.
7. The app stores the transfer atomically and opens the imported Jazla.

### Association mismatch

The import preview must show a blocking error such as:

> لا يمكن استيراد هذه الجزلة. الجمعية في الملف تختلف عن الجمعية المفتوحة حاليًا. افتح المدينة والجمعية الصحيحين ثم حاول مرة أخرى.

The confirm button stays disabled and no storage mutation occurs.

## Package format

The first release uses a single UTF-8 JSON document with the extension `.hiyaza-jazla`. JSON keeps the package inspectable, testable, and dependency-light. ZIP compression is deferred until real-world file-size measurements justify it.

```json
{
  "schemaVersion": 1,
  "bundleType": "jazla_transfer",
  "exportedAt": "2026-09-29T10:30:00.000Z",
  "sourceAppVersion": "1.0.0",
  "source": {
    "city": { "id": "city-id", "name": "منشأة الإخوة" },
    "association": {
      "code": "1233941",
      "name": "منشأة الإخوة - الإصلاح الزراعي",
      "type": "agricultural_reform"
    }
  },
  "jazla": {},
  "parcels": [],
  "completionStatuses": {}
}
```

### Required payloads

- **Manifest:** schema version, bundle type, export time, source app version, city, and association identity.
- **Jazla:** all current Jazla fields, including its basin, target area, `parcelIds` order, timestamps, and parcel defaults.
- **Parcels:** fully resolved current parcel records referenced by the Jazla only.
- **Review status:** completion/review state keyed by parcel ID.

The transfer must contain final resolved parcel values, not only field-edit overlays. This guarantees useful offline viewing on the destination device.

## Data ownership and storage

Create a dedicated feature:

```text
features/jazla_transfer/
  data/
    model/
    local/
    repo/
  logic/cubit/
  ui/widgets/
```

Suggested types:

```text
JazlaTransferBundle
JazlaTransferManifest
JazlaTransferAssociation
JazlaTransferCodec
JazlaTransferRepository
JazlaTransferRepositoryImpl
ImportedJazlaParcelStore
JazlaExportCubit
JazlaImportCubit
```

`ImportedJazlaParcelStore` is scoped by:

```text
cityId + jazlaId + parcelId
```

It must not overwrite the general city parcel snapshot or ordinary local field edits. It exists only as an offline fallback for the Jazla that was imported.

## Parcel resolution rule

When opening an imported Jazla:

1. Use the current resolved parcel from `parcel_catalog` when it exists locally.
2. Otherwise use the parcel snapshot from `ImportedJazlaParcelStore`.
3. Never inject imported parcels into general city search results automatically.

This preserves the existing city catalog while still allowing an imported Jazla to work offline or on a device without the source city snapshot.

## Validation before import

All validation happens before any local write:

- File is readable UTF-8 JSON.
- `bundleType` equals `jazla_transfer`.
- `schemaVersion` is supported.
- Source city and association metadata are complete enough to validate.
- City and association match the active context.
- Jazla payload is valid.
- Parcel IDs are unique.
- Every `jazla.parcelIds` entry exists in the package parcel list.
- No parcel belongs to another city in the payload.
- File size and parcel count stay within configured safe limits.

Invalid, corrupted, incompatible, or future-version files are rejected with a clear user message and zero writes.

## Conflict handling

### Existing Jazla ID

If a Jazla with the same ID already exists in the active city, show a conflict sheet that compares names and `updatedAt` values. Version 1 offers only:

- Replace the existing imported/local Jazla with the file version.
- Cancel.

Automatic merging is explicitly out of scope for version 1 because merging parcel order, defaults, and local changes can lose user work.

### Existing parcel IDs

Imported parcel data remains Jazla-scoped in `ImportedJazlaParcelStore`. It does not overwrite the global parcel catalog. The normal catalog remains the preferred source when available.

## UI requirements

- Use existing application theme tokens, `AppColors`, `CustomColors`, RTL conventions, and Material Rounded icons.
- The export action belongs in `JazlaActionsSheet`.
- The import action belongs in the Jazla list AppBar.
- Use bottom sheets for preview and conflict handling.
- Show explicit loading, success, validation-error, and write-error states.
- Disable repeat presses during codec, file, or storage operations.
- Do not place repository/store calls in widgets; UI sends intents to Cubits only.

## Privacy requirements

The bundle may contain national IDs, parcel boundaries, holder names, and notes. Before export, display a clear warning:

> هذا الملف يحتوي على بيانات حيازات وأشخاص. شاركه فقط مع جهات موثوقة.

Password encryption is not part of version 1. It may be planned later only with a documented key-recovery and compatibility strategy.

## Implementation phases

### Phase 1 — Data contracts and codec

- Define bundle, manifest, and association models.
- Implement strict JSON encode/decode.
- Add schema-version routing.
- Add pure validation and Arabic-name normalization.
- Write codec and validation tests.

### Phase 2 — Local transfer persistence

- Implement `ImportedJazlaParcelStore` with city/Jazla/parcel scoped keys.
- Add atomic-style import transaction semantics: validate, stage data, persist imported parcel fallback, persist Jazla, persist completion state, then publish catalog/Jazla updates.
- Ensure failed writes preserve the last valid local state.

### Phase 3 — Export flow

- Add `JazlaExportCubit`.
- Resolve current parcel data and review status.
- Produce the portable file.
- Add save/share integration for Android and Windows.
- Add privacy confirmation UI.

### Phase 4 — Import flow

- Add file-picker integration.
- Add `JazlaImportCubit`.
- Parse and validate before showing confirmation.
- Build the association/city preview sheet.
- Persist only after explicit user confirmation.

### Phase 5 — Imported parcel fallback

- Extend the public `parcel_catalog` reader contract with a Jazla-scoped fallback lookup.
- Update Jazla details and Jazla review flow to resolve unavailable catalog parcels from the imported fallback store.
- Keep general city search isolated from imported-only parcels.

### Phase 6 — Conflicts and resilience

- Add same-Jazla-ID conflict UI.
- Add rollback/error recovery coverage.
- Define safe maximum file and parcel limits.
- Add user-facing messages for each failure category.

### Phase 7 — Verification

- Run formatter, analyzer, and the complete test suite.
- Manually verify Android and Windows file pick/save/share flows.
- Verify an offline destination device can open and review the imported Jazla.

## Acceptance tests

- Export/import round-trip preserves Jazla metadata, parcel order, target area, defaults, notes, and review states.
- Import succeeds only for the same active city and association.
- Different city, association code, association type, or normalized association name blocks import with no writes.
- An imported Jazla opens offline when the source city snapshot is absent.
- Existing global parcel data is never overwritten by an imported transfer.
- Corrupted JSON, unsupported schema, duplicated parcel IDs, mismatched parcel references, and oversized files are rejected safely.
- Same Jazla ID requires an explicit replace-or-cancel decision.
- Export/import UI works in Arabic RTL, dark mode, narrow mobile layouts, and Windows.
- `dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test` pass before release.

## Explicit non-goals for version 1

- Supabase upload, sync, or remote sharing.
- Automatic merge of two Jazlas.
- Import into another city or association.
- Password-protected/encrypted files.
- Importing transfer parcels into general city search automatically.
- ZIP compression unless validated package sizes require it.

## Future extensions

- Optional ZIP compression with a backward-compatible `schemaVersion`.
- Password-protected export.
- QR-assisted nearby-device handoff.
- Controlled merge with a full conflict-resolution screen.
- Signed bundles or organization-level verification when authentication is introduced.
