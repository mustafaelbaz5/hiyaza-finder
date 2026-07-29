/// One row of the merged holdings workbook (`البيانات المجمعة` sheet).
/// A holding ID can legitimately repeat across several parcels — this
/// class represents a single parcel row, not a deduplicated holding.
class Parcel {
  const Parcel({
    required this.holdingId,
    this.id = '',
    this.pageNumber,
    this.directorate,
    this.administration,
    this.basinName,
    this.basinCode,
    this.holderName,
    this.nationalId,
    this.borderEast,
    this.borderSouth,
    this.borderWest,
    this.borderNorth,
    this.landNumber,
    this.feddan,
    this.qirat,
    this.sahm,
    this.totalSqm,
    this.ownerName,
    this.associationName,
    this.cropType,
    this.notes,
    this.creditType = defaultCreditType,
    this.isInheritance = false,
    this.usageType = defaultUsageType,
  });

  /// Stable identity within a loaded dataset (the parse-order index).
  /// Used to key persistent edits so corrections re-apply on reload.
  final String id;

  final String holdingId; // رقم الحيازة
  final String? pageNumber; // رقم الصفحة بالسجل
  final String? directorate; // المديريه
  final String? administration; // الأداره
  final String? basinName; // اسم الحوض
  final String? basinCode; // كود الحوض
  final String? holderName; // اسم الحائز
  final String? nationalId; // الرقم القومي
  final String? borderEast; // الحد الشرقى
  final String? borderSouth; // الحد القبلى
  final String? borderWest; // الحد الغربى
  final String? borderNorth; // الحد البحرى
  final String? landNumber; // رقم الأرض
  final double? feddan; // فدان
  final double? qirat; // قيراط
  final double? sahm; // سهم
  final double? totalSqm; // إجمالي المساحة (م²)

  // --- Fields added in-app (never parsed from the Excel file) ---
  final String? ownerName; // اسم المالك
  final String? associationName; // اسم الجمعية — derived from the file name
  final String? cropType; // نوع الزرع
  final String? notes; // ملاحظات
  final String creditType; // نوع الائتمان: ملك / أوقاف
  final bool isInheritance; // وراثة
  final String usageType; // نوع الاستخدام

  static const String defaultCreditType = 'ملك';
  static const String defaultUsageType = 'زراعة';

  static const List<String> creditTypeOptions = <String>['ملك', 'أوقاف'];

  static const List<String> usageTypeOptions = <String>[
    'زراعة',
    'مباني',
    'استخدام اخر',
  ];

  static const List<String> cropTypeOptions = <String>[
    'قمح',
    'ارز',
    'ذرة',
    'فول',
    'برسيم',
    'فول صويا',
    'بنجر',
    'قطن',
    'قصب',
    'عنب',
    'باذنجان',
    'اخرى',
  ];

  static const List<String> notesOptions = <String>[
    'لا يوجد حصر ميداني',
    'وضع يد',
    'نقص بيانات الحصر',
    'تابعة الي جهة\\هيئة',
    'غير محجز',
    'اكثر من نقطة في نفس الحيازة',
    'استخدام غير زراعي',
    'حيازة توجد داخل اكثر من جمعية',
    'خطوط الحصر غير مطابقة للصورة',
    'لا يوجد خطوط حصر لتوضيح التقسيمات',
    'تعارض التقسيمات بين اكثر من موظف حصر ميداني',
  ];

  /// Sentinel meaning "leave this field unchanged" — lets every field below
  /// be explicitly overridden, including to `null`, which a plain `??`
  /// fallback can't express (mirrors `HomeState.copyWith`'s `_unset`).
  static const Object _unset = Object();

