# CLAUDE.md — HiyazaFinder Refactor
## Supabase Removal + New Feature Pattern

> **اقرأ الملف ده بالكامل قبل أي سطر كود.**
> ده المرجع الوحيد للـ refactor والـ pattern الجديد.
> أي قرار مش موجود هنا → اسأل الأول.

---

## 1. الهدف النهائي

```
BEFORE:
Flutter ←→ Supabase (writes, reads, realtime, auth, sync)
Pattern:   feature/domain/ + feature/data/ + feature/presentation/

AFTER:
Flutter → Supabase (download مرة واحدة فقط، HTTP GET)
Flutter → Local Storage (كل العمليات)
Pattern:  feature/data/ + feature/logic/ + feature/ui/
```

**المبادئ:**
- لا Auth نهائياً — App يبدأ على HomeScreen مباشرة
- لا Realtime نهائياً
- لا writes على Supabase نهائياً
- كل edits/adds = local only، جاهزة للـ export مستقبلاً
- الـ app يشتغل offline بعد أول download

---

## 2. الـ Pattern الجديد — القاعدة الأساسية

### هيكل كل feature

```
lib/features/<feature>/
├── data/
│   ├── model/              ← data classes, DTOs, enums
│   ├── remote/             ← HTTP data sources (network only)
│   ├── local/               ← local data sources (SharedPrefs, file cache)
│   └── repo/
│       ├── <x>_repo.dart        ← abstract interface
│       └── <x>_repo_impl.dart   ← concrete implementation
├── logic/
│   └── cubit/
│       ├── <x>_cubit.dart
│       └── <x>_state.dart
└── ui/
    ├── widgets/
    │   └── <widget_name>.dart   ← one widget per file
    └── <x>_screen.dart
```

### القواعد الصارمة للـ Pattern

```
✅ data/model/    → data classes فقط، pure Dart، zero Flutter
✅ data/remote/   → HTTP calls فقط، بـ http package، zero Supabase SDK
✅ data/local/    → SharedPreferences/file cache فقط
✅ data/repo/     → interface + implementation في نفس الـ folder
✅ logic/cubit/   → Cubit + State فقط، يعتمد على repo interface
✅ ui/            → Widgets + Screens فقط، تعتمد على logic فقط
✅ ui/widgets/    → كل widget في ملف منفصل، اسم واضح
❌ logic/ لا يعتمد على data/ مباشرة → دايماً عبر repo interface
❌ ui/ لا تعتمد على data/ مباشرة → دايماً عبر logic/cubit
❌ مفيش business logic في الـ screens → الـ screen بتعرض بس
❌ مفيش Supabase SDK في أي feature
```

---

## 3. Mapping — من الـ Pattern القديم للجديد

| القديم | الجديد |
|---|---|
| `domain/entities/` | `data/model/` |
| `domain/repositories/` (interface) | `data/repo/<x>_repo.dart` |
| `data/` (impl) | `data/repo/<x>_repo_impl.dart` |
| `data/services/` (remote) | `data/remote/<x>_remote_ds.dart` |
| `data/repository/` (local stores) | `data/local/<x>_local_ds.dart` |
| `presentation/cubit/` | `logic/cubit/` |
| `presentation/screens/` | `ui/` |
| `presentation/widgets/` | `ui/widgets/` |
| `domain/services/` (pure logic) | `data/local/` |

---

## 4. الـ Features بعد الـ Refactor

### 4.1 Feature: `cities`

