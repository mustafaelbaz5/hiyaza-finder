# CLAUDE.md — HiyazaFinder App
## Complete Refactor + New Features Plan

> **اقرأ الملف ده بالكامل قبل أي سطر كود.**
> ده المرجع الوحيد للـ App refactor والـ features الجديدة.
> أي قرار مش موجود هنا → اسأل الأول.
> استخدم أي skill متاحة لو هتفيد في الـ implementation.

---

## 1. المبادئ الأساسية

```
✅ Local-First  — كل العمليات offline بعد أول download
✅ SOLID        — Single Responsibility في كل class/widget
✅ Clean Code   — ملف أقل من 150 سطر، function واحدة = مسؤولية واحدة
✅ Basin-First  — الـ UX بيمشي حوض → حيازة → قطعة
✅ No Auth      — App يبدأ على HomeScreen مباشرة
✅ No Supabase writes — كل التعديلات local فقط
✅ Export-Ready — LocalAddedParcelsStore + LocalEditTracker موجودين
✅ Use Skills   — استخدم أي skill متاحة لو هتحسّن الـ output
```

---

## 2. الـ Pattern — القاعدة الأساسية

```
lib/features/<feature>/
├── data/
│   ├── model/         ← data classes, enums, pure Dart
│   ├── remote/        ← HTTP GET only (http package)
│   ├── local/         ← SharedPrefs, file cache, local services
│   └── repo/
│       ├── <x>_repo.dart       ← abstract interface
│       └── <x>_repo_impl.dart  ← concrete implementation
├── logic/
│   └── cubit/
│       ├── <x>_cubit.dart
│       └── <x>_state.dart
└── ui/
    ├── widgets/
    │   └── <widget>.dart    ← one widget per file
    └── <x>_screen.dart
```

### قواعد الـ Pattern
```
❌ مفيش domain/ folder
❌ مفيش presentation/ folder
❌ ui/ لا تعتمد على data/ مباشرة
❌ logic/ لا تعتمد على data/ implementations مباشرة
✅ ui/ → logic/cubit فقط
✅ logic/cubit → repo interface فقط
✅ one class per file
✅ one widget per file
```

---

## 3. الـ Features Structure

### 3.1 Feature: `cities`
```
lib/features/cities/
├── data/
│   ├── model/
│   │   ├── city.dart
│   │   ├── city_snapshot.dart
│   │   ├── cached_city_meta.dart
│   │   └── association_type.dart
│   ├── remote/
│   │   └── city_remote_ds.dart     ← HTTP GET فقط
│   ├── local/
│   │   └── city_snapshot_cache.dart
│   └── repo/
│       ├── city_repo.dart
│       └── city_repo_impl.dart
├── logic/cubit/
│   ├── city_cubit.dart
│   └── city_state.dart
└── ui/
    ├── widgets/
    │   ├── city_tile.dart
    │   ├── cached_city_tile.dart
    │   ├── city_list_states.dart
    │   └── city_picker_loading_list.dart
    ├── city_picker_screen.dart
    ├── city_tools_screen.dart
    └── manage_cities_screen.dart
```

