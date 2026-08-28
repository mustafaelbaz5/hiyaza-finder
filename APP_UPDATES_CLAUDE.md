# CLAUDE.md — HiyazaFinder App Updates

## Remaining Implementation Requirements

> **اقرأ الملف ده بالكامل قبل أي سطر كود.**
> ده المرجع للـ updates الجديدة بعد الـ refactor الأول.
> الـ pattern والـ architecture موجودين في APP_CLAUDE.md — اتبعهم.
> أي قرار مش موجود هنا → اسأل الأول.
> استخدم أي skill متاحة لو هتحسّن الـ output.

---

## 0. المبادئ — تفضل كما هي

```
✅ data/logic/ui pattern
✅ SOLID + Clean Code
✅ Local-First
✅ One class per file
✅ One widget per file
✅ ملف أقل من 150 سطر
✅ Use available skills
```

---

## 1. Basin Details

### 1.1 الـ Model

**ملف:** `features/cities/data/model/basin.dart`

```dart
class Basin {
  final String id;
  final String cityId;
  final String basinName;
  final String? basinCode;
  final double totalFeddan;
  final double totalQirat;
  final double totalSahm;
  final double totalSqm;
  final int parcelCount;
}
```

### 1.2 الـ Download

الأحواض بتتحمّل مع البلد في نفس الـ request — مش request منفصل.

**عدّل:** `features/cities/data/remote/city_remote_ds.dart`

```dart
// بدل ما بتجيب parcels بس
// دلوقتي بتجيب parcels + basins في نفس الوقت

Future<CityDownloadResult> downloadCityData(String cityId);

class CityDownloadResult {
  final List<Parcel> parcels;
  final List<Basin> basins;    // ← NEW
}
```

### 1.3 الـ Snapshot

**عدّل:** `features/cities/data/model/city_snapshot.dart`

```dart
class CitySnapshot {
  final City city;
  final List<Parcel> parcels;
  final List<Basin> basins;    // ← NEW
  final DateTime downloadedAt;
}
```

### 1.4 الـ Cache

**عدّل:** `features/cities/data/local/city_snapshot_cache.dart`

```dart
// basins بتتحفظ مع الـ snapshot في نفس الـ JSON file
// مفيش cache منفصل للـ basins
```

### Definition of Done

```
□ Basin model موجود
□ Download بيجيب parcels + basins في request واحد
□ CitySnapshot بيحتوي على basins
□ Basins بتتحفظ locally مع الـ snapshot
□ Basins متاحة offline بعد أول download
```

---

## 2. Add Person / Add Holding

### 2.1 شخص جديد بحيازة جديدة

**الـ Required Fields:**

```
رقم الحيازة         ← يدخله اليوزر
اسم الحائز         ← يدخله اليوزر
اسم الحوض          ← يختاره من قائمة الأحواض
كود الحوض          ← يتضاف تلقائياً بناءً على الحوض المختار
المساحة (فدان/قيراط/سهم) ← يدخلها يدوياً، 3 حقول منفصلة
نوع المحصول         ← required لو نوع الاستخدام = زراعة
مراحل النمو         ← required لو نوع الاستخدام = زراعة
نوع الاستخدام       ← default = زراعة
```

**الـ Default Values:**

```
رقم الأرض     = "0"   (مش -1)
اسم المالك    = اسم الحائز (تلقائي)
نوع الاستخدام = زراعة
الملاحظات    = [] (فاضية — مش required)
```

**الـ Hidden Fields (مش بتظهر في Add Screen):**

```
رقم الصفحة بالسجل   ← مش required في الإضافة
الرقم الموحد للحيازة ← مش required في الإضافة
الرقم القومي        ← اختياري
حد بحري/قبلي/شرقي/غربي ← اختيارية
```

### 2.2 حيازة جديدة لشخص موجود

**البحث:**