```
lib/features/cities/
├── data/
│   ├── model/
│   │   ├── city.dart                  ← was: domain/entities/city.dart
│   │   ├── city_snapshot.dart         ← was: domain/entities/city_snapshot.dart
│   │   ├── cached_city_meta.dart      ← was: domain/entities/cached_city_meta.dart
│   │   └── association_type.dart      ← was: domain/entities/association_type.dart
│   ├── remote/
│   │   └── city_remote_ds.dart        ← NEW: HTTP GET only
│   ├── local/
│   │   └── city_snapshot_cache.dart   ← MOVE: was data/city_snapshot_cache.dart
│   └── repo/
│       ├── city_repo.dart             ← was: domain/repositories/city_repository.dart
│       └── city_repo_impl.dart        ← was: data/city_repository_impl.dart
├── logic/
│   └── cubit/
│       ├── city_cubit.dart            ← was: presentation/cubit/city_picker_cubit.dart
│       └── city_state.dart
└── ui/
    ├── widgets/
    │   ├── city_tile.dart
    │   ├── cached_city_tile.dart
    │   ├── city_list_states.dart
    │   ├── city_picker_loading_list.dart
    │   └── manage_cities_states.dart
    ├── city_picker_screen.dart
    ├── city_tools_screen.dart
    └── manage_cities_screen.dart
```

### 4.2 Feature: `holdings`

```
lib/features/holdings/
├── data/
│   ├── model/
│   │   ├── parcel.dart
│   │   ├── bulk_edit_outcome.dart
│   │   └── bulk_editable_field.dart
│   ├── local/
│   │   ├── arabic_normalizer.dart
│   │   ├── area_calculator.dart
│   │   ├── border_name_index.dart
│   │   ├── bulk_edit_service.dart
│   │   ├── clipboard_formatter.dart
│   │   ├── field_change_tracker.dart
│   │   ├── holding_search_service.dart
│   │   ├── parcel_dataset_state.dart
│   │   ├── parcel_edit_overlay.dart
│   │   ├── parcel_edits_store.dart
│   │   ├── parcel_mapper.dart          ← was: cities/data/holding_row_mapper.dart
│   │   ├── parcel_query_service.dart
│   │   ├── local_added_parcels_store.dart  ← NEW
│   │   └── local_edit_tracker.dart         ← NEW
│   └── repo/
│       ├── holdings_repo.dart              ← merged reader+writer interface
│       └── holdings_repo_impl.dart         ← was: data/repository/holdings_repository.dart
├── logic/
│   └── cubit/
│       ├── home_cubit.dart
│       └── home_state.dart
└── ui/
    ├── widgets/
    │   └── (all existing widgets moved here)
    ├── home_screen.dart
    ├── detail_screen.dart
    ├── add_record_screen.dart
    ├── file_status_screen.dart
    └── missing_holding_id_screen.dart
```

### 4.3 Feature: `crop_type` (جديدة مستقلة)

```
lib/features/crop_type/
├── data/
│   ├── local/
│   │   └── crop_type_local_ds.dart    ← SharedPreferences storage
│   └── repo/
│       ├── crop_type_repo.dart
│       └── crop_type_repo_impl.dart
├── logic/
│   └── cubit/ (اختياري)
└── ui/
    ├── widgets/
    │   └── crop_type_picker.dart      ← MOVE from holdings/widgets
    └── crop_type_settings_screen.dart ← MOVE from cities/screens
```

### 4.4 Feature: `about`

```
lib/features/about/
├── data/
│   └── about_constants.dart
└── ui/
    ├── widgets/
    │   ├── about_app_header.dart
    │   ├── about_flat_row.dart
    │   └── about_section_label.dart
    └── about_screen.dart
```

---

## 5. الـ Core Layer

```
lib/core/
├── config/
│   └── app_config.dart            ← يتعاد كتابته (شيل dotenv، أضف static consts)
├── di/
│   └── dependency_injection.dart  ← يتبسط
├── errors/
│   ├── error_handler.dart         ← يشيل Supabase-specific
│   ├── exceptions.dart            ← يفضل
│   └── failure.dart               ← يفضل
├── networking/
│   └── network_info.dart          ← يفضل (للـ download check)
├── router/
│   ├── app_router.dart            ← يشيل login route
│   └── routes.dart                ← يشيل login
├── service/
│   └── secure_storage.dart        ← يفضل
├── settings/cubit/                ← يفضل كما هو
├── storage/key_value_store.dart   ← يفضل كما هو
├── themes/                        ← يفضل كما هو
├── utils/                         ← يفضل كما هو
└── widgets/                       ← يفضل كما هو

❌ core/errors/handlers/supabase_handler.dart → يُحذف
❌ core/service/voice_search_service.dart     → يُحذف
```