  /// Every field is individually overridable — pass a new value (or
  /// explicit `null` to clear a nullable field) to change it, or omit it to
  /// keep the original. Used both for whole-parcel edits and single-field
  /// inline edits.
  Parcel copyWith({
    final String? id,
    final Object? pageNumber = _unset,
    final Object? directorate = _unset,
    final Object? administration = _unset,
    final Object? basinName = _unset,
    final Object? basinCode = _unset,
    final Object? holderName = _unset,
    final Object? nationalId = _unset,
    final Object? landNumber = _unset,
    final Object? feddan = _unset,
    final Object? qirat = _unset,
    final Object? sahm = _unset,
    final Object? totalSqm = _unset,
    final Object? ownerName = _unset,
    final Object? associationName = _unset,
    final Object? cropType = _unset,
    final Object? notes = _unset,
    final Object? creditType = _unset,
    final Object? isInheritance = _unset,
    final Object? usageType = _unset,
  }) {
    T resolve<T>(final Object? value, final T fallback) =>
        identical(value, _unset) ? fallback : value as T;

    return Parcel(
      id: id ?? this.id,
      holdingId: holdingId,
      pageNumber: resolve(pageNumber, this.pageNumber),
      directorate: resolve(directorate, this.directorate),
      administration: resolve(administration, this.administration),
      basinName: resolve(basinName, this.basinName),
      basinCode: resolve(basinCode, this.basinCode),
      holderName: resolve(holderName, this.holderName),
      nationalId: resolve(nationalId, this.nationalId),
      borderEast: borderEast,
      borderSouth: borderSouth,
      borderWest: borderWest,
      borderNorth: borderNorth,
      landNumber: resolve(landNumber, this.landNumber),
      feddan: resolve(feddan, this.feddan),
      qirat: resolve(qirat, this.qirat),
      sahm: resolve(sahm, this.sahm),
      totalSqm: resolve(totalSqm, this.totalSqm),
      ownerName: resolve(ownerName, this.ownerName),
      associationName: resolve(associationName, this.associationName),
      cropType: resolve(cropType, this.cropType),
      notes: resolve(notes, this.notes),
      creditType: resolve(creditType, this.creditType),
      isInheritance: resolve(isInheritance, this.isInheritance),
      usageType: resolve(usageType, this.usageType),
    );
  }

  /// The fields a user can correct via the detail card's inline field
  /// [ParcelEditsStore]. This is the single source of truth for what gets
  /// persisted per-parcel — extend this together with [fromEditableJson]
  /// when adding a new editable field, instead of hand-listing fields in
  /// multiple places.
  Map<String, dynamic> toEditableJson() => <String, dynamic>{
        'directorate': directorate,
        'administration': administration,
        'basinName': basinName,
        'basinCode': basinCode,
        'holderName': holderName,
        'nationalId': nationalId,
        'landNumber': landNumber,
        'feddan': feddan,
        'qirat': qirat,
        'sahm': sahm,
        'totalSqm': totalSqm,
        'ownerName': ownerName,
        'cropType': cropType,
        'notes': notes,
        'creditType': creditType,
        'isInheritance': isInheritance,
        'usageType': usageType,
      };

  /// Rebuilds a parcel from [original] — which supplies the never-editable
  /// fields (id, holdingId, pageNumber, borders, associationName) — overlaid
  /// with a saved [json] snapshot produced by [toEditableJson].
  factory Parcel.fromEditableJson(
    final Parcel original,
    final Map<String, dynamic> json,
  ) {
    double? d(final String key) => (json[key] as num?)?.toDouble();
    return Parcel(
      id: original.id,
      holdingId: original.holdingId,
      pageNumber: original.pageNumber,
      borderEast: original.borderEast,
      borderSouth: original.borderSouth,
      borderWest: original.borderWest,
      borderNorth: original.borderNorth,
      associationName: original.associationName,
      directorate: json['directorate'] as String?,
      administration: json['administration'] as String?,
      basinName: json['basinName'] as String?,
      basinCode: json['basinCode'] as String?,
      holderName: json['holderName'] as String?,
      nationalId: json['nationalId'] as String?,
      landNumber: json['landNumber'] as String?,
      feddan: d('feddan'),
      qirat: d('qirat'),
      sahm: d('sahm'),
      totalSqm: d('totalSqm'),
      ownerName: json['ownerName'] as String?,
      cropType: json['cropType'] as String?,
      notes: json['notes'] as String?,
      creditType: json['creditType'] as String? ?? defaultCreditType,
      isInheritance: json['isInheritance'] as bool? ?? false,
      usageType: json['usageType'] as String? ?? defaultUsageType,
    );
  }
}