- اليوزر بيبحث بـ رقم الحيازة
- Exact match (زي الـ search algorithm)
- لو لقى → بيعرض بيانات الشخص للتأكيد

**البيانات اللي بتتورث تلقائياً:**

```
اسم الحائز         ← من الشخص الموجود
الرقم القومي       ← من الشخص الموجود
رقم الحيازة        ← من الشخص الموجود
اسم المالك         ← من الشخص الموجود
```

**البيانات اللي اليوزر بيدخلها:**

```
اسم الحوض    ← يختار من قائمة
كود الحوض   ← تلقائي
المساحة      ← فدان/قيراط/سهم
نوع المحصول  ← required لو زراعة
مراحل النمو  ← required لو زراعة
```

**الملاحظات:**

```
= [] فاضية by default — مش required
```

### 2.3 Basin Selection Logic

```dart
// لما اليوزر يختار حوض من القائمة:
void onBasinSelected(Basin basin) {
  // 1. اتحط اسم الحوض
  holdingData.basinName = basin.basinName;
  // 2. اتحط كود الحوض تلقائياً
  holdingData.basinCode = basin.basinCode;
  // لا يوجد تدخل من اليوزر في كود الحوض
}

// القائمة بتيجي من:
// CitySnapshot.basins — المحملة locally
```

### Definition of Done

```
□ Add Screen بيفرّق بين شخص جديد وشخص موجود
□ البحث بـ رقم الحيازة exact match
□ البيانات بتتورث صح للشخص الموجود
□ كود الحوض بيتضاف تلقائياً لما الحوض يتاختار
□ رقم الأرض default = "0"
□ الملاحظات فاضية by default
□ نوع المحصول + مراحل النمو required بس لو زراعة
```

---

## 3. Owner Name / المفوض Toggle

### 3.1 خانة اسم المالك

```dart
// اسم المالك بيظهر دايماً في Detail Screen
// Default = اسم الحائز (read-only لو المفوض مش مفعّل)

// لما المفوض toggle = false:
//   اسم المالك = اسم الحائز (تلقائي، غير قابل للتعديل)

// لما المفوض toggle = true:
//   اسم المالك = قابل للتعديل
//   يفتح Dialog لإدخال الاسم الجديد
```

### 3.2 المفوض Logic

```dart
void onDelegateToggled(bool enabled, Parcel parcel) {
  if (!enabled) {
    // أرجع اسم المالك للـ default
    ownerName = parcel.holderName;
    // شيل note المفوض من القائمة لو موجودة
    notes.removeWhere((n) => n.startsWith('مفوض عنه'));
    return;
  }

  // افتح Dialog لإدخال اسم المالك
  showOwnerNameDialog(
    onConfirm: (newOwnerName) {
      // Validation: لازم يختلف عن اسم الحائز
      if (newOwnerName == parcel.holderName) {
        showError('اسم المالك لازم يختلف عن اسم الحائز');
        return;
      }
      // حفظ اسم المالك الجديد
      ownerName = newOwnerName;
      // إضافة note تلقائية
      notes.add('مفوض عنه ${parcel.holderName}');
    },
  );
}
```

### 3.3 ورثة + مفوض مع بعض

```dart
// is_inheritance = true AND is_delegate = true:
// اسم المالك في العرض: "ورثة [اسم المالك]"
// اسم الحائز في العرض: "[اسم الحائز]" (من غير ورثة)
// note المفوض بتتضاف كمان

String displayOwnerName(LocalParcelData data, String holderName) {
  final owner = data.ownerName ?? holderName;
  return data.isInheritance ? 'ورثة $owner' : owner;
}

String displayHolderName(LocalParcelData data, String holderName) {
  // ورثة بتتضاف للحائز بس لو مفيش مفوض
  if (data.isDelegate) return holderName;
  return data.isInheritance ? 'ورثة $holderName' : holderName;
}
```

### Definition of Done