### 3.2 Feature: `holdings`
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
│   │   ├── holding_search_service.dart     ← بيتعدل (search algorithm جديد)
│   │   ├── parcel_dataset_state.dart
│   │   ├── parcel_edit_overlay.dart
│   │   ├── parcel_edits_store.dart
│   │   ├── parcel_mapper.dart
│   │   ├── parcel_query_service.dart
│   │   ├── local_added_parcels_store.dart  ← NEW
│   │   └── local_edit_tracker.dart         ← NEW
│   └── repo/
│       ├── holdings_repo.dart
│       └── holdings_repo_impl.dart         ← بيتبسط (شيل Supabase)
├── logic/cubit/
│   ├── home_cubit.dart                     ← بيتعدل
│   └── home_state.dart
└── ui/
    ├── widgets/
    │   ├── basin_card.dart                 ← NEW
    │   ├── basin_progress_bar.dart         ← NEW
    │   ├── border_compass.dart
    │   ├── copy_all_button.dart
    │   ├── detail_screen_header.dart
    │   ├── empty_body.dart
    │   ├── error_body.dart
    │   ├── field_edit_dialogs.dart
    │   ├── field_row.dart
    │   ├── home_top_bar.dart
    │   ├── inline_action.dart
    │   ├── notes_field.dart                ← NEW (List<String> بدل String)
    │   ├── parcel_detail_card.dart         ← بيتعدل
    │   ├── parcel_detail_header.dart
    │   ├── parcel_nav_buttons.dart         ← NEW (Previous/Next)
    │   ├── parcel_status_filter.dart
    │   ├── recommendation_list.dart        ← بيتعدل
    │   ├── recommendation_tile.dart        ← بيتعدل
    │   ├── required_field_gaps.dart
    │   ├── responsive_fields_wrap.dart
    │   ├── section_card.dart
    │   ├── see_more_section.dart
    │   ├── status_badge.dart
    │   ├── status_summary_cards.dart
    │   ├── tile_icon_button.dart
    │   ├── toggle_field_row.dart
    │   └── top_bar_icon_button.dart
    ├── home_screen.dart                    ← بيتعدل (Basin-First)
    ├── basin_screen.dart                   ← NEW
    ├── detail_screen.dart                  ← بيتعدل
    ├── add_record_screen.dart
    ├── export_screen.dart                  ← NEW
    ├── file_status_screen.dart
    └── missing_holding_id_screen.dart
```

### 3.3 Feature: `crop_type`
```
lib/features/crop_type/
├── data/
│   ├── local/
│   │   └── crop_type_local_ds.dart
│   └── repo/
│       ├── crop_type_repo.dart
│       └── crop_type_repo_impl.dart
└── ui/
    ├── widgets/
    │   └── crop_type_picker.dart
    └── crop_type_settings_screen.dart
```

### 3.4 Feature: `about`
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

## 4. الـ Screens — التفاصيل الكاملة

### Screen 1: Home Screen (Basin-First)

**الهدف:** يبيّن للـ field worker تقدمه في كل حوض

```
┌─────────────────────────────────┐
│  شنشا — ائتمان          [⚙️]   │
├─────────────────────────────────┤
│  [🔍 بحث بالاسم أو الرقم...]   │
│                                 │
│  الأحواض                        │
│  ┌─────────────────────────┐   │
│  │ 🟢 الباشا      69/69   │   │
│  │ ████████████  100%      │   │
│  ├─────────────────────────┤   │
│  │ 🟡 البحيره     45/131   │   │
│  │ ████░░░░░░░    34%      │   │
│  ├─────────────────────────┤   │
│  │ ⚪ البراوي      0/175   │   │
│  │ ░░░░░░░░░░░    0%       │   │
│  └─────────────────────────┘   │
│                                 │
│  الإجمالي: 114 / 1,350  8%     │
│  ████████░░░░░░░░░░░░░░░░░      │
│                      [+ إضافة] │
└─────────────────────────────────┘
```

**Logic:**
- 🟢 = كل الحيازات completed
- 🟡 = جزء completed
- ⚪ = لا شيء completed
- Progress = عدد الحيازات الـ completed / الإجمالي
- Search bar → يفتح Search Screen

**State:**
```dart
// home_state.dart
enum HomeStatus { loading, noCity, loaded, error }

class HomeState {
  final HomeStatus status;
  final List<BasinSummary> basins;    // NEW - بدل parcels list مباشرة
  final int totalParcels;
  final int completedParcels;
  final String? cityName;
  final String? errorMessage;
}