---

## 6. ترتيب التنفيذ

### Phase 1 — حذف Auth + Sync + Packages  ✅ DONE

```
1.1 pubspec.yaml:
    ❌ supabase_flutter
    ❌ flutter_dotenv
    ✅ http: ^1.2.0

1.2 احذف:
    ❌ features/auth/ (كاملاً)
    ❌ features/sync/ (كاملاً)
    ❌ holdings/data/services/ (sync handlers)
    ❌ core/errors/handlers/supabase_handler.dart
    ❌ core/service/voice_search_service.dart

1.3 عدّل core/errors/error_handler.dart:
    ❌ شيل Supabase imports + SupabaseHandler.handle()
    ✅ فضّل generic error handling

1.4 عدّل core/config/app_config.dart:
    ❌ شيل dotenv
    ✅ static const supabaseUrl + supabaseAnonKey

Definition of Done:
□ flutter pub get بدون errors
□ مفيش supabase_flutter في أي ملف
□ مفيش flutter_dotenv في أي ملف
```

**ملاحظة تنفيذ:** الملفات الأساسية اتشالت (auth/، sync/، sync handlers، supabase_handler.dart،
voice_search_service.dart، app_config.dart القديم، .env من pubspec assets). لسه باقي: تنظيف
error_handler.dart من Supabase imports، وحذف auth_module.dart/sync_module.dart من DI (هيتعمل في
Phase 6 الجديد بدل ما كانوا في الخطة القديمة Phase 4، لأن الـ DI بيتلمس مرة واحدة بعد كل الـ
features تتنقل).

---

### Phase 2 — Restructure: `cities`

```
2.1 أنشئ folders: data/model/ + data/remote/ + data/local/ + data/repo/ + logic/cubit/ + ui/widgets/

2.2 انقل Models (domain/entities/ → data/model/):
    city.dart، city_snapshot.dart، cached_city_meta.dart، association_type.dart

2.3 انقل Local:
    data/city_snapshot_cache.dart → data/local/city_snapshot_cache.dart

2.4 انقل Repo:
    domain/repositories/city_repository.dart → data/repo/city_repo.dart
    data/city_repository_impl.dart           → data/repo/city_repo_impl.dart

2.5 أنشئ data/remote/city_remote_ds.dart:
    - http package فقط
    - listCities()، downloadHoldings(cityId)، getDataVersion(cityId)

2.6 احذف:
    ❌ data/supabase_city_data_source.dart
    ❌ data/crop_type_repository_impl.dart
    ❌ data/holding_row_mapper.dart (ينتقل لـ holdings في Phase 3)
    ❌ domain/ folder

2.7 انقل Logic + UI:
    presentation/cubit/ → logic/cubit/
    presentation/screens/ → ui/
    presentation/widgets/ → ui/widgets/
    ❌ احذف presentation/

Definition of Done:
□ مفيش domain/ في cities
□ مفيش presentation/ في cities
□ مفيش supabase import في cities
□ flutter analyze clean
```

---

### Phase 3 — Restructure: `holdings`

