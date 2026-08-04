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
    this.reformType = defaultReformType,
    this.isInheritance = false,
    this.isDelegate = false,
    this.usageType = defaultUsageType,
    this.holdingsCount,
    this.pendingGroupId,
    this.reviewed = false,
    this.reviewedAt,
    this.reviewedBy,
    this.isFieldAdded = false,
  });

  /// Stable identity — for an imported parcel this is `holdings.id` as
  /// downloaded; for a field-added parcel it's the client-generated uuid
  /// assigned in `HoldingsRepository.addLocalParcel`, which is now also
  /// sent verbatim as `added_holdings.id` on sync (see `pushAddRecord` in
  /// `supabase_sync_api.dart`), rather than letting Postgres generate a
  /// separate one. This makes [id] the single value that ties a parcel
  /// together across the app, `holdings`/`added_holdings`, and
  /// `holding_edits.holding_id` — the key the dashboard's export can join
  /// on. Also used locally to key persistent edits so corrections re-apply
  /// on reload.
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
  final int?
      holdingsCount; // عدد القطع في الحيازة — from city_top_holders, read-only

  /// Only meaningful for a still-[isHoldingIdPending] parcel: when set (by
  /// `HoldingsRepository.addLocalParcel`, for a parcel added as a sibling of
  /// an existing pending person), [groupKey] uses this instead of [id] so
  /// the new parcel groups with its parent instead of appearing as its own
  /// unrelated person. `null` for every parcel that isn't such a sibling —
  /// including the pending person it was added to, which keeps grouping by
  /// its own [id] as before.
  final String? pendingGroupId;

  /// Completed/reviewed status — a field worker marks a parcel reviewed once
  /// its data has been copied out (see `HoldingsRepository.setParcelReviewed`).
  /// A direct-column field synced via `MarkParcelReviewedOperation`, never
  /// part of the `holding_edits`/[toEditableJson] overlay.
  final bool reviewed;
  final DateTime? reviewedAt;
  final String? reviewedBy; // profiles.id (uuid), null if never reviewed

  /// Discriminates which table this parcel lives in — `false` for an
  /// imported `holdings` row, `true` for a field-created `added_holdings`
  /// row. Structural/origin metadata, never user-edited; needed so
  /// `setParcelReviewed`/`pushMarkReviewed` know which table to UPDATE.
  final bool isFieldAdded;

  // --- Fields added in-app (never parsed from the Excel file) ---
  final String? ownerName; // اسم المالك
  final String? associationName; // اسم الجمعية — derived from the file name
  final String? cropType; // نوع الزرع
  final String? notes; // ملاحظات
  final String
      creditType; // نوع الائتمان: ملك / أوقاف (only for agricultural credit)
  final String reformType; // نوع الإصلاح: for agricultural reform cities
  final bool isInheritance; // وراثة
  final bool
      isDelegate; // مفوض — overrides the (ورثة) copy-all prefix with (مفوض عنه)
  final String usageType; // نوع الاستخدام

  /// Whether رقم الحيازة hasn't been officially assigned yet — true for a
  /// brand-new person added in the field whose display value is still one
  /// of the placeholder forms (`""`/`"-"` from older records, `"-1"` the
  /// current add-person form default). This only gates app-side concerns
  /// — [groupKey] (search/detail grouping) and the pending badge — not
  /// what gets sent to the server: `added_holdings_mapper.dart` sends
  /// whatever literal value is in the field, placeholder or not.
  bool get isHoldingIdPending {
    final String trimmed = holdingId.trim();
    return trimmed.isEmpty || trimmed == '-' || trimmed == '-1';
  }

  /// What actually identifies "one holding" for search grouping and the
  /// detail-screen lookup. For a confirmed record this is just
  /// [holdingId] (unchanged behavior). For a pending one, [holdingId] is
  /// a shared placeholder ("", "-", or "-1") that every new person has
  /// until given a real number — grouping by it directly would silently
  /// merge unrelated new people into one search result/detail screen, so
  /// pending records group by their own unique [id] instead.
  String get groupKey =>
      isHoldingIdPending ? 'pending:${pendingGroupId ?? id}' : holdingId;

  /// Whether a required text/choice field actually has a value — blank,
  /// whitespace-only, and the literal `"-"` placeholder (used elsewhere for
  /// "not yet corrected", e.g. رقم الأرض) all count as "not filled". Shared
  /// by every place that enforces a field must be explicitly chosen —
  /// `AddRecordScreen`'s save validation and `ParcelDetailCard`'s copy-all
  /// guard — so the "empty" definition can't drift between them.
  static bool isValueFilled(final String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isNotEmpty && trimmed != '-';
  }

  static const String defaultCreditType = 'ملك';
  static const String defaultReformType = 'إصلاح مُملك';
  static const String defaultUsageType = 'زراعة';

  static const List<String> creditTypeOptions = <String>['ملك', 'أوقاف'];

  static const List<String> reformTypeOptions = <String>[
    'إصلاح مُملك',
    'إصلاح اشتراكي',
    'إصلاح قانون ثلاثة',
  ];

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
    'غير محيز',
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
    final String? holdingId,
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
    final Object? reformType = _unset,
    final Object? isInheritance = _unset,
    final Object? isDelegate = _unset,
    final Object? usageType = _unset,
    final Object? holdingsCount = _unset,
    final Object? pendingGroupId = _unset,
    final bool? reviewed,
    final Object? reviewedAt = _unset,
    final Object? reviewedBy = _unset,
    final bool? isFieldAdded,
  }) {
    T resolve<T>(final Object? value, final T fallback) =>
        identical(value, _unset) ? fallback : value as T;

    return Parcel(
      id: id ?? this.id,
      holdingId: holdingId ?? this.holdingId,
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
      reformType: resolve(reformType, this.reformType),
      isInheritance: resolve(isInheritance, this.isInheritance),
      isDelegate: resolve(isDelegate, this.isDelegate),
      usageType: resolve(usageType, this.usageType),
      holdingsCount: resolve(holdingsCount, this.holdingsCount),
      pendingGroupId: resolve(pendingGroupId, this.pendingGroupId),
      reviewed: reviewed ?? this.reviewed,
      reviewedAt: resolve(reviewedAt, this.reviewedAt),
      reviewedBy: resolve(reviewedBy, this.reviewedBy),
      isFieldAdded: isFieldAdded ?? this.isFieldAdded,
    );
  }

  /// The fields a user can correct via the detail card's inline field
  /// [ParcelEditsStore]. This is the single source of truth for what gets
  /// persisted per-parcel — extend this together with [fromEditableJson]
  /// when adding a new editable field, instead of hand-listing fields in
  /// multiple places.
  Map<String, dynamic> toEditableJson() => <String, dynamic>{
        'holdingId': holdingId,
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
        'reformType': reformType,
        'isInheritance': isInheritance,
        'isDelegate': isDelegate,
        'usageType': usageType,
      };

  /// Rebuilds a parcel from [original] — which supplies the never-editable
  /// fields (id, pageNumber, borders, associationName) — overlaid with a
  /// saved [json] snapshot produced by [toEditableJson]. `holdingId` falls
  /// back to [original]'s value only for snapshots saved before it became
  /// editable.
  factory Parcel.fromEditableJson(
    final Parcel original,
    final Map<String, dynamic> json,
  ) {
    double? d(final String key) => (json[key] as num?)?.toDouble();
    return Parcel(
      id: original.id,
      holdingId: json['holdingId'] as String? ?? original.holdingId,
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
      reformType: json['reformType'] as String? ?? defaultReformType,
      isInheritance: json['isInheritance'] as bool? ?? false,
      isDelegate: json['isDelegate'] as bool? ?? false,
      usageType: json['usageType'] as String? ?? defaultUsageType,
    );
  }

  /// Full round-trip serialization (every field, including the
  /// never-editable ones) — used by the local city-snapshot cache, unlike
  /// [toEditableJson]/[fromEditableJson] which only cover the
  /// user-correctable subset for the local edit overlay.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'holdingId': holdingId,
        'pageNumber': pageNumber,
        'directorate': directorate,
        'administration': administration,
        'basinName': basinName,
        'basinCode': basinCode,
        'holderName': holderName,
        'nationalId': nationalId,
        'borderEast': borderEast,
        'borderSouth': borderSouth,
        'borderWest': borderWest,
        'borderNorth': borderNorth,
        'landNumber': landNumber,
        'feddan': feddan,
        'qirat': qirat,
        'sahm': sahm,
        'totalSqm': totalSqm,
        'ownerName': ownerName,
        'associationName': associationName,
        'cropType': cropType,
        'notes': notes,
        'creditType': creditType,
        'reformType': reformType,
        'isInheritance': isInheritance,
        'isDelegate': isDelegate,
        'usageType': usageType,
        'holdingsCount': holdingsCount,
        'pendingGroupId': pendingGroupId,
        'reviewed': reviewed,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewedBy': reviewedBy,
        'isFieldAdded': isFieldAdded,
      };

  factory Parcel.fromJson(final Map<String, dynamic> json) {
    double? d(final String key) => (json[key] as num?)?.toDouble();
    return Parcel(
      id: json['id'] as String? ?? '',
      holdingId: json['holdingId'] as String,
      pageNumber: json['pageNumber'] as String?,
      directorate: json['directorate'] as String?,
      administration: json['administration'] as String?,
      basinName: json['basinName'] as String?,
      basinCode: json['basinCode'] as String?,
      holderName: json['holderName'] as String?,
      nationalId: json['nationalId'] as String?,
      borderEast: json['borderEast'] as String?,
      borderSouth: json['borderSouth'] as String?,
      borderWest: json['borderWest'] as String?,
      borderNorth: json['borderNorth'] as String?,
      landNumber: json['landNumber'] as String?,
      feddan: d('feddan'),
      qirat: d('qirat'),
      sahm: d('sahm'),
      totalSqm: d('totalSqm'),
      ownerName: json['ownerName'] as String?,
      associationName: json['associationName'] as String?,
      cropType: json['cropType'] as String?,
      notes: json['notes'] as String?,
      creditType: json['creditType'] as String? ?? defaultCreditType,
      reformType: json['reformType'] as String? ?? defaultReformType,
      isInheritance: json['isInheritance'] as bool? ?? false,
      isDelegate: json['isDelegate'] as bool? ?? false,
      usageType: json['usageType'] as String? ?? defaultUsageType,
      holdingsCount: json['holdingsCount'] as int?,
      pendingGroupId: json['pendingGroupId'] as String?,
      reviewed: json['reviewed'] as bool? ?? false,
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
      reviewedBy: json['reviewedBy'] as String?,
      isFieldAdded: json['isFieldAdded'] as bool? ?? false,
    );
  }
}