```
□ اسم المالك دايماً ظاهر (default = اسم الحائز)
□ اسم المالك read-only لو المفوض مش مفعّل
□ Dialog بيظهر لما المفوض يتفعّل
□ Validation: اسم المالك != اسم الحائز
□ Note تلقائية "مفوض عنه ..." بتتضاف
□ إلغاء المفوض → اسم المالك يرجع + note تتشال
```

---

## 4. نوع الاستخدام + نوع المحصول + مراحل النمو

### 4.1 الـ Options

```dart
enum UsageType {
  agricultural,  // زراعة ← default
  buildings,     // مباني
  fallow,        // بور
}
```

### 4.2 Conditional Fields Logic

```dart
// نوع الاستخدام = زراعة:
//   نوع المحصول  → ظاهر + required
//   مراحل النمو  → ظاهر + required
//   بيظهروا في Copy All

// نوع الاستخدام = مباني أو بور:
//   نوع المحصول  → مخفي تماماً (مش disabled — مخفي)
//   مراحل النمو  → مخفي تماماً
//   مش بيظهروا في Copy All
//   قيمتهم بتتمسح لو تغيّر من زراعة

bool get showCropFields => usageType == UsageType.agricultural;
```

### 4.3 Auto Notes Bidirectional

```dart
void onUsageTypeChanged(UsageType type) {
  switch (type) {
    case UsageType.buildings:
      // أضف note
      _addNoteIfAbsent('الأرض بها مباني');
      // شيل note البور لو موجودة
      notes.remove('الأرض بور أو غير مزروعة');
      // مسح قيم المحصول والنمو
      cropType = null;
      growthStage = null;
      break;

    case UsageType.fallow:
      _addNoteIfAbsent('الأرض بور أو غير مزروعة');
      notes.remove('الأرض بها مباني');
      cropType = null;
      growthStage = null;
      break;

    case UsageType.agricultural:
      notes.remove('الأرض بها مباني');
      notes.remove('الأرض بور أو غير مزروعة');
      break;
  }
}

void onNoteSelected(String note) {
  switch (note) {
    case 'الأرض بها مباني':
      usageType = UsageType.buildings;
      _addNoteIfAbsent(note);
      break;
    case 'الأرض بور أو غير مزروعة':
      usageType = UsageType.fallow;
      _addNoteIfAbsent(note);
      break;
    default:
      _addNoteIfAbsent(note);
  }
}

void _addNoteIfAbsent(String note) {
  if (!notes.contains(note)) notes.add(note);
}
```

### Definition of Done

```
□ 3 options فقط: زراعة / مباني / بور
□ نوع المحصول + مراحل النمو بيختفوا لو مش زراعة
□ Note بتتضاف تلقائياً لما نوع الاستخدام يتغير
□ نوع الاستخدام بيتغير لما النوت تتاختار
□ لا تعارض بين مباني ونوت البور
```

---

## 5. Notes System

### 5.1 Default Notes List

```dart
// ثابتة في الكود كـ default
// اليوزر يقدر يضيف/يشيل من خلال settings

const defaultNotesList = [
  'الأرض بها مباني',
  'الأرض بور أو غير مزروعة',
  'الأرض غير محيز',
  // + أي notes تلقائية من fields تانية
];
```

### 5.2 Custom Notes List

```dart
// مخزّنة في SharedPreferences
// key: 'custom_notes_list'
// اليوزر يقدر:
// - يضيف note جديدة
// - يشيل note موجودة
// - يعدّل على قائمته

class NotesListService {
  Future<List<String>> getUserNotesList();
  // بيرجع: defaultNotesList + notes اليوزر المضافة

  Future<void> addNote(String note);
  Future<void> removeNote(String note);
}
```

### 5.3 الـ Widget

**ملف:** `features/holdings/ui/widgets/notes_field.dart`