class BasinSummary {
  final String basinName;
  final String? basinCode;
  final int totalCount;
  final int completedCount;
}
```

---

### Screen 2: Basin Screen (جديد)

**الهدف:** عرض كل حيازات حوض معين مع status

```
┌─────────────────────────────────┐
│  ← البحيره           45/131    │
├─────────────────────────────────┤
│  [الكل] [ناقصة ○] [مكتملة ✅]   │
│                                 │
│  ┌─────────────────────────┐   │
│  │ #001 — محمد أحمد  ✅   │   │
│  │ قطعة واحدة             │   │
│  ├─────────────────────────┤   │
│  │ #003 — إبراهيم السيد ○ │   │
│  │ 3 قطع                  │   │
│  ├─────────────────────────┤   │
│  │ #004 — أحمد عبدالله ○  │   │
│  │ قطعة واحدة             │   │
│  └─────────────────────────┘   │
│                    [+ إضافة]   │
└─────────────────────────────────┘
```

**Logic:**
- مرتب بـ رقم الحيازة تصاعدياً
- كل card = holding واحد (مش قطعة)
- ✅ = كل قطع الحيازة completed
- ○ = مفيش قطعة completed
- ½ = بعض القطع completed (عدد/إجمالي)
- الفيلتر (الكل/ناقصة/مكتملة) بيشتغل على مستوى الـ holding

---

### Screen 3: Detail Screen (محسّن)

**الهدف:** تفاصيل حيازة + navigation للحيازة اللي قبلها أو بعدها

```
┌─────────────────────────────────┐
│  ← #003              [◀] [▶]   │
│     إبراهيم السيد   السابق التالي│
├─────────────────────────────────┤
│                                 │
│  ┌─── قطعة 1 — الباشا ────┐   │
│  │  🧭 البوصلة             │   │
│  │  البيانات...             │   │
│  │  [📋 Copy ID]           │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─── قطعة 2 — البحيره ───┐   │
│  │  🧭 البوصلة             │   │
│  │  البيانات...             │   │
│  │  [📋 Copy ID]           │   │
│  └─────────────────────────┘   │
│                                 │
│              [+ إضافة قطعة]    │
└─────────────────────────────────┘
```

**القطع مرتبة بـ اسم الحوض أبجدياً**

**Previous/Next:**
```dart
// الترتيب = نفس ترتيب Basin Screen
// السابق/التالي = الحيازة اللي قبل وبعد في نفس الحوض
// لو أول حيازة → السابق مش موجود
// لو آخر حيازة → التالي مش موجود
```

---

### Screen 4: Search Screen

**الهدف:** بحث متقدم بـ 3 طرق مختلفة

```
┌─────────────────────────────────┐
│  ← بحث                          │
├─────────────────────────────────┤
│  [🔍 ابحث بالاسم أو الرقم...] ✕ │
│                                 │
│  ← نتائج البحث عن "48"          │
│                                 │
│  ┌─────────────────────────┐   │
│  │ #48 — أحمد محمود        │   │
│  │ 2 قطعة | البحيره        │   │
│  └─────────────────────────┘   │
└─────────────────────────────────┘
```

---

### Screen 5: Export Screen (جديد)

```
┌─────────────────────────────────┐
│  ← تصدير البيانات               │
├─────────────────────────────────┤
│                                 │
│  البيانات المُصدَّرة             │
│  ○ كل البيانات (1,350 قطعة)    │
│  ● المضافة يدوياً فقط (23 قطعة) │
│                                 │
│  ─────────────────────────────  │
│                                 │
│  الحوض                          │
│  ● كل الأحواض                   │
│  ○ حوض محدد ▼                  │
│                                 │
│  ─────────────────────────────  │
│                                 │
│  الملف المُصدَّر سيحتوي على:    │
│  ✓ شيت "كل البيانات"           │
│  ✓ شيت لكل حوض                 │
│                                 │
│       [تصدير Excel ↓]           │
└─────────────────────────────────┘
```

---

## 5. الـ Search Algorithm الجديد

### `data/local/holding_search_service.dart`

```dart
// 3 أنواع بحث — بيتحدد نوعه تلقائياً

enum SearchType { holdingNumber, parcelId, holderName }

