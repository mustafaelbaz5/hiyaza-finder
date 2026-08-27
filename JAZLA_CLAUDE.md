# CLAUDE.md — Jazla Feature
## Complete Implementation Plan

> **اقرأ الملف ده بالكامل قبل أي سطر كود.**
> لا تبدأ implementation قبل ما تفهم كل section.
> الجزلة = تجميع وتنظيم فقط — مش نظام بيانات منفصل.
> استخدم أي skill متاحة لو هتحسّن الـ output.

---

## 1. المبدأ الأساسي

```
الجزلة لا تحتوي بيانات — هي تحتوي IDs فقط.
البيانات الحقيقية تبقى في المصدر الأصلي (parcels/local stores).
أي تعديل على قطعة من داخل الجزلة يأثر على القطعة الأصلية.
```

---

## 2. الـ Data Model

### `features/jazla/data/model/jazla.dart`

```dart
class Jazla {
  final String id;              // UUID - generated locally
  final String cityId;
  final String name;            // اسم الجزلة - user input
  final List<String> parcelIds; // ordered list - ترتيب الإضافة
  final DateTime createdAt;

  // Computed
  int get parcelCount => parcelIds.length;
}
```

---

## 3. الـ Feature Structure

```
lib/features/jazla/
├── data/
│   ├── model/
│   │   └── jazla.dart
│   ├── local/
│   │   └── jazla_store.dart        ← local JSON storage
│   └── repo/
│       ├── jazla_repo.dart         ← interface
│       └── jazla_repo_impl.dart    ← implementation
├── logic/
│   └── cubit/
│       ├── jazla_list_cubit.dart
│       ├── jazla_list_state.dart
│       ├── jazla_detail_cubit.dart
│       └── jazla_detail_state.dart
└── ui/
    ├── widgets/
    │   ├── jazla_card.dart              ← card في قائمة الجزل
    │   ├── jazla_parcel_tile.dart       ← قطعة داخل الجزلة
    │   ├── jazla_search_bar.dart        ← search في Bottom Sheet
    │   ├── jazla_parcel_result_tile.dart ← نتيجة بحث (قطعة)
    │   ├── jazla_locked_badge.dart      ← badge القطعة المقفولة
    │   └── jazla_quick_view_sheet.dart  ← Quick View Bottom Sheet
    ├── jazla_list_screen.dart
    ├── jazla_detail_screen.dart
    └── jazla_add_parcel_sheet.dart      ← Bottom Sheet للبحث والإضافة
```

---

## 4. الـ Local Store

### `features/jazla/data/local/jazla_store.dart`

```dart
class JazlaStore {
  static const String _keyPrefix = 'jazlas::';
  
  String _key(String cityId) => '$_keyPrefix$cityId';

  // CRUD
  Future<List<Jazla>> loadAll(String cityId);
  Future<void> save(Jazla jazla, String cityId);
  Future<void> delete(String jazlaId, String cityId);

  // Parcel management
  Future<void> addParcel(String jazlaId, String parcelId, String cityId);
  Future<void> removeParcel(String jazlaId, String parcelId, String cityId);
  Future<void> reorder(String jazlaId, List<String> newOrder, String cityId);

  // Query
  Future<Jazla?> findByParcelId(String parcelId, String cityId);
  // ← للـ badge: بيجيب الجزلة اللي القطعة موجودة فيها
}
```

---

## 5. الـ Repo Interface

### `features/jazla/data/repo/jazla_repo.dart`

```dart
abstract class JazlaRepo {
  Future<List<Jazla>> getAll(String cityId);
  Future<Jazla> create(String name, String cityId);
  Future<void> delete(String jazlaId, String cityId);
  Future<void> rename(String jazlaId, String newName, String cityId);
  Future<void> addParcel(String jazlaId, String parcelId, String cityId);
  Future<void> removeParcel(String jazlaId, String parcelId, String cityId);
  Future<void> reorderParcels(String jazlaId, List<String> newOrder, String cityId);
  Future<Jazla?> getJazlaContaining(String parcelId, String cityId);
  Future<bool> isParcelUsed(String parcelId, String cityId);
}
```

---

## 6. الـ Screens

### Screen 1: `jazla_list_screen.dart`

```
┌─────────────────────────────────┐
│  ← الجزل                        │
├─────────────────────────────────┤
│  ┌─────────────────────────┐   │
│  │ جزلة الري               │   │
│  │ 12 قطعة                 │   │
│  ├─────────────────────────┤   │
│  │ جزلة الترعة             │   │
│  │ 8 قطع                   │   │
│  └─────────────────────────┘   │
│                                 │
│              [+ جزلة جديدة]    │
└─────────────────────────────────┘
```

**Actions:**
- Tap على جزلة → Jazla Detail Screen
- Long press → خيارات (تعديل الاسم / حذف)
- [+ جزلة جديدة] → Dialog لإدخال الاسم

