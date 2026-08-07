/// One row of the merged holdings workbook (`البيانات المجمعة` sheet).
/// A holding ID can legitimately repeat across several parcels — this
/// class represents a single parcel row, not a deduplicated holding.
class Parcel {
  const Parcel({
    required this.holdingId,
    this.id = '',
    this.sourceAddedHoldingId,
    this.personId,
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
    this.completedAt,
    this.completedBy,
    this.isFieldAdded = false,
    this.createdBy,
    this.holderNameFarmerCard,
    this.ownerNameFarmerCard,
    this.growthStages = defaultGrowthStage,
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
  final String? sourceAddedHoldingId;
  final String? personId;

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

  /// Staff/Dashboard-only data-quality review flag (`SYSTEM_DESIGN.md` §10)
  /// — distinct from field-worker completion ([completedAt]/[completedBy]
  /// below). The Flutter app never reads or writes these three fields (no
  /// screen shows them, no write path sets them); they exist purely so a
  /// row fetched from `holdings`/`added_holdings` round-trips its full
  /// column set without silently dropping data the Dashboard owns.
  final bool reviewed;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  /// Field-worker completion — set the moment a field worker copies this
  /// parcel's ID (`ParcelDetailCard._copyId`) or explicitly taps
  /// Finish/Reopen (`DetailScreen`), meaning "I've recorded everything I
  /// need from this record." A direct-column field synced via
  /// `CompleteParcelOperation`, never part of the `holding_edits`/
  /// [toEditableJson] overlay — same treatment [reviewed] used to get
  /// before this field existed (`REFACTOR_ROADMAP.md` Phase 9 #12).
  final DateTime? completedAt;
  final String? completedBy; // profiles.id (uuid), null if not completed

  /// Discriminates which table this parcel lives in — `false` for an
  /// imported `holdings` row, `true` for a field-created `added_holdings`
  /// row. Structural/origin metadata, never user-edited; needed so
  /// `setParcelReviewed`/`pushMarkReviewed` know which table to UPDATE.
  final bool isFieldAdded;

  /// `added_holdings.created_by` (`profiles.id`, uuid) — who added this
  /// record in the field (`REFACTOR_ROADMAP.md` Phase 11 §12). Only ever
  /// populated on an unpromoted `added_holdings` row: `holdings` has no
  /// `created_by` column, so this is `null` once the record is promoted
  /// (same lifecycle as [isFieldAdded] flipping to `false`). Resolving the
  /// creator's display email from this id is the UI layer's job
  /// (`HoldingsApi.fetchProfileEmails`), not stored on the entity itself.
  final String? createdBy;

  /// اسم الحائز كما يظهر في بطاقة الفلاح (farmer-card name) — distinct from
  /// [holderName], which is the Excel-import/edit-overlay identity field.
  /// `holdings.holder_name_farmer_card` / `added_holdings.holder_name_farmer_card`.
  final String? holderNameFarmerCard;

  /// اسم المالك كما يظهر في بطاقة الفلاح — the owner-side counterpart to
  /// [holderNameFarmerCard]. `holdings.owner_name_farmer_card` /
  /// `added_holdings.owner_name_farmer_card`.
  final String? ownerNameFarmerCard;

  /// مراحل النمو — free-text growth-stage note for the current crop.
  /// `holdings.growth_stages` / `added_holdings.growth_stages`.
  final String? growthStages;

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
      isHoldingIdPending
          ? 'pending:${personId ?? pendingGroupId ?? id}'
          : holdingId;

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

  /// Egyptian national ID format: exactly 14 digits. `null`/empty is
  /// considered valid here — the field itself isn't required (see
  /// `PROJECT_OBJECTIVES.md` §6.1: national ID format is a shared
  /// client+server rule, but the field's presence isn't mandatory).
  /// Server-side enforcement is the actual authority (`DATABASE_REFERENCE.md`
  /// §4.10); this is the fast-feedback client-side layer only.
  static bool isNationalIdValid(final String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return true;
    return RegExp(r'^\d{14}$').hasMatch(trimmed);
  }

  /// اسم الحائز, اسم الحوض, and نوع الزرع must all be explicitly filled/chosen
  /// (see [isValueFilled]), and [nationalId] must be a valid format if
  /// present. Shared by `AddRecordScreen`'s save gate and the review-
  /// completion gate (`ParcelDetailCard`'s Copy ID action, per
  /// `REFACTOR_ROADMAP.md` Phase 7) so "what counts as a complete record"
  /// can't drift between the two flows. Per-field message strings live in
  /// the UI layer (`.tr()` needs `easy_localization`, unavailable to this
  /// pure-Dart entity) — see `requiredFieldGaps` in
  /// `ui/widgets/parcel_detail_card.dart`/`add_record_screen.dart`.
  bool get hasRequiredFieldsFilled =>
      isValueFilled(holderName) &&
      isValueFilled(basinName) &&
      isValueFilled(cropType) &&
      isNationalIdValid(nationalId);

  static const String defaultCreditType = 'ملك';
  static const String defaultReformType = 'إصلاح مُملك';
  static const String defaultUsageType = 'زراعة';
  static const String defaultGrowthStage = 'مرحلة النمو الخضري';

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

  static const List<String> growthStageOptions = <String>[
    'مرحلة الإنبات',
    'مرحلة النمو الخضري',
    'مرحلة الإزهار والإثمار',
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
    notesOtherOption,
  ];

  /// The ملاحظات option that unlocks the free-text follow-up
  /// (`REFACTOR_ROADMAP.md` Phase 12) — same "specify other" pattern
  /// `cropTypeOtherOption` already established, for when none of the fixed
  /// options fit.
  static const String notesOtherOption = 'أخرى';

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
    final String? sourceAddedHoldingId,
    final String? personId,
    final String? holdingId,
    final Object? pageNumber = _unset,
    final Object? directorate = _unset,
    final Object? administration = _unset,
    final Object? basinName = _unset,
    final Object? basinCode = _unset,
    final Object? holderName = _unset,
    final Object? nationalId = _unset,
    final Object? borderEast = _unset,
    final Object? borderSouth = _unset,
    final Object? borderWest = _unset,
    final Object? borderNorth = _unset,
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
    final Object? completedAt = _unset,
    final Object? completedBy = _unset,
    final bool? isFieldAdded,
    final Object? createdBy = _unset,
    final Object? holderNameFarmerCard = _unset,
    final Object? ownerNameFarmerCard = _unset,
    final Object? growthStages = _unset,
  }) {
    T resolve<T>(final Object? value, final T fallback) =>
        identical(value, _unset) ? fallback : value as T;

    return Parcel(
      id: id ?? this.id,
      sourceAddedHoldingId:
          sourceAddedHoldingId ?? this.sourceAddedHoldingId,
      personId: personId ?? this.personId,
      holdingId: holdingId ?? this.holdingId,
      pageNumber: resolve(pageNumber, this.pageNumber),
      directorate: resolve(directorate, this.directorate),
      administration: resolve(administration, this.administration),
      basinName: resolve(basinName, this.basinName),
      basinCode: resolve(basinCode, this.basinCode),
      holderName: resolve(holderName, this.holderName),
      nationalId: resolve(nationalId, this.nationalId),
      borderEast: resolve(borderEast, this.borderEast),
      borderSouth: resolve(borderSouth, this.borderSouth),
      borderWest: resolve(borderWest, this.borderWest),
      borderNorth: resolve(borderNorth, this.borderNorth),
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
      completedAt: resolve(completedAt, this.completedAt),
      completedBy: resolve(completedBy, this.completedBy),
      isFieldAdded: isFieldAdded ?? this.isFieldAdded,
      createdBy: resolve(createdBy, this.createdBy),
      holderNameFarmerCard:
          resolve(holderNameFarmerCard, this.holderNameFarmerCard),
      ownerNameFarmerCard:
          resolve(ownerNameFarmerCard, this.ownerNameFarmerCard),
      growthStages: resolve(growthStages, this.growthStages),
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
        'associationName': associationName,
        'cropType': cropType,
        'notes': notes,
        'creditType': creditType,
        'reformType': reformType,
        'isInheritance': isInheritance,
        'isDelegate': isDelegate,
        'usageType': usageType,
        'holderNameFarmerCard': holderNameFarmerCard,
        'ownerNameFarmerCard': ownerNameFarmerCard,
        'growthStages': growthStages,
      };

  /// Rebuilds a parcel from [original] — which supplies the never-editable
  /// fields (id, pageNumber, borders) — overlaid with a saved [json]
  /// snapshot produced by [toEditableJson]. `holdingId` falls back to
  /// [original]'s value only for snapshots saved before it became editable.
  /// `associationName` became editable when it moved into the More Details
  /// section (`REFACTOR_ROADMAP.md` Phase 11 §4) — falls back to
  /// [original]'s value for snapshots saved before that (this doc comment
  /// previously, incorrectly, still listed it as never-editable, matching a
  /// real bug: the field was editable in the UI but silently never synced).
  factory Parcel.fromEditableJson(
    final Parcel original,
    final Map<String, dynamic> json,
  ) {
    double? d(final String key) => (json[key] as num?)?.toDouble();
    return Parcel(
      id: original.id,
      sourceAddedHoldingId: original.sourceAddedHoldingId,
      personId: original.personId,
      holdingId: json['holdingId'] as String? ?? original.holdingId,
      pageNumber: original.pageNumber,
      borderEast: original.borderEast,
      borderSouth: original.borderSouth,
      borderWest: original.borderWest,
      borderNorth: original.borderNorth,
      associationName:
          json['associationName'] as String? ?? original.associationName,
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
      holdingsCount: original.holdingsCount,
      pendingGroupId: original.pendingGroupId,
      reviewed: original.reviewed,
      reviewedAt: original.reviewedAt,
      reviewedBy: original.reviewedBy,
      completedAt: original.completedAt,
      completedBy: original.completedBy,
      isFieldAdded: original.isFieldAdded,
      createdBy: original.createdBy,
      holderNameFarmerCard: json['holderNameFarmerCard'] as String?,
      ownerNameFarmerCard: json['ownerNameFarmerCard'] as String?,
      growthStages: json['growthStages'] as String? ?? defaultGrowthStage,
    );
  }

  /// Full round-trip serialization (every field, including the
  /// never-editable ones) — used by the local city-snapshot cache, unlike
  /// [toEditableJson]/[fromEditableJson] which only cover the
  /// user-correctable subset for the local edit overlay.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sourceAddedHoldingId': sourceAddedHoldingId,
        'personId': personId,
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
        'completedAt': completedAt?.toIso8601String(),
        'completedBy': completedBy,
        'isFieldAdded': isFieldAdded,
        'createdBy': createdBy,
        'holderNameFarmerCard': holderNameFarmerCard,
        'ownerNameFarmerCard': ownerNameFarmerCard,
        'growthStages': growthStages,
      };

  factory Parcel.fromJson(final Map<String, dynamic> json) {
    double? d(final String key) => (json[key] as num?)?.toDouble();
    return Parcel(
      id: json['id'] as String? ?? '',
      sourceAddedHoldingId: json['sourceAddedHoldingId'] as String?,
      personId: json['personId'] as String?,
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
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      completedBy: json['completedBy'] as String?,
      isFieldAdded: json['isFieldAdded'] as bool? ?? false,
      createdBy: json['createdBy'] as String?,
      holderNameFarmerCard: json['holderNameFarmerCard'] as String?,
      ownerNameFarmerCard: json['ownerNameFarmerCard'] as String?,
      growthStages: json['growthStages'] as String? ?? defaultGrowthStage,
    );
  }
}