SearchType detectSearchType(String query) {
  // كل الـ input أرقام (عربية أو إنجليزية) → رقم الحيازة
  if (RegExp(r'^[\d٠-٩]+$').hasMatch(query.trim())) {
    return SearchType.holdingNumber;
  }
  // UUID format (hex + dashes) → Parcel ID
  if (RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(query.trim())) {
    return SearchType.parcelId;
  }
  // غير كده → اسم الحائز
  return SearchType.holderName;
}

// رقم الحيازة: EXACT MATCH فقط
// "8" → بس رقم الحيازة = "8" بالظبط
// "48" → بس رقم الحيازة = "48" بالظبط
// مش contains — مش startsWith — exact فقط
List<SearchResult> searchByHoldingNumber(List<Parcel> parcels, String query) {
  final normalized = _normalizeHoldingNumber(query); // شيل leading zeros
  return parcels
      .where((p) => _normalizeHoldingNumber(p.holdingIdNumber ?? '') == normalized)
      .toList();
}

// Parcel ID: startsWith
List<SearchResult> searchByParcelId(List<Parcel> parcels, String query) {
  return parcels
      .where((p) => p.id.toLowerCase().startsWith(query.toLowerCase()))
      .toList();
}

// اسم الحائز: contains + Arabic normalization
// نفس الـ scoring الموجود (exact > word start > contains)
List<SearchResult> searchByHolderName(List<Parcel> parcels, String query) {
  final normalizedQuery = ArabicNormalizer.normalizeForSearch(query);
  // ... existing scoring logic
}

// النتيجة دايماً مجمّعة بـ holding (مش قطعة قطعة)
// كل holding = card واحد + عدد القطع
```

---

## 6. الـ Local Data Model

### الـ Parcel Fields

**من الـ DB (read-only من Supabase):**
```
id, city_id, basin_id
directorate, administration
association_name, association_code, association_type
basin_name, basin_code
holding_id_number, unified_holding_id, registry_page
national_id, holder_name, parcel_count_in_holding
land_number
area_feddan, area_qirat, area_sahm, area_sqm
border_north, border_south, border_east, border_west
```

**locally فقط (بتتحفظ في ParcelEditsStore):**
```
owner_name          ← اسم المالك (default = holder_name)
usage_type          ← نوع الاستخدام (default = 'زراعة')
crop_type           ← نوع المحصول
growth_stage        ← مراحل النمو (default = 'مرحلة النمو الخضري')
notes               ← List<String> (مش String واحدة)
is_inheritance      ← bool (default = false)
is_delegate         ← bool (default = false)
is_completed        ← bool (default = false)
completed_at        ← DateTime?
```

### الـ Local Stores

```dart
// 1. ParcelEditsStore — تعديلات على قطع موجودة
// key: 'parcel_edits::city_id'
// value: Map<parcel_id, Map<field, value>>

// 2. LocalAddedParcelsStore — قطع مضافة يدوياً
// key: 'added_parcels::city_id'
// value: List<Parcel> (كاملة بكل البيانات)

// 3. LocalEditTracker — تتبع IDs المعدّلة للـ export
// key: 'edited_ids::city_id'
// value: Set<parcel_id>

// 4. LocalCompletedStore — القطع المكتملة
// key: 'completed::city_id'
// value: Map<parcel_id, completed_at>
```

---

## 7. الـ Toggle Logic الجديد

### وراثة Toggle

```dart
// is_inheritance = true
// → "وارثه " يُضاف في العرض قبل اسم المالك وقبل اسم الحائز
// → في Copy All والـ Export نفس الشيء
// → القيمة المخزنة (holder_name) مش بتتغير
// → بس الـ display والـ formatted output بيتغيروا

String displayHolderName(Parcel p) {
  final name = p.holderName ?? '';
  return p.isInheritance ? 'وارثه $name' : name;
}