---

### Screen 2: `jazla_detail_screen.dart`

```
┌─────────────────────────────────┐
│  ← جزلة الري    12 قطعة  [📤] │
├─────────────────────────────────┤
│  (drag handles on left)         │
│  ☰ 1  محمد أحمد | الباشا      │
│     0 ف | 14 ق | 0 س          │
│  ─────────────────────────────  │
│  ☰ 2  إبراهيم السيد | البحيره  │
│     1 ف | 0 ق | 0 س           │
│  ─────────────────────────────  │
│  ☰ 3  أحمد عبدالله | العمده   │
│     0 ف | 21 ق | 12 س         │
│                                 │
│              [+ إضافة قطعة]    │
└─────────────────────────────────┘
```

**Actions:**
- Tap على قطعة → Detail Screen الكامل (مش Quick View)
- Drag & Drop لإعادة الترتيب
- Swipe left → حذف من الجزلة
- [📤] → Export (Excel)
- [+ إضافة قطعة] → Jazla Add Parcel Sheet

---

### Screen 3: `jazla_add_parcel_sheet.dart` (Bottom Sheet)

```
┌─────────────────────────────────┐
│  إضافة قطعة                     │
│  [🔍 ابحث بالاسم أو الرقم...]  │
├─────────────────────────────────┤
│  نتائج البحث — على مستوى القطع  │
│                                 │
│  محمد أحمد                      │
│  ┌─────────────────────────┐   │
│  │ قطعة 1 — الباشا   [+]  │   │
│  │ 0ف | 14ق | 0س          │   │
│  ├─────────────────────────┤   │
│  │ قطعة 2 — البحيره       │   │
│  │ [🔒 جزلة الترعة]       │   │
│  └─────────────────────────┘   │
│                                 │
│  [+ شخص جديد] [+ قطعة لشخص]   │
└─────────────────────────────────┘
```

**Rules:**
- نفس Search Algorithm الحالي بالظبط
- النتيجة على مستوى القطع مش الأشخاص
- كل قطعة في جزلة تانية → badge بيعرض اسم الجزلة + مش قابلة للإضافة
- [+] على قطعة حرة → يفتح Quick View
- مفيش نتائج → خيارات إضافة شخص جديد أو قطعة لشخص موجود

---

### Screen 4: `jazla_quick_view_sheet.dart` (Bottom Sheet)

```
┌─────────────────────────────────┐
│  محمد أحمد              [✕]    │
├─────────────────────────────────┤
│  رقم الحيازة: 48                │
│  اسم الحائز: محمد أحمد          │
│  اسم المالك: محمد أحمد          │
│  اسم الحوض: الباشا              │
│  المساحة: 0ف | 14ق | 0س        │
│                                 │
│  ─── تعديل قبل الإضافة ───      │
│  [وارثه  ●────── ○]             │
│  [مفوض   ○────── ●]             │
│                                 │
│  [إلغاء]    [إضافة للجزلة ✓]   │
└─────────────────────────────────┘
```

**Rules:**
- Toggles (وراثة/مفوض) بيظهروا هنا
- التعديل مؤقت — بيتحفظ بس لو اليوزر ضغط "إضافة للجزلة"
- لو ألغى → القطعة ترجع زي ما كانت بدون أي تغيير
- لو أضاف → التعديل بيتحفظ على القطعة الأصلية ثم بتتضاف للجزلة

---

## 7. الـ Search Logic في الجزلة

**نفس `HoldingSearchService` الحالي بالظبط — بس النتيجة مختلفة:**

```dart
// بدل HoldingGroup → ParcelSearchResult
class ParcelSearchResult {
  final Parcel parcel;
  final String holderName;
  final String? jazlaName;   // null = حرة، اسم = مقفولة
  final bool isLocked;       // موجودة في جزلة تانية
}

// في jazla_repo_impl.dart
List<ParcelSearchResult> searchParcels(String query) {
  // 1. نفس detectSearchType
  // 2. نفس منطق البحث
  // 3. لكل قطعة في النتيجة:
  //    - جيب الجزلة اللي فيها (لو موجودة)
  //    - حدد isLocked
  //    - حدد jazlaName
  // 4. رتب: الحرة أول ثم المقفولة
}
```

---

## 8. Quick View — التعديل المؤقت

```dart
// في jazla_detail_cubit.dart أو jazla_add_parcel_cubit

// عند فتح Quick View:
// 1. اقرأ LocalParcelData الحالية للقطعة
// 2. اعمل نسخة مؤقتة (temp copy)

class TempParcelEdits {
  bool isInheritance;
  bool isDelegate;
  String? ownerName;
  List<String> notes;
  // ... أي تعديل من الـ Quick View
}

// لو اليوزر ضغط "إضافة للجزلة":
// 1. حفظ TempParcelEdits على القطعة الأصلية
//    (نفس ParcelEditsStore الحالي)
// 2. إضافة parcelId للجزلة
// 3. إغلاق الـ Sheet

// لو اليوزر ضغط "إلغاء":
// 1. TempParcelEdits بتتتجاهل
// 2. القطعة الأصلية مش بتتغير
// 3. إغلاق الـ Sheet
```