```
┌─────────────────────────────────┐
│  الملاحظات                      │
│  ┌──────────────────────────┐  │
│  │ مفوض عنه مصطفي      [×] │  │
│  │ الأرض غير محيز       [×] │  │
│  └──────────────────────────┘  │
│  [+ إضافة ملاحظة]              │
└─────────────────────────────────┘

لما يضغط "+ إضافة":
┌─────────────────────────────────┐
│  إضافة ملاحظة                   │
│  [اكتب ملاحظة...]               │
│  ─────────────────────────────  │
│  الأرض بها مباني           [+] │
│  الأرض بور أو غير مزروعة  [+] │
│  الأرض غير محيز            [+] │
│  [إضافة للقائمة الخاصة]         │
│                    [تأكيد]      │
└─────────────────────────────────┘
```

### 5.4 Notes Settings

متاحة من City Tools Screen:

- عرض القائمة الحالية
- إضافة note جديدة للقائمة
- حذف note من القائمة
- مش بتأثر على notes المضافة فعلاً للقطع

### Definition of Done

```
□ Default list = 3 notes ثابتة
□ اليوزر يقدر يضيف للقائمة من Settings
□ Notes على القطع مستقلة عن تعديل القائمة
□ Bidirectional مع نوع الاستخدام شغال
□ Notes التلقائية (مفوض، مباني، بور) بتتضاف تلقائياً
□ اليوزر يقدر يكتب free text
```

---

## 6. Copy All — Format النهائي

### 6.1 الـ Format

```dart
String buildCopyAllText({
  required Parcel parcel,
  required LocalParcelData local,
  required AssociationType associationType,
}) {
  final buffer = StringBuffer();

  // دايماً موجودين
  buffer.writeln('ID: ${parcel.id}');
  buffer.writeln('رقم الحيازة: ${parcel.holdingIdNumber ?? "0"}');
  buffer.writeln('اسم المالك: ${displayOwnerName(local, parcel.holderName)}');
  buffer.writeln('اسم الحائز: ${displayHolderName(local, parcel.holderName)}');
  buffer.writeln('الرقم القومي: ${parcel.nationalId ?? ""}');
  buffer.writeln('عدد القطع: ${parcel.parcelCountInHolding ?? 1}');
  buffer.writeln('اسم الحوض: ${parcel.basinName ?? ""}');
  buffer.writeln('كود الحوض: ${parcel.basinCode ?? ""}');
  buffer.writeln('المساحة:');
  buffer.writeln('  فدان: ${parcel.areaFeddan}');
  buffer.writeln('  قيراط: ${parcel.areaQirat}');
  buffer.writeln('  سهم: ${parcel.areaSahm}');

  // بس لو نوع الاستخدام = زراعة
  if (local.usageType == UsageType.agricultural) {
    buffer.writeln('نوع المحصول: ${local.cropType ?? ""}');
    buffer.writeln('مراحل النمو: ${local.growthStage ?? ""}');
  }

  buffer.writeln('نوع الاستخدام: ${local.usageType.displayName}');

  // نوع الائتمان بناءً على نوع البلد
  final creditType = associationType == AssociationType.credit
      ? 'ملك'
      : 'إصلاح مُملك';
  buffer.writeln('نوع الائتمان: $creditType');

  // الملاحظات
  if (local.notes.isNotEmpty) {
    buffer.writeln('الملاحظات: ${local.notes.join("، ")}');
  }

  return buffer.toString().trim();
}
```

### 6.2 نوع الائتمان Logic

```dart
// بييجي من نوع البلد — مش field اليوزر بيدخله
// ائتمان زراعي → "ملك"
// إصلاح زراعي  → "إصلاح مُملك"

// AssociationType بييجي من CitySnapshot.city.associationType
```

### Definition of Done

```
□ Format منسّق وواضح
□ نوع المحصول + مراحل النمو بيظهروا بس لو زراعة
□ اسم المالك دايماً موجود (default = اسم الحائز)
□ نوع الائتمان بييجي تلقائياً من نوع البلد
□ Notes بتتجمع بـ "، "
□ مفيش حقول فاضية تظهر في النسخ
```