String displayOwnerName(Parcel p) {
  final name = effectiveOwnerName(p); // owner_name أو holder_name
  return p.isInheritance ? 'وارثه $name' : name;
}
```

### مفوض Toggle

```dart
// is_delegate = true
// → يفتح Dialog لإدخال اسم المالك
// → اسم المالك لازم يختلف عن اسم الحائز (validation)
// → بعد التأكيد:
//   1. owner_name = الاسم الجديد
//   2. يُضاف في notes تلقائياً: "مفوض عنه {holder_name}"

void onDelegateEnabled(String holderName, String newOwnerName) {
  // validation: newOwnerName != holderName
  // save: owner_name = newOwnerName
  // auto-add to notes: "مفوض عنه $holderName"
}
```

### الاتنين مع بعض

```dart
// is_inheritance = true AND is_delegate = true
// → "وارثه " قبل اسم المالك بس (مش الحائز)
// → ملاحظة المفوض بتتضاف كمان
// → في العرض:
//   اسم المالك: "وارثه [اسم المالك]"
//   اسم الحائز: "[اسم الحائز]" (من غير وارثه)
```

---

## 8. الـ Notes System الجديد

```dart
// notes = List<String> بدل String واحدة

// في الـ ParcelEditsStore:
// notes: ['ملاحظة 1', 'ملاحظة 2', 'مفوض عنه مصطفي']

// الـ Widget الجديد: notes_field.dart
// - يعرض كل ملاحظة كـ chip أو سطر منفصل
// - زرار "+" لإضافة ملاحظة جديدة
//   → يفتح Dialog:
//     - TextField للكتابة بالإيد (free text)
//     - قائمة سريعة بالملاحظات الشائعة:
//       * "لا يوجد حصر ميداني"
//       * "وضع يد"
//       * "نقص بيانات الحصر"
//       * "تابعة لجهة/هيئة"
//       * "غير محيز"
//       * وغيرها...
//     - اختيار من القائمة يُضيف مباشرة للـ notes list
// - زرار حذف على كل ملاحظة
// - المفوض يضيف تلقائياً بدون Dialog

// في Copy All والـ Export:
// notes.join('، ') → "ملاحظة 1، ملاحظة 2، مفوض عنه مصطفي"
```

---

## 9. الـ Copy All Format

```dart
// نفس الـ export format:
String formatCopyAll(Parcel p, LocalData local) {
  return '''
كود القطعة: ${p.id}
رقم الحيازة: ${p.holdingIdNumber}
كود الجمعية + اسم الجمعية: ${p.associationCode} - ${p.associationName}
نوع الجمعية: ${p.associationType}
اسم المالك: ${displayOwnerName(p, local)}
الرقم القومي للمالك: ${p.nationalId}
اسم الحائز: ${displayHolderName(p, local)}
الرقم القومي للحائز: ${p.nationalId}
رقم القطعة: ${p.landNumber}
المساحة: ${p.areaFeddan} فدان ${p.areaQirat} قيراط ${p.areaSahm} سهم
كود الحوض + اسم الحوض: ${p.basinCode} - ${p.basinName}
نوع الاستخدام: ${local.usageType}
نوع المحصول: ${local.cropType}
مراحل النمو: ${local.growthStage}
ملاحظات: ${local.notes.join('، ')}
''';
}
```

---

## 10. الـ Export Logic

### `data/local/export_service.dart`

```dart
class ExportService {
  // بيولّد Excel file في memory
  // بيرجع Uint8List جاهز للـ download

  Future<Uint8List> exportToExcel({
    required List<Parcel> parcels,
    required Map<String, dynamic> localData, // ParcelEditsStore data
    required ExportScope scope,              // all or added_only
    required String? basinFilter,            // null = all basins
  });
}

enum ExportScope { all, addedOnly }

// الـ Excel Output:
// Sheet 1: "كل البيانات" ← كل القطع
// Sheet 2: "الباشا"      ← قطع الحوض ده بس
// Sheet 3: "البحيره"     ← ...
// ... شيت لكل حوض موجود في الـ data

