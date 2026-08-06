# HiyazaFinder Flutter Application Architecture Reference

**Last Updated:** August 6, 2026  
**Version:** 1.1.2  
**Architecture Pattern:** Clean Architecture (3-layer: presentation, domain, data)  
**Canonical Source:** `lib/` folder structure, `APP_PLAN.md` (design decisions)

**Accuracy note (added during Phase 1 architecture audit):** this document contains claims that do
not match the real `lib/` tree as of this note — file names (`holding_detail_screen.dart` should be
`detail_screen.dart`, `search_cubit.dart` should be `home_cubit.dart`), files that don't exist
(`sync_status_badge.dart`, `sync_operation.dart`, `sync_queue.dart`, `usecases/` folders under
`auth`/`cities`), and stale claims already corrected below: **`lib/core/api/` (Dio) and
`lib/core/errors/handlers/dio_handler.dart` have been removed** (confirmed genuinely unreferenced —
no Firebase packages ever existed in `pubspec.yaml`, contrary to §17's claim). Verify any other
specific file/line/status claim in this document against the real repo before relying on it — treat
this as a useful starting inventory of concerns (§14/§15's lists), not a verified source of truth.

---

## 1. Folder Structure & Organization

```
lib/
├── main_dev.dart                    # Development flavor entry point
├── main_prod.dart                   # Production flavor entry point
│
├── core/                            # Cross-cutting concerns (unchanged by feature)
│   ├── api/                         # HTTP client setup (legacy, mostly unused now)
│   │   ├── api_consumer.dart
│   │   ├── api_interceptors.dart
│   │   └── dio_factory.dart
│   │
│   ├── di/                          # Dependency Injection (GetIt configuration)
│   │   ├── dependency_injection.dart (main entry point)
│   │   └── modules/
│   │       ├── core_module.dart     (services, storage, network)
│   │       ├── auth_module.dart
│   │       ├── cities_module.dart
│   │       ├── holdings_module.dart
│   │       └── sync_module.dart
│   │
│   ├── errors/                      # Error handling
│   │   ├── error_handler.dart       (central exception → Failure mapper)
│   │   ├── failure.dart             (Result<T, Failure> value type)
│   │   ├── exceptions.dart
│   │   └── handlers/
│   │       ├── supabase_handler.dart (SupabaseException → Failure)
│   │       ├── dio_handler.dart     (DioException → Failure)
│   │       └── firebase_handler.dart (UNUSED — to be deleted)
│   │
│   ├── networking/
│   │   └── network_info.dart        (internet connection checker wrapper)
│   │
│   ├── router/
│   │   ├── app_router.dart          (GoRouter configuration)
│   │   └── routes.dart              (route string constants)
│   │
│   ├── settings/
│   │   ├── cubit/
│   │   │   ├── app_settings_cubit.dart (font/theme state)
│   │   │   └── app_settings_state.dart
│   │   └── ui/
│   │       └── settings_sheet.dart
│   │
│   ├── storage/
│   │   └── key_value_store.dart     (abstraction over SharedPreferences)
│   │
│   ├── service/
│   │   ├── secure_storage.dart      (flutter_secure_storage wrapper)
│   │   ├── voice_search_service.dart (speech_to_text integration)
│   │
│   ├── themes/
│   │   ├── app_colors.dart
│   │   ├── app_font_family.dart
│   │   ├── app_font_weight.dart
│   │   ├── app_text_styles.dart
│   │   ├── custom_colors.dart
│   │   └── theme_data/
│   │       ├── theme_data_dark.dart
│   │       └── theme_data_light.dart
│   │
│   ├── localization/
│   │   └── localization_manager.dart (easy_localization wrapper)
│   │
│   ├── utils/
│   │   ├── app_assets.dart          (asset paths)
│   │   ├── app_constants.dart       (hardcoded constants)
│   │   ├── spacing.dart             (design tokens)
│   │   ├── validators.dart          (form validation)
│   │   ├── extensions/
│   │   │   ├── context_ext.dart     (BuildContext helpers)
│   │   │   ├── datetime_ext.dart
│   │   │   ├── list_ext.dart
│   │   │   ├── num_ext.dart
│   │   │   └── string_ext.dart
│   │   └── functions/
│   │       ├── app_setting_method.dart
│   │       └── url_launcher.dart
│   │
│   └── widgets/                     (reusable UI components)
│       ├── app_back_button.dart
│       ├── custom_text_form_.dart
│       ├── custom_text_button.dart
│       ├── error_screen.dart
│       ├── ui/
│       │   ├── dialogs/
│       │   │   ├── app_dialogs.dart
│       │   │   ├── choice_dialog.dart
│       │   │   ├── custom_app_dialog.dart
│       │   │   └── text_input_dialog.dart
│       │   └── loaders/
│       │       └── overlay_loader.dart
│
├── features/                        # Feature modules (domain/data/presentation per feature)
│   │
│   ├── auth/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── app_user.dart    (user identity + role)
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart (interface)
│   │   │   └── usecases/
│   │   │       ├── sign_in.dart
│   │   │       ├── sign_out.dart
│   │   │       └── watch_session.dart
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── app_user_model.dart (JSON serialization)
│   │   │   └── supabase_auth_repository.dart (implementation)
│   │   └── presentation/
│   │       ├── cubit/
│   │       │   └── session_cubit.dart (login/logout state)
│   │       └── screens/
│   │           └── login_screen.dart
│   │
│   ├── cities/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── city.dart        (published city metadata)
│   │   │   │   ├── city_snapshot.dart (locally cached city data)
│   │   │   │   ├── cached_city_meta.dart (snapshot metadata only)
│   │   │   │   └── association_type.dart (credit vs. reform city type)
│   │   │   ├── repositories/
│   │   │   │   └── city_repository.dart (interface)
│   │   │   └── usecases/
│   │   │       ├── list_cities.dart
│   │   │       ├── download_city.dart
│   │   │       └── check_staleness.dart
│   │   ├── data/
│   │   │   ├── supabase_city_data_source.dart (Supabase queries)
│   │   │   ├── city_snapshot_cache.dart (local file I/O)
│   │   │   ├── city_repository_impl.dart (coordinates above)
│   │   │   ├── holding_row_mapper.dart (holdings → Parcel)
│   │   │   └── (no models; uses domain entities directly)
│   │   └── presentation/
│   │       ├── cubit/
│   │       │   └── city_state.dart
│   │       └── screens/
│   │           ├── city_picker_screen.dart
│   │           └── manage_cities_screen.dart
│   │
│   ├── holdings/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── parcel.dart      (core business entity; 445 lines)
│   │   │   │   ├── bulk_editable_field.dart (enum + extension: which field being bulk-edited)
│   │   │   │   └── bulk_edit_outcome.dart (result of bulk edit)
│   │   │   ├── repositories/
│   │   │   │   ├── holdings_reader.dart (interface: search/query)
│   │   │   │   └── holdings_writer.dart (interface: add/edit/bulk-edit)
│   │   │   └── services/            (pure business logic, testable)
│   │   │       ├── parcel_query_service.dart (search, basin filtering, lookups)
│   │   │       ├── parcel_edit_overlay.dart (merge: original + edits)
│   │   │       ├── bulk_edit_service.dart (apply bulk edit to parcels)
│   │   │       ├── clipboard_formatter.dart (format for copy-all)
│   │   │       ├── border_name_index.dart (O(1) حدود lookup)
│   │   │       ├── field_change_tracker.dart (undo/redo support)
│   │   │
│   │   ├── data/
│   │   │   ├── repository/
│   │   │   │   └── holdings_repository.dart (in-memory dataset manager)
│   │   │   ├── holdings_api.dart    (Supabase write operations)
│   │   │   ├── added_holdings_mapper.dart (Parcel → added_holdings insert shape)
│   │   │   └── parcel_edits_store.dart (local JSON edit overlay persistence)
│   │   │
│   │   └── presentation/
│   │       ├── cubit/
│   │       │   └── search_cubit.dart
│   │       ├── screens/
│   │       │   ├── home_screen.dart
│   │       │   ├── holding_detail_screen.dart
│   │       │   ├── add_record_screen.dart
│   │       │   └── file_status_screen.dart
│   │       └── widgets/
│   │           ├── parcel_detail_card.dart (large, ~500 lines; core display)
│   │           ├── field_row.dart
│   │           ├── section_card.dart
│   │           ├── border_compass.dart (visual 4-way borders)
│   │           ├── crop_type_picker.dart
│   │           ├── picker_row.dart
│   │           ├── tile_icon_button.dart
│   │           ├── top_bar_icon_button.dart
│   │           ├── empty_body.dart
│   │           ├── error_body.dart
│   │           └── file_info_card.dart
│   │
│   ├── sync/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── sync_operation.dart (sealed class: EditHolding | AddRecord | BulkEditRecords)
│   │   │   └── repositories/
│   │   │       └── sync_queue.dart (interface)
│   │   │
│   │   ├── data/
│   │   │   ├── holdings_api.dart    (Supabase network calls)
│   │   │   ├── realtime_sync_service.dart (live multi-device updates)
│   │   │   └── (no persistent queue yet; online-first design)
│   │   │
│   │   └── presentation/
│   │       └── widgets/
│   │           └── sync_status_badge.dart (pending operation count + last sync time)
│   │
│   └── about/
│       ├── data/
│       │   └── about_constants.dart
│       └── ui/
│           ├── about_screen.dart
│           └── widgets/
│               ├── about_section_label.dart
│               ├── about_app_header.dart
│               └── about_flat_row.dart
│
└── test/                            # Unit/integration tests (mirrors lib/ structure)
    ├── features/
    │   ├── auth/
    │   ├── cities/
    │   ├── holdings/
    │   │   ├── data/
    │   │   │   └── added_holdings_mapper_test.dart
    │   │   ├── domain/
    │   │   │   ├── entities/
    │   │   │   └── services/
    │   │   └── logic/
    │   └── sync/
    └── core/
        └── router/
```

---

## 2. Architecture Layers

### 2.1 Domain Layer

**Location:** `lib/features/*/domain/`

**Dependencies:** Pure Dart only. NO Flutter, NO Supabase, NO SharedPreferences.

**Responsibility:** Business logic, entities, repository interfaces, use cases, services.

**Contents:**

| Component | Purpose | Testable | Example |
|-----------|---------|----------|---------|
| **Entities** | Core business objects; immutable | Yes (plain Dart) | `Parcel`, `City`, `AppUser` |
| **Repository Interfaces** | Abstract contracts for data access | Yes (fakes substitute implementations) | `HoldingsReader`, `HoldingsWriter`, `CityRepository` |
| **Services** | Pure functions over entities; no I/O | Yes (unit test, no fixtures) | `ParcelEditOverlay.apply()`, `ParcelQueryService.search()` |
| **Use Cases** | Orchestrate services + repositories for a single user action | Yes (against fake repos) | `SignInUseCase`, `DownloadCityUseCase` |

**Key Entities:**
- **`Parcel`** (445 lines): One row of land-holding data. Combines fields from `holdings` (immutable) and `holding_edits` (corrections). Has two JSON serialization paths: `toEditableJson()` (overlay) and `toJson()` (full snapshot).
- **`City`**: Published city metadata; only `status='published'` are offered to field app.
- **`CitySnapshot`**: Locally cached city data (parcels + metadata + version).
- **`AppUser`**: Authenticated user identity + role.

**Design Principles:**
- Entities use value semantics (`copyWith`, `==`/`hashCode` via `equatable`).
- Repository interfaces are narrow (`HoldingsReader` vs. `HoldingsWriter`); no god-interfaces.
- Services are pure: given input, always return same output (no caching, no I/O).

---

### 2.2 Data Layer

**Location:** `lib/features/*/data/`

**Dependencies:** Implements domain interfaces. Uses Supabase, local storage, mappers.

**Responsibility:** Network calls, local persistence, DTO/model serialization, concrete repository implementations.

**Contents:**

| Component | Purpose | Example |
|-----------|---------|---------|
| **Data Sources** | Direct Supabase queries; one file per source | `SupabaseCityDataSource` (read), `HoldingsApi` (write) |
| **Models/DTOs** | JSON ↔ Dart serialization | `AppUserModel.fromJson()` |
| **Repositories (impl)** | Concrete repository combining data sources | `CityRepositoryImpl`, `HoldingsRepository` |
| **Mappers** | Specific transformations (row → entity) | `holdingRowToParcel()`, `parcelToAddedHoldingsRecord()` |
| **Stores** | Local persistence abstraction | `ParcelEditsStore` (JSON file I/O) |

**Key Classes:**

**`SupabaseCityDataSource`:**
- Only file that queries Supabase directly for city/holdings/edits.
- Handles pagination (1000-row limit).
- Fetches multiple tables and merges locally (holdings + edits + added_holdings + counts).

**`HoldingsApi`:**
- All write operations: edit, bulk-edit, add-record, mark-reviewed.
- 15-second timeout per request (converts hung connections into user-visible errors).
- No retry logic (online-first).

**`HoldingsRepository`:**
- Owns in-memory dataset for active city.
- Merges corrections on load via `ParcelEditOverlay`.
- Exposes search, detail, bulk-edit, add/delete operations.
- Updates happen server-first (await HoldingsApi call), then local state.

**`ParcelEditsStore`:**
- Persists local edit overlays to JSON file.
- Keyed per city (e.g., `city::${cityId}`).
- Loads on city activation; reapplies on fresh download.

**`RealtimeSyncService`:**
- Subscribes to Supabase Realtime for holdings/holding_edits/added_holdings.
- Patches incoming changes into `HoldingsRepository` incrementally.
- Filters by active city.

**Design Principles:**
- One data source per remote service (clear I/O boundary).
- Models have `fromJson` / `toJson` but are often discarded after mapping to domain entities.
- Repositories are thin coordinators (not god-classes).
- All error handling via `ErrorHandler.handleException()` → `Failure` value type.

---

### 2.3 Presentation Layer

**Location:** `lib/features/*/presentation/`

**Dependencies:** Domain interfaces only; never imports `data/`.

**Responsibility:** UI state management (cubits), screens, widgets, user interaction.

**Contents:**

| Component | Purpose | Example |
|-----------|---------|---------|
| **Cubits** | State machine; emits state changes | `SessionCubit`, `SearchCubit` |
| **Screens** | Full-screen UI; container component | `HomeScreen`, `LoginScreen` |
| **Widgets** | Reusable UI; presentational | `ParcelDetailCard`, `BorderCompass` |

**Key Cubits:**

**`SessionCubit`:**
- Listens to Supabase Auth state.
- Emits `authenticated`/`unauthenticated`.
- Router redirects on state change.

**`SearchCubit`:**
- Queries active dataset via `HoldingsReader.search()`.
- Emits search results, selected basin, filters.

**`AppSettingsCubit`:**
- Persists font/theme preference.
- Emits theme state for app-wide MaterialApp theme.

**Key Screens:**
- **`LoginScreen`**: Email/password input; Supabase Auth.
- **`CityPickerScreen`**: Lists published cities; downloads selected; shows progress.
- **`HomeScreen`**: Search interface; basin filter; search results; detail navigation.
- **`HoldingDetailScreen`**: Parcel details; inline field edits; copy-all; add-parcel; borders navigation.
- **`AddRecordScreen`**: Form to create new person or new parcel; validation; submit.

**Key Widgets:**
- **`ParcelDetailCard`** (~500 lines): Largest widget; renders one parcel with all fields; handles inline edits; copy-all button; is_inheritance/is_delegate prefix logic.
- **`BorderCompass`**: Visual 4-way compass showing border names; tappable to navigate to referenced person.
- **`SyncStatusBadge`**: Shows pending operation count, last-sync time, manual sync button.

**Design Principles:**
- Cubits are pure state machines (no business logic).
- Screens are thin composition layers; don't render much directly.
- Widgets are stateless; state flows down, events bubble up.
- RTL/Arabic support built in (MaterialApp `locale` setting).

---

## 3. Data Flow Patterns

### 3.1 City Download & Activation
```
CityPickerScreen (user selects city)
  │
  ├─► CityPickerCubit.downloadAndActivate(city)
  │   │
  │   ├─► CityRepository.downloadCity(city)
  │   │   │
  │   │   ├─► SupabaseCityDataSource.downloadHoldings(city.id)
  │   │   │   (Fetches: holdings + holding_edits_latest + added_holdings + counts)
  │   │   │
  │   │   ├─► CitySnapshotCache.save(snapshot)
  │   │   │   (Writes JSON to disk via path_provider)
  │   │   │
  │   │   └─► Return CitySnapshot
  │   │
  │   ├─► HoldingsRepository.loadParcelsForCity(snapshot.parcels, ...)
  │   │   │
  │   │   ├─► Load local edits from ParcelEditsStore
  │   │   ├─► Apply edits via ParcelEditOverlay.apply()
  │   │   ├─► Emit updated _parcels
  │   │   │
  │   │   └─► Subscribe to Realtime (RealtimeSyncService.subscribeToCity)
  │   │
  │   └─► Emit success state
  │
  └─► Router navigates to HomeScreen
```

### 3.2 Search Flow
```
HomeScreen (user types search query)
  │
  ├─► SearchCubit.search("محمد علي", basinName: "السرو")
  │   │
  │   ├─► ParcelQueryService.search(_parcels, query, basin)
  │   │   │
  │   │   ├─► HoldingSearchService.search(scope, query)
  │   │   │   │
  │   │   │   ├─► Normalize query (Arabic): remove diacritics, etc.
  │   │   │   ├─► Rank by (holderName, nationalId, holding_id_number)
  │   │   │   │   (Arabic substring matching with ranking)
  │   │   │   │
  │   │   │   └─► Return [SearchResult] sorted by score
  │   │   │
  │   │   └─► Return results
  │   │
  │   └─► Emit ResultsState(results: [...]
  │
  └─► UI renders results as tappable list
      (On tap → navigate to HoldingDetailScreen)
```

### 3.3 Inline Field Edit Flow
```
HoldingDetailScreen (user edits one field inline)
  │
  ├─► ParcelDetailCard.onFieldChanged(cropType: "قمح")
  │   │
  │   ├─► HoldingsRepository.updateParcel(parcel.copyWith(...))
  │   │   │
  │   │   ├─► HoldingsApi.editHolding(holdingId, {crop_type: "قمح"})
  │   │   │   │
  │   │   │   ├─► INSERT INTO holding_edits (...)
  │   │   │   ├─► (Trigger fires: bump city version)
  │   │   │   ├─► (Realtime event: fire to all connected clients)
  │   │   │   │
  │   │   │   └─► Success
  │   │   │
  │   │   ├─► Update _parcels[idx] locally
  │   │   ├─► Persist to ParcelEditsStore (overlay cache)
  │   │   ├─► Emit state change
  │   │   │
  │   │   └─► Return updated parcel
  │   │
  │   └─► HomeCubit/DetailCubit emits new state
  │
  └─► UI re-renders with new value
```

### 3.4 Realtime Update Flow
```
Another user (on different device) edits same parcel
  │
  ├─► Supabase INSERT to holding_edits
  │
  └─► Realtime event fires on this device
      │
      ├─► RealtimeSyncService._handleHoldingEditPayload()
      │   │
      │   ├─► HoldingsRepository.applyRemoteEdit(holdingId, payload)
      │   │   │
      │   │   ├─► Find parcel by id
      │   │   ├─► Apply edit via ParcelEditOverlay
      │   │   ├─► Replace in _parcels
      │   │   │
      │   │   └─► Fire _remoteChangesController.add(null)
      │   │
      │   └─► (In parallel, any cubit listening to onRemoteChange receives notification)
      │
      └─► HomeCubit/DetailCubit (if listening) re-emits state
          │
          └─► UI re-renders
```

### 3.5 Add New Person Flow
```
HomeScreen (search finds nothing)
  │
  ├─► Show "إضافة بيانات جديدة" button
  │
  └─► User taps → Navigate to AddRecordScreen
      │
      ├─► AddRecordScreen (form with defaults from Parcel constructor)
      │   │
      │   ├─► User fills form (all fields editable)
      │   │   holding_id_number: "-1" (placeholder, since unassigned)
      │   │   holder_name: "محمد علي"
      │   │   ...
      │   │
      │   ├─► User taps save
      │   │
      │   └─► Validate (all required fields filled)
      │       │
      │       ├─► HoldingsRepository.addLocalParcel(parcel)
      │       │   │
      │       │   ├─► Generate Parcel.id = uuid v4
      │       │   ├─► Add to _parcels
      │       │   ├─► Emit state (parcel now visible in search/detail)
      │       │   │
      │       │   └─► HoldingsApi.addRecord(id, {parcel fields...})
      │       │       │
      │       │       ├─► INSERT INTO added_holdings (id, client_id, ...)
      │       │       ├─► (Trigger: auto-promote to holdings)
      │       │       ├─► (Realtime: event fires for both added_holdings INSERT and holdings INSERT)
      │       │       │
      │       │       └─► Return promoted_holding_id
      │       │
      │       └─► Realtime syncs back
      │           │
      │           ├─► added_holdings INSERT received
      │           │   → promoted_holding_id is set
      │           │   → Treated as DELETE (superseded)
      │           │
      │           └─► holdings INSERT received
      │               → New row added (replaces added_holdings)
      │
      └─► Pop to HomeScreen; parcel now appears under new person's name
```

### 3.6 Bulk Edit Flow
```
HomeScreen (user selects bulk-edit mode)
  │
  ├─► User selects crop_type, selects field (e.g., crop_type: "قمح")
  │
  ├─► User selects multiple parcels (checkboxes)
  │
  └─► User taps "Apply"
      │
      ├─► SearchCubit.bulkApplyField(field, value, selectedParcels)
      │   │
      │   ├─► BulkEditService.apply(field, value, parcels)
      │   │   │
      │   │   ├─► For each parcel: generate new Parcel with updated field
      │   │   └─► Return Map<holdingId, updatedParcel>
      │   │
      │   ├─► HoldingsRepository.bulkApplyField(...)
      │   │   │
      │   │   ├─► HoldingsApi.bulkEditHoldings(
      │   │   │       payloadsByHoldingId: {id1: {crop_type: "قمح"}, id2: {...}, ...}
      │   │   │   )
      │   │   │   │
      │   │   │   ├─► For each holding:
      │   │   │   │   INSERT INTO holding_edits (...)
      │   │   │   │   (on error, collect failed ids, continue)
      │   │   │   │
      │   │   │   └─► Return List<failedIds>
      │   │   │
      │   │   ├─► Update _parcels locally (replace affected parcels)
      │   │   ├─► Persist edits to ParcelEditsStore
      │   │   │
      │   │   └─► Return BulkEditOutcome(succeeded: N, failed: M)
      │   │
      │   └─► Emit state (success or partial failure)
      │
      └─► Show "مطبق على N حيازة" toast
```

---

## 4. State Management

### Architecture
- **Framework:** Flutter BLoC library (bloc, flutter_bloc, hydrated_bloc)
- **State Immutability:** All states immutable; `copyWith` for updates
- **Single Source of Truth:** One cubit per feature concern

### Key Cubits

**`SessionCubit`** (auth/session_cubit.dart):
```dart
abstract class SessionState {}
class UnauthenticatedState extends SessionState {}
class AuthenticatedState extends SessionState {
  final AppUser user;
}
class SessionLoadingState extends SessionState {}
class SessionErrorState extends SessionState {
  final String message;
}
```
- Listens to `Supabase.instance.auth.onAuthStateChanged` stream.
- Emits state on sign in/out.
- Router uses this to gate navigation.

**`SearchCubit`** (holdings/search_cubit.dart):
```dart
class SearchState {
  final List<SearchResult> results;
  final String query;
  final String? selectedBasin;
  final bool isLoading;
  final String? error;
}
```
- Listens to user search input (debounced).
- Queries `ParcelQueryService`.
- Emits results as user types.

**`AppSettingsCubit`** (core/settings_cubit.dart):
```dart
class AppSettingsState {
  final bool isDarkMode;
  final AppFontSize fontSize;
}
```
- Persists to SharedPreferences via `hydrated_bloc`.
- Emits theme state for root MaterialApp.

---

## 5. Dependency Injection

### Setup: `lib/core/di/dependency_injection.dart`
```dart
final GetIt getIt = GetIt.instance;

Future<void> setUpDependencies() async {
  await registerCoreModule(getIt);
  registerAuthModule(getIt);
  registerSyncModule(getIt);
  registerHoldingsModule(getIt);
  registerCitiesModule(getIt);
}
```

### Module Pattern
Each module registers related dependencies:

**`core_module`:**
- `KeyValueStore` (SharedPreferences wrapper)
- `NetworkInfo` (internet connection checker)
- `SecureStorage` (flutter_secure_storage)
- `VoiceSearchService` (speech_to_text)

**`auth_module`:**
- `SupabaseAuthRepository` (impl)
- `SessionCubit`

**`cities_module`:**
- `SupabaseCityDataSource`
- `CitySnapshotCache`
- `CityRepositoryImpl`

**`holdings_module`:**
- `HoldingsApi`
- `HoldingsRepository`
- `ParcelQueryService`
- `BulkEditService`
- `ClipboardFormatter`
- `BorderNameIndex`

**`sync_module`:**
- `RealtimeSyncService`

### Lazy Singletons
All dependencies registered as `GetIt.lazySingleton()`:
- Constructed on first access.
- Reused thereafter (no rebuilds).
- Circular dependencies resolved via getter functions (see `RealtimeSyncService`).

---

## 6. Routing & Navigation

### Router: `lib/core/router/app_router.dart`
Uses **GoRouter** (declarative, nested routing):

```dart
final router = GoRouter(
  routes: [
    GoRoute(path: Routes.login, builder: (_, __) => LoginScreen()),
    GoRoute(path: Routes.cityPicker, builder: (_, __) => CityPickerScreen()),
    GoRoute(path: Routes.home, builder: (_, __) => HomeScreen()),
    GoRoute(
      path: Routes.holdingDetail,
      builder: (_, state) => HoldingDetailScreen(id: state.extra as String),
    ),
    GoRoute(path: Routes.addRecord, builder: (_, __) => AddRecordScreen()),
    GoRoute(path: Routes.aboutScreen, builder: (_, __) => AboutScreen()),
  ],
  redirect: (_, state) {
    // Route guard: require auth for most routes
    if (!isAuthenticated && state.path != Routes.login) {
      return Routes.login;
    }
    return null;
  },
);
```

### Route Strings (lib/core/router/routes.dart)
```dart
class Routes {
  static const String login = '/login';
  static const String cityPicker = '/cityPicker';
  static const String home = '/home';
  static const String holdingDetail = '/holdingDetail';
  static const String addRecord = '/addRecord';
  static const String aboutScreen = '/aboutScreen';
  static const String fileStatus = '/fileStatus';
  static const String manageCities = '/manageCities';
}
```

### Navigation Patterns
- **Push:** `context.push(Routes.holdingDetail, extra: parcelId)`
- **Replace:** `context.replace(Routes.login)` (on logout)
- **Guard:** Router's `redirect` callback checks auth state before routing

---

## 7. Error Handling

### Failure Value Type: `lib/core/errors/failure.dart`
```dart
abstract class Failure {
  final String message;
}
class NetworkFailure extends Failure {}
class AuthenticationFailure extends Failure {}
class NotFoundFailure extends Failure {}
class ServerFailure extends Failure {}
// ... more types
```

### Central Handler: `lib/core/errors/error_handler.dart`
```dart
class ErrorHandler {
  static void handleException(dynamic error) {
    if (error is SupabaseException) {
      // → SupabaseHandler.handle()
    } else if (error is DioException) {
      // → DioHandler.handle()
    } else {
      // Generic error
    }
    // Throws Failure (which is caught at use-case/cubit level)
  }
}
```

### Result Type (Conceptual, not yet used consistently)
```dart
// NOT YET IMPLEMENTED, but intended for use cases:
// Result<T, Failure> = Success<T> | Failure
// Use cases return Result, cubits unwrap and emit state
```

### Current Pattern
- Network calls in data sources throw exceptions.
- `ErrorHandler.handleException()` catches and converts to `Failure`.
- Caller catches `Failure` and emits error state.
- UI shows error message (Arabic).

---

## 8. Localization

### Framework: `easy_localization` (Arabic default, English fallback)

### Setup: `lib/core/localization/localization_manager.dart`
```dart
EasyLocalization(
  supportedLocales: [Locale('ar'), Locale('en')],
  locale: Locale('ar'),  // Default to Arabic, RTL
  fallbackLocale: Locale('en'),
  path: 'assets/lang',
  child: MaterialApp(...),
)
```

### Translation Files
- `assets/lang/ar.json` (Arabic, RTL)
- `assets/lang/en.json` (English, LTR)

### Usage
```dart
Text('field_name'.tr())  // Looks up in current locale's JSON
```

### Known Gap
- Many older widgets hardcode Arabic strings instead of using `.tr()`.
- This is documented as tech debt (not a pattern to copy in new code).

---

## 9. Models & Entities

### Parcel (445 lines): Core Entity
```dart
class Parcel {
  final String id;                    // UUID (stable across app/db/edits)
  final String holdingId;             // رقم الحيازة
  final String? holder_name;          // حائز
  final double? feddan;               // فدان (area)
  final String? basinName;            // اسم الحوض
  final bool reviewed;                // Marked as complete
  final bool isFieldAdded;            // Field-created record?
  
  // ... 30+ more fields (see full file for complete list)
  
  Parcel copyWith({...});            // Immutable replacement
  Map<String, dynamic> toJson();     // Full snapshot
  Map<String, dynamic> toEditableJson(); // Corrections only
  Parcel.fromJson(...);
  Parcel.fromEditableJson(...);
}
```

**Key Getters:**
- `groupKey`: For grouping "one holding"; handles pending-record ambiguity
- `isHoldingIdPending`: Whether رقم الحيازة is still a placeholder
- `isValueFilled(value)`: Shared validation rule for "field has a real value"

### City (52 lines)
```dart
class City {
  final String id;
  final String name;
  final CityStatus status;           // draft | published | archived
  final int dataVersion;             // Staleness signal
  final AssociationType? associationType; // agricultural_credit | agricultural_reform
}
```

### CitySnapshot (locally cached)
```dart
class CitySnapshot {
  final String cityId;
  final String cityName;
  final List<Parcel> parcels;        // Merged: holdings + edits + added_holdings
  final int dataVersion;             // For staleness check
  final DateTime downloadedAt;
  // ...
}
```

### AppUser
```dart
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;               // admin | editor | viewer | field
}
```

---

## 10. Search & Query Services

### ParcelQueryService: Pure Search Logic
```dart
class ParcelQueryService {
  List<SearchResult> search(List<Parcel> parcels, String query, {String? basin}) {
    // Filter by basin if given
    final List<Parcel> scope = basin != null
        ? parcels.where((p) => p.basinName == basin).toList()
        : parcels;
    
    // Delegate to HoldingSearchService (Arabic-aware ranking)
    return _searchService.search(scope, query);
  }
  
  List<String> availableBasins(List<Parcel> parcels) { ... }
  Map<String, int> basinHoldingCounts(List<Parcel> parcels) { ... }
  List<Parcel> parcelsForHolding(List<Parcel> parcels, String groupKey) { ... }
}
```

### HoldingSearchService: Arabic Normalization & Ranking
```dart
class HoldingSearchService {
  List<SearchResult> search(List<Parcel> parcels, String query) {
    final normalized = ArabicNormalizer.normalize(query);
    
    // Rank by:
    // 1. Exact match holderName
    // 2. Substring match holderName
    // 3. Exact/substring match nationalId or holdingId
    
    // Return sorted by score, then by name
  }
}
```

### BorderNameIndex: O(1) حدود Lookup
```dart
class BorderNameIndex {
  // Precomputed index:
  // "محمد علي" → Parcel.id (the holding that person refers to)
  // "ورثة محمد" → Parcel.id
  // (Handles ambiguity; builds once per dataset load)
  
  Parcel? findByBorderText(String borderText) {
    final normalized = ArabicNormalizer.normalize(borderText);
    return _index[normalized];
  }
}
```

---

## 11. Clipboard Formatting

### ClipboardFormatter: Copy-All Logic
```dart
class ClipboardFormatter {
  String formatForClipboard(Parcel parcel) {
    // Multi-line formatted string for copy-all:
    // اسم الحائز: محمد علي
    // الرقم القومي: 123...
    // ... (all fields)
    
    // Prefix logic: وراثة / مفوض
    // If isInheritance: "ورثة محمد" instead of just "محمد"
    // If isDelegate: "مفوض عنه محمد" instead of just "محمد"
  }
}
```

**Business Logic Matrix:**
```
| isInheritance | isDelegate | Prefix |
|---------------|------------|--------|
| false         | false      | (none) |
| true          | false      | ورثة   |
| false         | true       | مفوض عنه |
| true          | true       | ??? (unclear; covered by test) |
```

---

## 12. Complete Feature List

### Currently Supported Features

| Feature | Status | Entry Point | Key Classes |
|---------|--------|-------------|-------------|
| **Authentication** | ✅ Implemented | LoginScreen | SessionCubit, SupabaseAuthRepository |
| **City Download** | ✅ Implemented | CityPickerScreen | CityRepositoryImpl, SupabaseCityDataSource |
| **Search** | ✅ Implemented | HomeScreen | SearchCubit, ParcelQueryService, HoldingSearchService |
| **Basin Filter** | ✅ Implemented | HomeScreen | ParcelQueryService.availableBasins() |
| **Detail View** | ✅ Implemented | HoldingDetailScreen | ParcelDetailCard widget |
| **Inline Edit** | ✅ Implemented | ParcelDetailCard | HoldingsApi.editHolding(), HoldingsRepository.updateParcel() |
| **Copy-All** | ✅ Implemented | ParcelDetailCard | ClipboardFormatter.formatForClipboard() |
| **Bulk Edit** | ✅ Implemented | HomeScreen (mode) | BulkEditService, HoldingsApi.bulkEditHoldings() |
| **Add New Person** | ✅ Implemented | AddRecordScreen | HoldingsRepository.addLocalParcel(), HoldingsApi.addRecord() |
| **Add Parcel (existing person)** | ✅ Implemented | HoldingDetailScreen | HoldingsRepository.addLocalParcel(parentHoldingId=...) |
| **Borders Navigator** | ✅ Implemented | ParcelDetailCard (BorderCompass) | BorderNameIndex.findByBorderText() |
| **Realtime Updates** | ✅ Implemented | (background) | RealtimeSyncService |
| **Staleness Check** | ✅ Implemented | App open | CityRepository.remoteDataVersion() |
| **Mark Reviewed** | ✅ Implemented | Detail screen | HoldingsApi.markReviewed() |
| **Settings (font/theme)** | ✅ Implemented | SettingsSheet | AppSettingsCubit |
| **Offline Support** | ⚠️ Partial | (cache/edits) | ParcelEditsStore, CitySnapshotCache |
| **Voice Search** | ✅ Implemented | HomeScreen | VoiceSearchService |

### Not Yet Implemented

| Feature | Why | Planned Phase |
|---------|-----|---------------|
| **Sync Outbox** | Online-first design; no queue | Phase 3 (if going local-first) |
| **Conflict Resolution UI** | Rare (single team per city) | Phase 6 |
| **Export to Excel** | Dashboard feature | (dashboard repo) |
| **Person Grouping UI** | person_id added recently; UI pending | TBD |
| **Unreviewed Filter** | Data model ready; UI not wired | TBD |

---

## 13. Current Business Rules (Implicit in Code)

### City & Downloads
1. Only `status='published'` cities are offered to field app (enforced by RLS + query filter).
2. City download is one operation: holdings + edits + approved added_holdings + counts in one round-trip.
3. Staleness check happens on app open (fetch city.data_version, compare with cached snapshot).
4. Re-download on stale prompted by banner (not automatic; respects metered connections).

### Parcels & Holding Identity
5. One `Parcel` row = one row of land data; multiple rows can share same رقم الحيازة (holding ID).
6. Search/grouping by `groupKey` (not raw holding_id_number): pending records group by unique id to prevent merge.
7. Brand-new person has `holding_id_number = "-1"` (placeholder) until dashboard assigns official number.
8. "Add parcel to person" copies all fields from parent except area (feddan/qirat/sahm) and land_number (defaults to "-1").

### Edits & Corrections
9. Corrections stored append-only in `holding_edits` table (never update/delete).
10. Merge on download: fetch original holding row, overlay latest edit from `holding_edits_latest`.
11. Merge on edit: if edit already exists for same holding, new edit replaces it (last-write-wins by client_edited_at).
12. App does NOT persist edits locally while offline (online-first); failed POST throws error.
13. Locally, edits are overlaid via `ParcelEditOverlay.apply(original, snapshot)` from `ParcelEditsStore` (JSON file per city).

### Field-Added Records
14. New persons/parcels created by field worker go to `added_holdings` table, not `holdings`.
15. `added_holdings` row has `client_id` unique constraint for idempotent sync (retry-safe).
16. Dashboard-approved records auto-promoted to `holdings` (trigger inferred; Realtime event fires).
17. Once promoted, original `added_holdings` row is superseded; app ignores it (realtime handler filters by `promoted_holding_id is null`).

### Credit/Reform Types
18. City's `association_type` (from `cities` table) gates which credit/reform options shown in app.
19. `credit_type` (ملك/أوقاف) only shown for `agricultural_credit` cities.
20. `reform_type` (إصلاح variants) only shown for `agricultural_reform` cities.
21. `usage_type` (زراعة/مباني/etc.) and `is_inheritance`/`is_delegate` always shown (not gated).

### Copy-All & Prefixes
22. Copy-all groups by basin (or all if no basin filter active).
23. Prefix rules:
    - If `is_inheritance=true`: prepend "ورثة" to holder name.
    - If `is_delegate=true`: prepend "مفوض عنه" to holder name.
    - If both: behavior unclear (see test for exact rule).

### Reviewed Status
24. Field worker can mark a parcel `reviewed=true` (separate from edits; direct UPDATE).
25. Reviewed status is per-parcel, not per-holding.
26. Dashboard can see reviewed status; may use for "export only reviewed" reports.

### Search
27. Search query normalized (Arabic diacritics removed).
28. Ranked by: exact holder name match > substring match > national ID > holding ID.
29. Can narrow to basin (filter, then search within).
30. No full-text index (yet); ranking is in-memory per city.

### Borders
31. Border text (الحدود) is unstructured; matched against holder/owner names by exact (normalized) string match.
32. Match is O(1) via `BorderNameIndex` built once per dataset load.
33. No fuzzy matching; ambiguous names resolve by first match.

---

## 14. Architecture Problems & Limitations

### Read-Only Observations (Not to be Fixed)

1. **No Persistent Sync Queue**
   - App is online-first; failed writes throw error immediately.
   - No retry queue; no backoff.
   - If user is offline, edits cannot be saved (network call fails).
   - Acceptable for field workflow (works when internet present); not ideal for areas with spotty connection.

2. **Realtime Subscription per City Only**
   - Only one city can be active at a time (RealtimeSyncService unsubscribes on switch).
   - Design matches offline-work model; no simultaneous multi-city sync.
   - Scalable up to ~1-2 devices per field worker; not a distributed team.

3. **Edit Idempotency at Client Level Only**
   - `holding_edits` table has no unique constraint on (holding_id, edited_by, edited_at).
   - Idempotency relies on app logic (don't re-send same timestamp).
   - If client crashes mid-send, retry may insert duplicate rows with same payload.
   - **Low risk:** Duplicates just re-apply same edit; merge logic handles it.

4. **No Conflict Detection**
   - Last-write-wins by timestamp (client_edited_at or server edited_at).
   - No warning if multiple users edit same field concurrently.
   - Acceptable assumption: single team per city, unlikely collisions.

5. **Soft FK in `holding_edits.holding_id`**
   - Can point to `holdings.id` OR `added_holdings.id`; database cannot enforce this.
   - App validates (lookup before insert); database is not a guardian.
   - Future: split into two edit tables or add `holding_type` column.

6. **Local Edit Overlay Cache Unbounded**
   - `ParcelEditsStore` persists one JSON file per city with all edits.
   - No cleanup; file grows as edits accumulate.
   - For a city with 1,000 parcels and 10 edits each, ~50 KB JSON.
   - Not a problem at current scale; could become issue at scale (add pruning logic later).

7. **No Undo/Redo in Detail Screen**
   - `FieldChangeTracker` exists but unused.
   - Edits are immediate; no UI undo button.
   - User can re-edit to revert (acceptable).

8. **Bulk Edit Cannot Be Partially Undone**
   - Bulk edit applies N times, returns count of successes/failures.
   - Failed edits are not rolled back (intentional: independence per holding).
   - User must manually re-edit failed ones.

9. **Arabic Normalization Incomplete**
   - `ArabicNormalizer` removes diacritics and some variants (e.g., ة → ه).
   - May miss some edge cases (e.g., zero-width joiners, rare ligatures).
   - Good enough for typical use; not a full Arabic NLP library.

10. **Search Index Not Persistent**
    - `BorderNameIndex` rebuilt every time parcels are reloaded.
    - O(n) construction cost; happens at app load and on every realtime batch update.
    - For 1,000 parcels, negligible; at 10k+, might be noticeable.
    - Could add caching (rebuild only on parcel structure change, not on edit values).

11. **No Download Progress for Large Cities**
    - City download shows generic "loading" spinner.
    - No per-batch progress (e.g., "fetching 1,200 holdings...").
    - For slow connections, feels stuck even though it's working.

12. **Pagination Hardcoded to 1,000 Rows**
    - `SupabaseCityDataSource` uses fixed 1,000-row page size (PostgREST limit).
    - If a city has > 1,000 holdings, pagination kicks in (automatic).
    - Works; could be tuned (trade memory for fewer trips).

13. **No Re-sync on App Resume**
    - Realtime subscription persists on app pause/resume.
    - If device sleeps for hours, connection may be stale.
    - On resume, Realtime auto-reconnects (handled by supabase_flutter).
    - Edge case: very long sleep, connection dropped, resumption late to reconnect.

14. **Edited Parcel IDs Not Stable for `added_holdings`**
    - Comment in `SupabaseCityDataSource.downloadHoldings()` flags: edits to `added_holdings` records fail until promoted.
    - `holding_edits.holding_id` is FK'd to `holdings.id` only, not `added_holdings.id`.
    - Editing a pending field record (before promotion) will fail.
    - Workaround: dashboard must review/approve records before field edits can stick.

15. **No Offline Add/Edit**
    - Add/edit both require immediate network POST.
    - If offline, operation fails with error.
    - Acceptable for "save edits" (can retry when online); not ideal for "new record" (requires re-entry if offline).

16. **No Metered Connection Prompt**
    - App does NOT check `NetworkInfo` before re-download.
    - Banner prompts "تحديث البيانات" without warning about data usage.
    - User may incur surprise charges on metered mobile.
    - Workaround: manual refresh only when on WiFi (not foolproof).

17. **No Multi-Parcel Edit**
    - Bulk edit changes one field across many holdings.
    - Cannot change multiple fields at once for same holding from UI.
    - Requires sequential inline edits (acceptable; mirrors form workflow).

18. **Missing `reform_type` in `added_holdings` Schema**
    - `added_holdings` table lacks `reform_type` column (migration 007 shows only `credit_type`).
    - Field form for reform city shows `reform_type` picker; value not persisted.
    - Re-download loses it; must re-enter on next load.
    - Bug; should add column in future migration.

19. **No Validation on `person_id` Grouping**
    - `person_id` is free-form UUID; app just copies it from parent on "add parcel".
    - No CHECK constraint or RLS policy ensuring all rows with same `person_id` have same `holding_id_number`.
    - Could lead to nonsensical groupings (e.g., person has multiple different holding IDs).
    - Workaround: dashboard review + manual correction if needed.

20. **No Soft-Delete for Parcels**
    - Delete is hard DELETE (removes row).
    - No archive/trash/is_deleted flag.
    - Once deleted, cannot recover (except via DB backup).
    - Workaround: don't offer delete UI; only dashboard can remove via data correction.

21. **`holdings` feature uses `logic/`+`ui/`, every other feature uses `presentation/`** (found
    2026-08-06 planning audit)
    - `holdings` is the only feature split into `data/logic/ui` instead of `data/domain/presentation`.
    - No functional impact, but breaks the "one convention" assumption the rest of this document (and
      `REFACTOR_ROADMAP.md` Phase 8) makes.
    - Tracked in `REFACTOR_ROADMAP.md` Phase 8 (project-wide feature-parity pass).

22. **`lib/features/sync/presentation/` is a completely empty directory** (found 2026-08-06 planning
    audit)
    - Zero files inside it; dead structure left over from an earlier design, not cleaned up.
    - Tracked in `REFACTOR_ROADMAP.md` Phase 8.

---

## 15. Code Smells & Refactor Opportunities

### Without Changing Behavior

1. **`ParcelDetailCard` is 500+ lines**
   - Too large; should split into smaller presentational widgets (fields, borders, actions).
   - Refactor: extract `ParcelFieldSection`, `ParcelBordersSection`, `ParcelActionsSection` as separate widgets.

2. **HoldingsRepository is 300+ lines**
   - Coordinator for data loading, search, edit, bulk-edit, realtime, and local storage.
   - Could split into `HoldingsDataManager` (in-memory state) and `HoldingsOperations` (add/edit/delete).
   - Keep as-is if single-responsibility boundary is "manages active city dataset" (defensible).

3. **No Consistent Error Handling Pattern**
   - Some data sources throw exceptions, others return null.
   - No use of `Result<T, Failure>` type throughout (only partially).
   - Refactor: use Result type everywhere; unwrap at use-case/cubit boundaries.

4. **`ArabicNormalizer` Not Comprehensive**
   - Only removes diacritics and maps a few character variants (ة/ه).
   - Better: use `url_launcher` or a proper Arabic NLP library (if available).
   - For now, acceptable; document limitations.

5. **Realtime Subscription Coupling**
   - `RealtimeSyncService` tightly coupled to `HoldingsRepository` via getter function.
   - Circular dependency resolved via lazy singleton; could be cleaner.
   - Refactor: event-based subscription (emit "parcels changed" to a global stream instead of direct mutation).

6. **No Logging Framework**
   - Errors not logged to console/remote service.
   - Cannot diagnose production issues.
   - Refactor: add `logger` package; log all errors + major operations.

7. **Magic Strings Scattered**
   - Table names ("holding_edits", "added_holdings") appear in multiple files.
   - Should centralize in a `Tables` or `DatabaseConstants` class.

8. **No CI/CD Validation**
   - Tests exist but not gated (can merge failing tests).
   - Refactor: GitHub Actions to run `flutter test` + `flutter analyze` on PR.

9. **Fonts Hardcoded to Two Choices**
   - App switches between Manrope and Tajawal for font size; no design token system.
   - Refactor: extract font scale + family to theme configuration.

10. **Settings Cubit Not Testable**
    - Depends on SharedPreferences directly in constructor (via hydrated_bloc).
    - Refactor: inject KeyValueStore instead; mock in tests.

11. **No Immutability Enforcement**
    - Parcel is declared immutable (final fields) but no `@immutable` annotation.
    - Refactor: add `@immutable` to Parcel, City, all domain entities.

12. **Pagination Not Exposed to UI**
    - City download pages silently; no UI feedback.
    - Could show "Fetching page 2 of 3..." for transparency (not critical).

13. **Old Firebase Deps Still in pubspec.yaml**
    - Firebase dependencies listed but unused (target Phase 5 cleanup).
    - Current: firebase_core, firebase_auth, cloud_firestore, firebase_storage.
    - Refactor: remove all four + clean up handlers.

14. **Dio Interceptors Setup but Unused**
    - API consumer fully set up but Supabase takes precedence.
    - Refactor: delete dio_factory, api_consumer, api_interceptors (dead code).

15. **No Widget Testing for Large Widgets**
    - `ParcelDetailCard` has no widget tests.
    - Difficult to test without full app environment.
    - Refactor: add golden tests or snapshot tests for major widgets.

16. **Search Results Not Cached**
    - Every search keystroke re-searches entire dataset.
    - Fine for small cities; could memoize for large ones.
    - Refactor: cache search results per query; invalidate on parcel change.

17. **Enum String Conversion Scattered**
    - `cityStatusFromString()`, `userRoleFromString()` functions in entity files.
    - Refactor: centralize in `EnumParsers` or `EnumConverters` utility class.

18. **No Feature Flags**
    - No way to toggle features on/off without rebuild.
    - Could add `FeatureFlagsService` using environment or Supabase metadata.
    - Current: acceptable; no experiments running.

19. **No A/B Testing**
    - App has no telemetry; cannot measure adoption of new features.
    - Could add Firebase Analytics (but remove Firebase first per Phase 5).
    - Refactor: add Supabase-based analytics if needed.

20. **Color Palette Not Themeable**
   - Colors hardcoded per light/dark theme; no color variables or tokens.
   - Refactor: extract to theme.colorScheme or Material Design 3 tokens.

21. **`holdings`'s `logic/`+`ui/` split vs. every other feature's `presentation/`**
   - Real, confirmed naming drift (2026-08-06 audit), not just a stylistic nit — anyone reading this
     doc's §1 tree literally alongside the real `holdings` folder will find it doesn't match.
   - Refactor: pick one convention project-wide; tracked in `REFACTOR_ROADMAP.md` Phase 8.

22. **Empty `lib/features/sync/presentation/` directory**
   - Zero files; should be deleted outright, not merely renamed.
   - Tracked in `REFACTOR_ROADMAP.md` Phase 8.

---

## 16. Questions & Missing Information

1. **What is the exact `added_holdings_auto_promote` trigger logic?**
   - Does it fire on every INSERT or only when status='approved'?
   - Does it create the `holdings` row atomically or in a separate transaction?
   - Verify in production database.

2. **Is `reform_type` supposed to be persisted in `added_holdings`?**
   - Current schema has no column; form shows field.
   - Is this a bug or intentional (reform type added post-promotion only)?
   - Clarify with dashboard team.

3. **How is person_id assigned?**
   - When user creates "add parcel to person", who generates the person_id?
   - Is it copied from parent, or generated fresh?
   - Is there a person_id collision risk (two users add to same person concurrently)?

4. **What is the dashboard's approval workflow exactly?**
   - Are field records auto-approved on creation?
   - Or does dashboard staff explicitly change status from pending → approved?
   - Does approval trigger the promotion to `holdings`?

5. **How should `person_id` UI work?**
   - Should app show "Person #123" in detail screen?
   - Should user be able to merge two people (re-assign person_id)?
   - Currently there's no UI for person management.

6. **Is the `reviewed` status used for any business logic?**
   - Dashboard exports only reviewed parcels?
   - Affects sync/refresh behavior?
   - Or purely informational (data quality tracking)?

7. **How often should `city_top_holders` materialized view be refreshed?**
   - After every import?
   - Nightly cron job?
   - Manual (dashboard action)?
   - Currently no automation; dashboard must remember to refresh.

8. **Can a field user ever see draft cities via Realtime?**
   - Realtime subscription respects RLS (same as SELECT).
   - If city promoted from draft → published during user's session, do they auto-see it?
   - Or is subscription bound to published status at subscription time?

9. **What happens if app edits a holding before dashboard promotes `added_holdings`?**
   - `added_holdings` record created; not yet in `holdings`.
   - App tries to edit it (HoldingsApi.editHolding to `holding_edits`).
   - `holding_edits` FK'd to `holdings.id` only (no `added_holdings.id`).
   - Does this fail or silently drop?

10. **Should app support offline-first sync (local queue)?**
    - Currently online-first (fails if network unavailable).
    - Field workers in areas with sporadic connectivity need offline-first.
    - Phase 3 could add `SyncOutbox` (local queue + retry on reconnect).
    - Confirm if this is future scope.

11. **What is the corpus of test data?**
    - Real sample file exists (الدير_ائتمان_مجمع.xlsx with ~1,200 rows, real PII).
    - Trimmed test fixture used in tests?
    - Confirm fixture location and how to regenerate.

12. **How should the app handle re-login mid-session?**
    - Supabase token expires; should app auto-refresh or force re-login?
    - Current: no explicit handling; supabase_flutter may handle transparently.

13. **Does app support multiple cities in local cache?**
    - Can user download city A, then city B, then switch back to A?
    - Current: `CityRepository` caches all downloaded cities; one is "active".
    - UI support (`ManageCitiesScreen`) exists but path to access it is unclear.

---

## 17. Version & Dependencies

| Name | Version | Purpose |
|------|---------|---------|
| `flutter` | >=3.0.0 | Framework |
| `flutter_bloc` | ^9.1.1 | State management |
| `hydrated_bloc` | ^11.0.0 | Persistence (hydrated state) |
| `supabase_flutter` | ^2.16.0 | Backend (auth + database + realtime) |
| `easy_localization` | ^3.0.8 | i18n (Arabic/English) |
| `uuid` | ^4.5.1 | UUID generation |
| `url_launcher` | ^6.3.2 | Open URLs |
| `flutter_secure_storage` | ^10.3.1 | Encrypted storage |
| `shared_preferences` | ^2.5.5 | Key-value store |
| `path_provider` | ^2.1.6 | File system paths |
| `internet_connection_checker` | ^3.0.1 | Connectivity check |
| `speech_to_text` | ^7.4.0 | Voice search (Android) |
| `permission_handler` | ^12.0.3 | Runtime permissions |
| `flutter_dotenv` | ^6.0.1 | Environment variables |
| `equatable` | ^2.1.0 | Value equality |
| `get_it` | ^9.2.1 | Dependency injection |
| `google_fonts` | ^8.1.0 | Font loading |
| `flutter_screenutil` | ^5.9.3 | Responsive sizing |

**Unused (to be removed):**
- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` (phase 5)

---

## 18. Test Coverage

### Tested Components
- `ParcelQueryService` (search, basin filtering, lookups)
- `ParcelEditOverlay` (merge logic)
- `BulkEditService` (bulk apply)
- `ClipboardFormatter` (copy-all format)
- `ArabicNormalizer` (normalization)
- `CityRepositoryImpl` (download + cache)
- `SessionCubit` (auth state)
- `CityPickerCubit` (city selection)
- `HoldingRowMapper` (row → entity)
- Added holdings mapper

### Untested Components
- `ParcelDetailCard` (large widget; no widget tests)
- `HomeScreen` (integration; no E2E tests)
- `RealtimeSyncService` (realtime; mock Supabase needed)
- `HoldingsApi` (network; could mock)
- `VoiceSearchService` (platform-specific)

### Strategy
- Fakes over mocks for domain interfaces.
- Test fixtures using real Arabic data (e.g., from trimmed `الدير_ائتمان_مجمع.xlsx`).
- Target >= 90% coverage for domain services.

---

## 19. Build & Release

### Flavors
- `development`: Points to dev Supabase project; `.env` from .env file.
- `production`: Points to prod Supabase project; `.env` from environment.

### Build Commands
```bash
make dev       # flutter run --flavor development --target lib/main_dev.dart
make prod      # flutter run --flavor production --target lib/main_prod.dart
make test      # flutter test
make analyze   # flutter analyze
make format    # dart format lib/ test/
make generate  # dart run build_runner build
```

### Version
- Current: 1.1.2+2
- Naming: Semantic versioning (major.minor.patch + build).
- Update in `pubspec.yaml` before each release.

---

## 20. Known Issues & Tracked Bugs

1. **Missing `reform_type` Column in `added_holdings`**
   - Impact: Reform city field records lose reform_type on sync.
   - Status: Documented in DATABASE_REFERENCE.md § 13.
   - Fix: Add column to `added_holdings` in future migration.

2. **Soft FK in `holding_edits.holding_id`**
   - Impact: Can point to either `holdings.id` or `added_holdings.id`; no DB enforcement.
   - Status: Documented; app layer validates.
   - Fix: Split into two edit tables or add `holding_type` column.

3. **Realtime Subscription May Not Reconnect After Long Sleep**
   - Impact: Very old connections may not reconnect; stale data until manual refresh.
   - Status: Low risk (supabase_flutter handles auto-reconnect).
   - Fix: Add explicit "retry connection" button or periodical health check.

4. **ParcelDetailCard Too Large (500+ lines)**
   - Impact: Hard to test, maintain, extend.
   - Status: Works; refactoring deferred.
   - Fix: Split into smaller widgets (Phase 6+ refactoring).

5. **No Undo/Redo in Detail Screen**
   - Impact: User accidentally changes field; must manually revert.
   - Status: Acceptable (can re-edit).
   - Fix: Add undo button (low priority).

6. **Search Not Cached**
   - Impact: Large cities may feel sluggish on every keystroke.
   - Status: Acceptable at current scale.
   - Fix: Memoize search results (optimization, not critical).

---

## 21. Future Roadmap (From APP_PLAN.md)

| Phase | Focus | Gate |
|-------|-------|------|
| 0 | Refactor (no behavior change) | flutter analyze + flutter test ✓ |
| 1 | Supabase schema + RLS | RLS verified by hand ✓ |
| 2 | Auth + city download | Download works offline ✓ |
| 3 | Sync outbox (priority feature) | Edit → sync → appears on device B ✓ |
| 4 | Add new person / add parcel | Both workflows work with correct server rows ✓ |
| 5 | Retire Excel path | No file_picker / spreadsheet_decoder references |
| 6 | Hardening | Offline 24h with 20 queued ops → clean sync |

---