---

## 9. Navigation Changes

### Home Screen AppBar

```dart
// قبل:
// [🏘️ أحواض] [⚙️ أدوات] [🔄 تغيير المدينة]

// بعد:
// [🗂️ جزل] [⚙️ أدوات] [🔄 تغيير المدينة]
```

### City Tools Screen

```dart
// أضف في القائمة:
// ─── التنظيم ───
// [🏘️] الأحواض      ← انتقل من Home
// [🗂️] الجزل        ← جديد → Jazla List Screen
```

---

## 10. Export

### اسم الملف

```dart
String buildJazlaExportFileName(String cityName, String jazlaName) {
  final now = DateTime.now();
  final day   = now.day.toString().padLeft(2, '0');
  final month = now.month.toString().padLeft(2, '0');
  final year  = now.year.toString();
  
  final cleanCity  = cityName.replaceAll(' ', '_').replaceAll('-', '_');
  final cleanJazla = jazlaName.replaceAll(' ', '_');
  
  return '${cleanCity}_${cleanJazla}_${day}_${month}_${year}.xlsx';
  // مثال: شنشا_جزلة_الري_26_08_2026.xlsx
}
```

### الـ Excel Sheet

**الأعمدة بالترتيب:**

| التسلسل | اسم الحائز | اسم المالك | رقم الحيازة | سهم | قيراط | فدان | الملاحظات |
|---|---|---|---|---|---|---|---|

**Rules:**
- التسلسل = ترتيب القطعة في الجزلة (1، 2، 3...)
- اسم المالك = effectiveOwnerName (يراعي المفوض والوراثة)
- اسم الحائز = effectiveHolderName (يراعي الوراثة)
- الملاحظات = notes.join('، ')
- RTL sheet

---

## 11. الـ DI

### أضف في `holdings_module.dart` أو `jazla_module.dart` جديد:

```dart
void registerJazlaModule(GetIt getIt) {
  getIt.registerLazySingleton<JazlaStore>(() => JazlaStore(
    store: getIt<KeyValueStore>(),
  ));

  getIt.registerLazySingleton<JazlaRepo>(() => JazlaRepoImpl(
    store: getIt<JazlaStore>(),
  ));
}
```

### أضف في `dependency_injection.dart`:

```dart
registerJazlaModule(getIt);
```

---

## 12. الـ Routes

```dart
// أضف في routes.dart:
static const String jazlaList   = '/jazla';
static const String jazlaDetail = '/jazla/detail';

// أضف في app_router.dart:
case Routes.jazlaList:
  return MaterialPageRoute(builder: (_) => const JazlaListScreen());
case Routes.jazlaDetail:
  final jazla = settings.arguments as Jazla;
  return MaterialPageRoute(builder: (_) => JazlaDetailScreen(jazla: jazla));
```

---

## 13. Implementation Phases

### Phase 1 — Data Layer
```
1.1 أنشئ jazla.dart model
1.2 أنشئ jazla_store.dart
1.3 أنشئ jazla_repo.dart (interface)
1.4 أنشئ jazla_repo_impl.dart
1.5 أضف registerJazlaModule في DI

Definition of Done:
□ JazlaStore بيحفظ ويقرأ صح
□ isParcelUsed() بتشتغل صح
□ getJazlaContaining() بتشتغل صح
```

### Phase 2 — Navigation Changes
```
2.1 شيل أيقونة الأحواض من Home AppBar
2.2 أضف أيقونة الجزل في Home AppBar
2.3 أضف الأحواض في City Tools Screen
2.4 أضف الجزل في City Tools Screen
2.5 أضف Routes الجديدة

Definition of Done:
□ Home AppBar: [🗂️ جزل] [⚙️] [🔄]
□ City Tools: الأحواض + الجزل موجودين
□ Routes شغالة
```

### Phase 3 — Jazla List Screen
```
3.1 أنشئ jazla_list_cubit + state
3.2 أنشئ jazla_card.dart widget
3.3 أنشئ jazla_list_screen.dart
3.4 Dialog إنشاء جزلة جديدة (اسم فقط)
3.5 Long press actions (تعديل اسم / حذف)

Definition of Done:
□ قائمة الجزل بتظهر
□ إنشاء جزلة جديدة بيشتغل
□ حذف جزلة بيشتغل
□ تعديل الاسم بيشتغل
```