// الأعمدة في كل شيت:
const exportColumns = [
  'كود القطعة',
  'رقم الحيازة',
  'كود الجمعية + اسم الجمعية',
  'نوع الجمعية',
  'اسم المالك من الحصر الميداني',
  'الرقم القومي',
  'اسم الحائز من الحصر الميداني',
  'رقم القطعة',
  'فدان',
  'قيراط',
  'سهم',
  'كود الحوض + اسم الحوض',
  'نوع الاستخدام',
  'نوع المحصول',
  'مراحل النمو',
  'ملاحظات من فريق العمل',
];
```

---

## 11. Implementation Phases

### Phase 1 — Supabase Removal + Package Update
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

1.3 عدّل core/errors/error_handler.dart
1.4 عدّل core/config/app_config.dart

Definition of Done:
□ flutter pub get بدون errors
□ مفيش supabase_flutter في أي ملف
```

### Phase 2 — Restructure: `cities`
```
2.1 أنشئ folders الجديدة
2.2 انقل models من domain/entities → data/model/
2.3 أنشئ city_remote_ds.dart (HTTP GET)
2.4 انقل + عدّل city_repo_impl.dart
2.5 احذف supabase_city_data_source.dart
2.6 انقل logic + ui

Definition of Done:
□ مفيش domain/ في cities
□ City download بيشتغل بـ HTTP
```

### Phase 3 — Restructure: `holdings` (Part 1 — Data Layer)
```
3.1 أنشئ folders الجديدة
3.2 انقل models
3.3 انقل local services
3.4 أنشئ LocalAddedParcelsStore
3.5 أنشئ LocalEditTracker
3.6 عدّل + بسّط holdings_repo_impl.dart
    ❌ شيل كل Supabase/sync methods
    ✅ فضّل local-only operations

Definition of Done:
□ مفيش Supabase imports في holdings/data/
□ LocalAddedParcelsStore بيحفظ صح
```

### Phase 4 — Restructure: `holdings` (Part 2 — Logic + UI)
```
4.1 انقل + عدّل home_cubit.dart (Basin-First)
4.2 أنشئ basin_screen.dart
4.3 عدّل home_screen.dart (Basin cards + progress)
4.4 عدّل detail_screen.dart (sort by basin + prev/next)
4.5 أنشئ parcel_nav_buttons.dart
4.6 احذف presentation/ folder

Definition of Done:
□ Home بيعرض الأحواض مع progress
□ Basin screen بيعرض الحيازات
□ Previous/Next بيشتغل في Detail
□ القطع مرتبة بـ basin name
```

### Phase 5 — Search Algorithm الجديد
```
5.1 عدّل holding_search_service.dart:
    - detectSearchType()
    - searchByHoldingNumber() → EXACT MATCH
    - searchByParcelId() → startsWith
    - searchByHolderName() → contains + normalized

5.2 عدّل recommendation_tile.dart
5.3 عدّل recommendation_list.dart

Definition of Done:
□ "8" → بس رقم الحيازة = 8 بالظبط
□ "محمد" → كل الحائزين بـ محمد في الاسم
□ UUID → القطعة اللي ID بتاعها startsWith
□ كل holding = card واحد + عدد القطع
```

### Phase 6 — Notes + Toggles الجديدة
```
6.1 عدّل Parcel model:
    - notes: List<String> (مش String)

6.2 أنشئ notes_field.dart widget:
    - عرض notes كـ chips
    - Dialog للإضافة (free text + quick list)
    - حذف note

6.3 عدّل toggle logic:
    - وراثة → display prefix بس
    - مفوض → Dialog + owner_name + auto-note
    - الاتنين مع بعض → combined logic

6.4 عدّل clipboard_formatter.dart:
    - notes.join('، ')
    - displayHolderName() + displayOwnerName()

Definition of Done:
□ Notes بتتضاف وتتحذف صح
□ وراثة بتظهر في العرض والـ copy
□ مفوض بيفتح Dialog ويضيف ملاحظة تلقائي
```