```
3.1 أنشئ folders: data/model/ + data/local/ + data/repo/ + logic/cubit/ + ui/widgets/

3.2 انقل Models (domain/entities/ → data/model/):
    parcel.dart، bulk_edit_outcome.dart، bulk_editable_field.dart

3.3 انقل Local Services (domain/services/ → data/local/):
    arabic_normalizer، area_calculator، border_name_index،
    bulk_edit_service، clipboard_formatter، field_change_tracker،
    holding_search_service، parcel_edit_overlay، parcel_query_service

3.4 انقل Local Stores:
    data/repository/parcel_edits_store.dart   → data/local/
    data/repository/parcel_dataset_state.dart → data/local/

3.5 انقل Mapper:
    cities/data/holding_row_mapper.dart → holdings/data/local/parcel_mapper.dart

3.6 أنشئ Local Stores الجديدة:
    data/local/local_added_parcels_store.dart
    data/local/local_edit_tracker.dart

3.7 أنشئ Repo:
    data/repo/holdings_repo.dart (merged reader+writer interface)
    data/repo/holdings_repo_impl.dart:
        ❌ احذف: Supabase/sync methods كلها
        ✅ فضّل: local-only operations

3.8 انقل Logic + UI:
    presentation/cubit/ → logic/cubit/
    presentation/screens/ → ui/
    presentation/widgets/ → ui/widgets/

3.9 احذف:
    ❌ domain/ folder
    ❌ presentation/ folder
    ❌ data/repository/ folder
    ❌ data/services/ folder

Definition of Done:
□ مفيش domain/ في holdings
□ مفيش presentation/ في holdings
□ LocalAddedParcelsStore يحفظ added parcels
□ LocalEditTracker يتتبع edits
□ flutter analyze clean
```

---

### Phase 4 — Feature جديدة: `crop_type`

```
4.1 أنشئ lib/features/crop_type/
4.2 أنشئ data/local/crop_type_local_ds.dart (SharedPreferences)
4.3 أنشئ data/repo/crop_type_repo.dart + crop_type_repo_impl.dart
4.4 انقل ui/crop_type_settings_screen.dart من cities
4.5 انقل ui/widgets/crop_type_picker.dart من holdings

Definition of Done:
□ Crop type settings شغالة
□ Custom types بتتحفظ locally
□ Fallback لـ static list شغال
```

---

### Phase 5 — Restructure: `about`

```
5.1 انقل presentation/about_screen.dart → ui/about_screen.dart
5.2 انقل presentation/widgets/ → ui/widgets/
5.3 احذف presentation/ folder

Definition of Done:
□ About screen شغالة
□ مفيش presentation/ في about
```

---

### Phase 6 — تنظيف Core + DI

```
6.1 احذف:
    ❌ core/di/modules/auth_module.dart   ✅ DONE (Phase 1 أثناء التنفيذ)
    ❌ core/di/modules/sync_module.dart   ✅ DONE (Phase 1 أثناء التنفيذ)

6.2 عدّل core_module.dart:
    ❌ شيل InternetConnectionChecker، VoiceSearchService
    ✅ أضف http.Client

6.3 عدّل cities_module.dart:
    ❌ شيل SupabaseCityDataSource، Supabase.instance.client
    ✅ أضف CityRemoteDataSource، CropTypeRepoImpl
    ✅ new import paths

6.4 عدّل holdings_module.dart:
    ❌ شيل SyncRunner.registerHandler calls
    ❌ شيل HoldingsApi، RealtimeSyncService، ParcelSyncService
    ✅ أضف LocalAddedParcelsStore، LocalEditTracker
    ✅ new import paths

6.5 عدّل dependency_injection.dart:
    ❌ شيل registerAuthModule، registerSyncModule
    ❌ شيل SyncRunner restore/flush
    ✅ core + cities + holdings + crop_type فقط

6.6 عدّل app_router.dart + routes.dart:
    ❌ شيل login route

Definition of Done:
□ setUpDependencies() بدون auth/sync
□ flutter analyze clean على core
```

---

### Phase 7 — main.dart + HiyazaFinderApp

```
7.1 دمج main_dev + main_prod في main.dart:
    ❌ شيل dotenv.load()
    ❌ شيل Supabase.initialize()

7.2 عدّل HiyazaFinderApp:
    ❌ شيل BlocProvider<SessionCubit>
    ❌ شيل BlocListener<SessionCubit>
    ✅ initialRoute: Routes.home مباشرة

7.3 احذف main_dev.dart + main_prod.dart

Definition of Done:
□ App يبدأ على HomeScreen
□ مفيش SessionCubit في widget tree
□ main.dart واحد بدون Supabase
```