---

## 7. Search Algorithm الجديد

### 7.1 رقم الحيازة — Exact Match

```dart
// مش بيتغير من الـ version السابقة
List<HoldingGroup> searchByHoldingNumber(String query) {
  final normalized = normalizeHoldingNumber(query);
  final matched = parcels.where(
    (p) => normalizeHoldingNumber(p.holdingIdNumber ?? '') == normalized,
  );
  return groupByHolding(matched.toList());
}
```

### 7.2 اسم الحائز — StartsWith مع Priority

```dart
// بدل contains → startsWith على أي جزء من الاسم
// مع priority بناءً على موقع الـ match

class NameSearchResult {
  final HoldingGroup holding;
  final int priority; // 0 = أعلى أولوية
}

List<HoldingGroup> searchByHolderName(String query) {
  final normalized = ArabicNormalizer.normalize(query);
  final results = <NameSearchResult>[];

  for (final group in holdingGroups) {
    final nameParts = group.holderName.split(' ');

    for (int i = 0; i < nameParts.length; i++) {
      final part = ArabicNormalizer.normalize(nameParts[i]);
      if (part.startsWith(normalized)) {
        results.add(NameSearchResult(
          holding: group,
          priority: i, // الاسم الأول = 0، الثاني = 1، إلخ
        ));
        break; // أول match في الاسم ده كافي
      }
    }
  }

  // ترتيب: priority أقل = يجي أول
  results.sort((a, b) => a.priority.compareTo(b.priority));
  return results.map((r) => r.holding).toList();
}
```

### 7.3 Search Type Detection

```dart
SearchType detectSearchType(String query) {
  final trimmed = query.trim();

  // أرقام فقط → رقم الحيازة
  if (RegExp(r'^[\d٠-٩]+$').hasMatch(trimmed)) {
    return SearchType.holdingNumber;
  }

  // UUID format → Parcel ID
  if (RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(trimmed)) {
    return SearchType.parcelId;
  }

  // غير كده → اسم الحائز
  return SearchType.holderName;
}
```

### 7.4 Search Result Card

```
┌─────────────────────────────────┐
│  #48 — أحمد محمود               │
│  3 قطع | البحيره                │
└─────────────────────────────────┘
```

- كل holding = card واحد
- بيظهر: رقم الحيازة + اسم الحائز + عدد القطع + اسم الحوض
- لما يدخل → Detail Screen بكل القطع

### Definition of Done

```
□ رقم الحيازة: exact match فقط
□ اسم الحائز: startsWith على كل جزء من الاسم
□ Priority: الاسم الأول قبل الثاني قبل الثالث
□ UUID: startsWith
□ نتائج مجمّعة بـ holding (مش قطعة قطعة)
```

---

## 8. Default Values الجديدة

```dart
// رقم الأرض
const defaultLandNumber = '0';    // بدل -1

// رقم الحيازة للقطع المفقودة
const defaultHoldingNumber = '0'; // بدل -1

// في كل الأماكن اللي كانت بتستخدم -1:
// - Add Record Screen
// - Missing Holding ID Screen
// - LocalAddedParcelsStore
// - Copy All format
// - Export
```

### Definition of Done

```
□ مفيش -1 في أي قيمة default
□ رقم الأرض default = "0"
□ رقم الحيازة المفقود = "0"
```

---

## 9. Navigation & UI Restructure

### 9.1 Home Screen Header الجديد

```
┌─────────────────────────────────────────────┐
│  [🔍 بحث بالاسم أو الرقم...]               │
│                          [🏘] [⚙️] [🔄]     │
└─────────────────────────────────────────────┘
```

**الأيقونات:**

```
🏘  → Basins Page
⚙️  → City Tools Screen
🔄  → تغيير المدينة (City Picker)
```

**بيتشال من الـ Header:**