### Phase 7 — Export Feature
```
7.1 أنشئ export_service.dart في data/local/
7.2 أنشئ export_screen.dart
7.3 اضيف ExportScope enum
7.4 اضيف xlsx dependency في pubspec.yaml
7.5 اربط Export بـ City Tools Screen

Definition of Done:
□ Export كل البيانات → Excel صح
□ Export المضافة بس → Excel صح
□ شيت لكل حوض موجود في الـ output
□ الأعمدة صح ومرتبة
```

### Phase 8 — crop_type Feature
```
8.1 أنشئ lib/features/crop_type/
8.2 LocalCropTypeService (SharedPreferences)
8.3 انقل crop_type_settings_screen.dart
8.4 انقل crop_type_picker.dart

Definition of Done:
□ Crop types بتتحفظ locally
□ Fallback للـ default list
```

### Phase 9 — About + Core Cleanup
```
9.1 Restructure about feature
9.2 احذف DI modules (auth + sync)
9.3 عدّل core_module (أضف http.Client)
9.4 عدّل cities_module + holdings_module
9.5 عدّل app_router (شيل login)
9.6 بسّط main.dart (شيل Supabase.initialize)
9.7 عدّل HiyazaFinderApp (شيل SessionCubit)

Definition of Done:
□ App يبدأ على Home مباشرة
□ flutter analyze clean
```

### Phase 10 — Final Verification
```
□ flutter pub get → no errors
□ flutter analyze → zero issues
□ flutter test → all passing
□ مفيش supabase_flutter في أي ملف
□ مفيش domain/ أو presentation/ في أي feature
□ App يبدأ على HomeScreen
□ City download شغال (HTTP)
□ Home بيعرض الأحواض بـ progress
□ Basin screen بيعرض الحيازات
□ Search: exact للأرقام، contains للأسماء
□ Notes: list بتتضاف وتتحذف
□ Export: Excel صح مع شيت لكل حوض
□ App شغال offline بعد أول download
```

---

## 12. قواعد لا تُكسر

| القاعدة | التفصيل |
|---|---|
| ❌ لا Supabase SDK | http فقط |
| ❌ لا Auth | HomeScreen مباشرة |
| ❌ لا writes على network | local only |
| ❌ لا domain/ folder | models في data/model/ |
| ❌ لا presentation/ folder | ui/ بدلها |
| ❌ لا any في Dart | strong typing دايماً |
| ❌ لا business logic في UI | services + repo بس |
| ❌ لا hardcoded strings | constants أو localization |
| ✅ Phase by phase | لا قفز بين phases |
| ✅ ui/ → logic/ فقط | مش data/ مباشرة |
| ✅ logic/ → repo interface | مش impl |
| ✅ one class per file | |
| ✅ one widget per file | |
| ✅ ملف أقل من 150 سطر | لو أكبر → اقسمه |
| ✅ Use available skills | استخدم أي skill مفيدة |
| ✅ Export-ready | LocalAddedParcelsStore + LocalEditTracker |
| ✅ Preview قبل Export | اليوزر يشوف قبل التنزيل |
| ✅ Batch operations | +100 عنصر → batches |

---

## 13. اللي مش بيتغير

```
✅ Parcel entity logic (بيتنقل بس)
✅ CitySnapshotCache logic
✅ ParcelEditsStore logic
✅ BorderNameIndex
✅ AreaCalculator
✅ ArabicNormalizer
✅ AppColors + AppTextStyles + CustomColors
✅ Easy Localization (Arabic/English)
✅ HydratedBloc (AppSettingsCubit فقط)
✅ flutter_screenutil
✅ flutter_animate
✅ Bloc/Cubit pattern
✅ Mark Completed logic (Copy ID = completed)
```

---

*آخر تحديث: أغسطس 2026*
*الإصدار: 3.0 — Basin-First + New Features*