---

### Phase 8 — تنظيف UI

```
8.1 holdings/ui/widgets/home_top_bar.dart:
    ❌ شيل _PendingSyncsButton

8.2 احذف:
    ❌ holdings/ui/widgets/pending_syncs_sheet.dart
    ❌ holdings/ui/widgets/sync_operation_summary.dart

8.3 holdings/ui/home_screen.dart:
    ❌ شيل SyncRunner.flush()
    ❌ شيل searchRemote() + _mergeRemoteResults

8.4 cities/ui/city_tools_screen.dart:
    ❌ شيل _editCityCode() + city code tile

8.5 holdings/ui/widgets/parcel_detail_card.dart:
    ❌ بسّط _copyId() — شيل Supabase reconciliation

8.6 holdings/ui/detail_screen.dart:
    ❌ شيل _remoteChangesSub، _connectivitySub، syncNow
    ❌ استبدل setParcelCompletedWithReconciliation بـ setParcelCompleted

Definition of Done:
□ مفيش pending syncs UI
□ مفيش Supabase calls في UI
□ كل الـ screens بتشتغل
```

---

### Phase 9 — Final Verification

```
□ flutter pub get → no errors
□ flutter analyze → zero issues
□ flutter test → all passing
□ مفيش supabase_flutter في أي ملف
□ مفيش flutter_dotenv في أي ملف
□ مفيش domain/ folder في أي feature
□ مفيش presentation/ folder في أي feature
□ كل feature: data/ + logic/ + ui/ بس
□ App يبدأ على HomeScreen مباشرة
□ City download شغال (HTTP GET)
□ Search + Edit + Add + Delete كلهم local
□ LocalAddedParcelsStore يحفظ added parcels
□ App يشتغل offline بعد أول download
```

---

## 7. Template للـ Features الجديدة

```
lib/features/<feature_name>/
├── data/
│   ├── model/
│   │   └── <name>.dart
│   ├── remote/                      ← لو في network
│   │   └── <name>_remote_ds.dart
│   ├── local/                       ← لو في local storage
│   │   └── <name>_local_ds.dart
│   └── repo/
│       ├── <name>_repo.dart         ← abstract
│       └── <name>_repo_impl.dart    ← concrete
├── logic/
│   └── cubit/
│       ├── <name>_cubit.dart
│       └── <name>_state.dart
└── ui/
    ├── widgets/
    │   └── <widget>.dart            ← one per file
    └── <name>_screen.dart
```

---

## 8. قواعد لا تُكسر

| القاعدة | التفصيل |
|---|---|
| ❌ لا Supabase SDK | http فقط |
| ❌ لا Auth | HomeScreen مباشرة |
| ❌ لا writes على network | local only |
| ❌ لا domain/ folder | models في data/model/ |
| ❌ لا presentation/ folder | ui/ بدلها |
| ✅ ui/ → logic/ فقط | مش data/ مباشرة |
| ✅ logic/ → repo interface | مش impl |
| ✅ One class per file | |
| ✅ One widget per file | |
| ✅ Phase by phase | لا قفز |
| ✅ Export-ready | LocalAddedParcelsStore + LocalEditTracker |

---

## 9. اللي مش بيتغير

```
✅ Parcel entity logic
✅ CitySnapshotCache logic
✅ ParcelEditsStore logic
✅ كل الـ domain services logic
✅ كل الـ UI widgets
✅ كل الـ Screens
✅ AppColors + AppTextStyles
✅ Easy Localization
✅ HydratedBloc (AppSettingsCubit فقط)
✅ flutter_screenutil + flutter_animate
✅ Bloc/Cubit pattern
```

---

*آخر تحديث: أغسطس 2026*
*الإصدار: 2.0 — New Pattern + Local-First*