```
❌ Wi-Fi / Internet status indicator
❌ Basin filter icon
```

**بيفضل في الـ Home:**

```
✅ قائمة الحيازات (كل الأحواض مع بعض)
✅ FAB لإضافة شخص
```

### 9.2 Basins Page (منفصلة)

**Route:** `/basins`

```
┌─────────────────────────────────┐
│  ← الأحواض                      │
├─────────────────────────────────┤
│  ┌─────────────────────────┐   │
│  │ الباشا          69/69  │   │
│  │ كود: 001               │   │
│  │ ████████████ 100%       │   │
│  ├─────────────────────────┤   │
│  │ البحيره         45/131  │   │
│  │ كود: 002               │   │
│  │ ████░░░░░░░  34%        │   │
│  └─────────────────────────┘   │
└─────────────────────────────────┘
```

**كل Basin Card يحتوي:**

```
اسم الحوض
كود الحوض
عدد القطع completed / الإجمالي
Progress bar
```

### 9.3 Basin Detail Screen

**Route:** `/basins/:basinName`

```
┌─────────────────────────────────┐
│  ← الباشا               [📤]   │
├─────────────────────────────────┤
│  ┌─ معلومات الحوض ───────────┐ │
│  │ كود الحوض:  001           │ │
│  │ إجمالي القطع: 69          │ │
│  │ المساحة الكلية: xx م²     │ │
│  └────────────────────────────┘ │
│                                 │
│  [الكل] [ناقصة ○] [مكتملة ✅]   │
│                                 │
│  ┌─────────────────────────┐   │
│  │ #001 — محمد أحمد  ✅   │   │
│  │ قطعة واحدة             │   │
│  ├─────────────────────────┤   │
│  │ #003 — إبراهيم السيد ○ │   │
│  │ 3 قطع                  │   │
│  └─────────────────────────┘   │
│                    [+ إضافة]   │
└─────────────────────────────────┘
```

**[📤] Export Button:**

```
يفتح Bottom Sheet:
┌─────────────────────────────────┐
│  تصدير بيانات الباشا            │
│                                 │
│  ○ كل البيانات                  │
│  ● المضافة يدوياً فقط           │
│                                 │
│       [تصدير Excel]             │
└─────────────────────────────────┘
```

### 9.4 شيل Wi-Fi Indicator

**احذف من:**

```
❌ home_top_bar.dart → _ConnectionQualityBadge widget
❌ أي مكان تاني بيعرض internet status
```

**فضّل:**

```
✅ Internet check بس وقت الـ download
✅ Error message واضحة لو الـ download فشل بسبب الـ network
```

### Definition of Done

```
□ Wi-Fi indicator اتشال من كل الـ UI
□ Home header فيه: search + 3 أيقونات بس
□ Basins Page منفصلة بـ route خاص
□ Basin Detail بيعرض: معلومات + حيازات + export
□ Export من Basin = bottom sheet بسيط
□ Home بتعرض كل الحيازات (مش بتفلتر بحوض)
```

---

## 10. City Tools Screen — التعديل

### 10.1 بيتشال

```
❌ إحصائيات الأحواض section كاملاً
```

### 10.2 بيتضاف في الأول

**City Info Card:**

```
┌─────────────────────────────────┐
│  شنشا                           │
│  الائتمان الزراعي               │
│  ──────────────────────────     │
│  اسم الجمعية:                   │
│  شنشا-الائتمان الزراعي  [نسخ]  │
│  ──────────────────────────     │
│  كود الجمعية:                   │
│  323925               [نسخ]    │
│  ──────────────────────────     │
│  المديرية: الدقهليه             │
│  الإدارة: اجا                  │
└─────────────────────────────────┘
```

**[نسخ] بجانب اسم الجمعية:**

- ينسخ اسم الجمعية للـ clipboard

**[نسخ] بجانب كود الجمعية:**

- ينسخ كود الجمعية للـ clipboard

### Definition of Done