### Phase 4 — Jazla Detail Screen
```
4.1 أنشئ jazla_detail_cubit + state
4.2 أنشئ jazla_parcel_tile.dart
4.3 أنشئ jazla_detail_screen.dart مع Drag & Drop
4.4 Swipe to remove من الجزلة
4.5 Tap → Detail Screen الكامل للقطعة

Definition of Done:
□ القطع بتظهر مرتبة
□ Drag & Drop بيحفظ الترتيب
□ Swipe بيشيل القطعة من الجزلة
□ Tap بيفتح Detail Screen الكامل
```

### Phase 5 — Add Parcel Flow
```
5.1 أنشئ jazla_search_bar.dart
5.2 أنشئ jazla_parcel_result_tile.dart
5.3 أنشئ jazla_locked_badge.dart
5.4 أنشئ jazla_add_parcel_sheet.dart

Search Result Logic:
- نفس HoldingSearchService
- لكل قطعة: check isParcelUsed()
- لو مستخدمة: جيب اسم الجزلة للـ badge
- رتب: حرة أول ثم مقفولة

5.5 [+ شخص جديد] → Add Person Flow الحالي ثم رجوع
5.6 [+ قطعة لشخص موجود] → Add Parcel Flow الحالي ثم رجوع

بعد إضافة شخص/قطعة جديدة:
→ يرجع للـ Bottom Sheet
→ القطعة الجديدة تتضاف للجزلة تلقائياً

Definition of Done:
□ البحث بيعرض قطع مش أشخاص
□ Badge بيعرض اسم الجزلة
□ القطع المقفولة مش قابلة للإضافة
□ Add Person Flow بيشتغل وبيرجع صح
□ Add Parcel Flow بيشتغل وبيرجع صح
```

### Phase 6 — Quick View Sheet
```
6.1 أنشئ jazla_quick_view_sheet.dart
6.2 عرض البيانات الأساسية للقطعة
6.3 Toggles الوراثة والمفوض (temp edits)
6.4 لو "إضافة":
    - حفظ TempParcelEdits على القطعة الأصلية
    - إضافة parcelId للجزلة
    - إغلاق الـ Sheet
6.5 لو "إلغاء":
    - تجاهل TempParcelEdits
    - لا تغيير على القطعة الأصلية

Definition of Done:
□ Quick View بيعرض البيانات الأساسية
□ Toggles شغالة بشكل مؤقت
□ "إضافة" بيحفظ التعديلات وبيضيف للجزلة
□ "إلغاء" ما بيغيرش القطعة الأصلية
```

### Phase 7 — Export
```
7.1 أضف buildJazlaExportFileName() في export_service.dart
7.2 أضف exportJazla() method:
    - يجيب القطع بترتيب الجزلة
    - يبني الـ Excel بالأعمدة المتفق عليها
    - اسم الملف = cityName_jazlaName_date.xlsx
7.3 أضف Export button في jazla_detail_screen.dart

Definition of Done:
□ Excel بيطلع بالأعمدة الصح وبالترتيب
□ اسم الملف صح
□ RTL sheet
□ الملاحظات متجمعة بـ "، "
```

### Phase 8 — Final Verification
```
□ flutter analyze → zero issues
□ إنشاء جزلة جديدة
□ إضافة قطعة موجودة (حرة)
□ إضافة قطعة مع تعديل وراثة/مفوض في Quick View
□ إلغاء في Quick View → القطعة ما اتغيرتش
□ Badge على قطعة مقفولة بيعرض اسم الجزلة
□ Drag & Drop بيحفظ الترتيب
□ Tap على قطعة في الجزلة → Detail Screen كامل
□ إضافة شخص جديد من داخل الجزلة
□ Export بيطلع صح
□ Navigation: Home → جزل | Tools → أحواض + جزل
```

---

## 14. قواعد لا تُكسر

| القاعدة | التفصيل |
|---|---|
| ❌ لا نسخ للقطع | الجزلة تحتوي IDs فقط |
| ❌ لا قطعة في جزلتين | isParcelUsed() دايماً قبل الإضافة |
| ❌ لا تعديل دائم في Quick View | بس لو اليوزر ضغط "إضافة" |
| ✅ نفس الـ Logic الحالي | Search + Add + Detail كلهم نفسهم |
| ✅ Drag & Drop يحفظ | reorder() بعد كل تغيير |
| ✅ Export RTL | sheet_view.rightToLeft = true |
| ✅ Phase by phase | كل phase تكتمل قبل التالية |
| ✅ Use available skills | استخدم أي skill مفيدة |

---

## 15. اللي مش في الـ Scope دلوقتي

```
⏳ رفع الجزلة على Supabase
⏳ مشاركة الجزلة مع التيم
⏳ PDF export
⏳ فلتر/بحث داخل الجزلة
```

---

*آخر تحديث: أغسطس 2026*
*الإصدار: 1.0 — Local Jazla Feature*