```
□ City Info Card في أول الصفحة
□ نسخ اسم الجمعية شغال
□ نسخ كود الجمعية شغال
□ إحصائيات الأحواض اتشالت
```

---

## 11. Detail Screen — Parcel Sort

```dart
// القطع في Detail Screen مرتبة بـ اسم الحوض أبجدياً
// مش بتاريخ الإضافة

List<Parcel> sortParcelsByBasin(List<Parcel> parcels) {
  return parcels..sort(
    (a, b) => (a.basinName ?? '').compareTo(b.basinName ?? ''),
  );
}
```

---

## 12. Implementation Phases

### Phase 1 — Basin Model + Download

```
1.1 أنشئ features/cities/data/model/basin.dart
1.2 عدّل city_remote_ds.dart → downloadCityData() يرجع parcels + basins
1.3 عدّل city_snapshot.dart → أضف basins field
1.4 عدّل city_snapshot_cache.dart → يحفظ basins في الـ JSON
1.5 عدّل city_repo_impl.dart → يمرّر basins للـ snapshot

Definition of Done:
□ Basin model موجود
□ Basins بتتحمّل مع البلد
□ Basins بتتحفظ locally
```

### Phase 2 — Navigation Restructure

```
2.1 عدّل home_top_bar.dart:
    ❌ شيل Wi-Fi indicator
    ❌ شيل Basin filter icon
    ✅ أضف أيقونة Basins Page
    ✅ أضف أيقونة City Tools
    ✅ أضف أيقونة تغيير المدينة

2.2 أنشئ features/holdings/ui/basins_page.dart
2.3 أنشئ features/holdings/ui/basin_detail_screen.dart
2.4 أنشئ features/holdings/ui/widgets/basin_card.dart
2.5 أنشئ features/holdings/ui/widgets/basin_info_card.dart
2.6 أنشئ features/holdings/ui/widgets/export_bottom_sheet.dart
2.7 عدّل app_router.dart → أضف /basins و /basins/:name routes

Definition of Done:
□ Wi-Fi indicator مش موجود
□ Basins Page شغالة من الأيقونة
□ Basin Detail بيعرض المعلومات والحيازات
□ Export bottom sheet بيشتغل
```

### Phase 3 — City Tools Update

```
3.1 عدّل city_tools_screen.dart:
    ❌ شيل إحصائيات الأحواض
    ✅ أضف City Info Card في الأول

3.2 أنشئ features/cities/ui/widgets/city_info_card.dart

Definition of Done:
□ City Info Card ظاهر في الأول
□ نسخ اسم الجمعية شغال
□ نسخ الكود شغال
□ إحصائيات الأحواض مش موجودة
```

### Phase 4 — Add Record Screen Restructure

```
4.1 عدّل add_record_screen.dart:
    - Tab/Toggle: شخص جديد / شخص موجود
    - شخص جديد → كل الـ required fields
    - شخص موجود → search برقم الحيازة + inherits بيانات

4.2 أنشئ features/holdings/ui/widgets/basin_picker.dart
    - يعرض قائمة الأحواض من CitySnapshot
    - الاختيار → يتحط basin_name + basin_code تلقائياً

4.3 أنشئ features/holdings/ui/widgets/area_input.dart
    - 3 حقول منفصلة: فدان / قيراط / سهم

4.4 عدّل default values:
    - رقم الأرض = "0"
    - رقم الحيازة المفقود = "0"

Definition of Done:
□ Add Screen بيفرّق بين حالتين
□ Basin picker بيتحط كود الحوض تلقائياً
□ Default values = "0" مش "-1"
□ Notes فاضية by default
```

### Phase 5 — نوع الاستخدام + Notes System

```
5.1 أنشئ UsageType enum في data/model/
5.2 عدّل LocalParcelData → usageType + notes: List<String>
5.3 عدّل ParcelEditsStore → يحفظ notes كـ List
5.4 أنشئ NotesListService في data/local/
5.5 أنشئ features/holdings/ui/widgets/notes_field.dart
5.6 أنشئ features/holdings/ui/widgets/usage_type_selector.dart
5.7 نفّذ Bidirectional logic بين notes ونوع الاستخدام
5.8 عدّل Detail Screen:
    - نوع المحصول + مراحل النمو بيختفوا لو مش زراعة

Definition of Done:
□ UsageType enum: agricultural/buildings/fallow
□ Bidirectional note ↔ نوع الاستخدام شغال
□ Notes field بيعرض chips + إضافة
□ نوع المحصول + مراحل النمو مخفيين لو مش زراعة
□ Default list = 3 notes
```

### Phase 6 — Owner Name + Toggles

```
6.1 عدّل toggle_field_row.dart (ورثة + مفوض)
6.2 أنشئ features/holdings/ui/widgets/owner_name_field.dart
    - ظاهر دايماً
    - read-only لو المفوض مش مفعّل
    - Dialog لما المفوض يتفعّل
6.3 نفّذ validation: owner_name != holder_name
6.4 Auto-note "مفوض عنه ..." بتتضاف/بتتشال

Definition of Done:
□ اسم المالك دايماً ظاهر
□ Dialog بيفتح لما المفوض يتفعّل
□ Validation شغالة
□ Auto-note شغالة
□ إلغاء المفوض → يرجع كل حاجة للـ default
```

### Phase 7 — Copy All + Search

```
7.1 عدّل clipboard_formatter.dart → buildCopyAllText()
    - نوع الائتمان من AssociationType
    - نوع المحصول + مراحل النمو conditional
    - Notes مجمّعة بـ "، "
    - Format منسّق

7.2 عدّل holding_search_service.dart:
    - searchByHolderName → startsWith + priority
    - Priority based on word position in name

Definition of Done:
□ Copy All format صح ومنسّق
□ نوع الائتمان: ملك / إصلاح مُملك
□ Search: startsWith مع priority
□ Search results مجمّعة بـ holding
```

### Phase 8 — Detail Screen + Sort

```
8.1 عدّل detail_screen.dart:
    - القطع مرتبة بـ basin name
    - Previous/Next navigation

8.2 عدّل parcel_detail_card.dart:
    - نوع المحصول + مراحل النمو conditional display
    - Owner name دايماً ظاهر

Definition of Done:
□ القطع مرتبة بـ basin name أبجدياً
□ Previous/Next شغالين
□ Fields conditional حسب نوع الاستخدام
```

### Phase 9 — Final Verification

```
□ flutter analyze → zero issues
□ Basin details بتتحمّل مع البلد
□ Wi-Fi indicator مش موجود
□ Navigation: Home → Basins → Basin Detail
□ Add Screen: شخص جديد + شخص موجود
□ Basin Picker بيحط كود الحوض تلقائياً
□ Default values = "0" مش "-1"
□ Notes bidirectional مع نوع الاستخدام
□ نوع المحصول + مراحل النمو مخفيين لو مش زراعة
□ Copy All format صح
□ نوع الائتمان: ملك / إصلاح مُملك
□ Search: startsWith + priority
□ City Tools: City Info Card في الأول
□ Export من Basin Detail شغال
```

---

## 13. قواعد إضافية

```
✅ مفيش -1 في أي قيمة default في المشروع كله
✅ Notes دايماً List<String> مش String
✅ basin_code دايماً بييجي تلقائياً — اليوزر مش بيدخله
✅ نوع الائتمان بييجي من AssociationType — مش field منفصل
✅ نوع المحصول + مراحل النمو بيختفوا في UI والـ Copy لو مش زراعة
✅ اسم المالك default = اسم الحائز دايماً
✅ Internet بيتستخدم بس وقت الـ download
```

---

_آخر تحديث: أغسطس 2026_
_الإصدار: 4.0 — Remaining Requirements_
