import '../../../cities/data/model/association_type.dart';
import '../model/parcel.dart';
import '../model/usage_type.dart';

/// Builds the "copy all" clipboard text for a parcel, and the shared
/// اسم المالك default-value rule the detail card also displays inline.
/// Extracted from `ParcelDetailCard` — this is real business logic (the
/// ورثة/مفوض prefix interaction has four distinct states) and deserves
/// unit tests, which it couldn't have while it lived inside a widget.
class ClipboardFormatter {
  const ClipboardFormatter();

  static const String emptyPlaceholder = '-';

  /// The display fallback for a missing الرقم القومي — never stored, only
  /// shown/copied (UI/UX Updates prompt "Change 7").
  static const String missingNationalIdDisplay = '11111111111111';

  /// اسم المالك defaults to اسم الحائز when not explicitly set — most
  /// owners and holders are the same person, so this avoids re-typing the
  /// name while still letting it be overridden per parcel.
  String? effectiveOwnerName(final Parcel p) {
    final String? owner = p.ownerName?.trim();
    if (owner != null && owner.isNotEmpty) return owner;
    final String? holder = p.holderName?.trim();
    return (holder != null && holder.isNotEmpty) ? holder : null;
  }

  /// اسم الحائز never gets a prefix (UI/UX Updates prompt "Change 1"/
  /// "Change 2") — مفوض is represented purely by the automatic
  /// Inheritance without delegation prefixes both displayed names. When
  /// delegation is active, only the owner receives the inheritance prefix.
  /// Kept as a method so the rule has one place to land.
  String? holderNamePrefix(final Parcel p) =>
      p.isInheritance && !p.isDelegate ? 'ورثة ' : null;

  /// ورثة prefix for the displayed owner. Delegation does not affect it.
  String? ownerNamePrefix(final Parcel p) => p.isInheritance ? 'ورثة ' : null;

  /// اسم الحائز as shown in the UI/copy-all/export. The stored value is never
  /// changed; only the display/output text is transformed.
  String displayHolderName(final Parcel p) {
    final String name = p.holderName?.trim() ?? '';
    if (name.isEmpty) return name;
    final String? prefix = holderNamePrefix(p);
    return prefix == null ? name : '$prefix$name';
  }

  /// اسم المالك as shown anywhere in the UI/copy-all/export — prefixed with
  /// [ownerNamePrefix] ("ورثة ") when ورثة is set, applied to
  /// [effectiveOwnerName] (which already falls back to اسم الحائز when اسم
  /// المالك isn't set).
  String displayOwnerName(final Parcel p) {
    final String name = effectiveOwnerName(p) ?? '';
    if (name.isEmpty) return name;
    final String? prefix = ownerNamePrefix(p);
    return prefix == null ? name : '$prefix$name';
  }

  /// الرقم القومي as shown/copied — falls back to
  /// [missingNationalIdDisplay] when unset, never stored (UI/UX Updates
  /// prompt "Change 7").
  String displayNationalId(final Parcel p) {
    final String trimmed = p.nationalId?.trim() ?? '';
    return trimmed.isEmpty ? missingNationalIdDisplay : trimmed;
  }

  /// رقم الأرض as shown/copied — falls back to "0" when unset or the
  /// parcel was field-added, never stored (UI/UX Updates prompt "Change 8").
  String displayLandNumber(final Parcel p) {
    final String trimmed = p.landNumber?.trim() ?? '';
    if (trimmed.isEmpty || p.isFieldAdded) return '0';
    return trimmed;
  }

  /// Formats one compact, labeled field per copied message. The pipe is the
  /// primary separator because Google Earth/KML descriptions may flatten line
  /// breaks. Related values share an Arabic comma, while semicolons are
  /// deliberately avoided.
  /// [hideCreditType]/[associationType] are accepted for call-site
  /// compatibility but no longer affect the output — نوع الائتمان/نوع
  /// الإصلاح were never a Copy All field (`CreditTypeNotesSync` surfaces
  /// them through ملاحظات instead).
  String format(
    final Parcel p, {
    final bool hideCreditType = false,
    final AssociationType? associationType,
  }) {
    String slot(final String? v) =>
        (v == null || v.trim().isEmpty) ? emptyPlaceholder : v.trim();

    final String holderSlot =
        displayHolderName(p).isEmpty ? emptyPlaceholder : displayHolderName(p);
    final String ownerSlot =
        displayOwnerName(p).isEmpty ? emptyPlaceholder : displayOwnerName(p);
    final int parcelCount = (p.holdingsCount ?? 0) < 1 ? 1 : p.holdingsCount!;
    final bool isAgricultural =
        UsageType.fromLabel(p.usageType) == UsageType.agricultural;
    final String notesJoined = p.notes
        .map((final String note) =>
            note.replaceAll(RegExp(r'\s*\r?\n\s*'), '، '))
        .join('، ')
        .trim();

    String field(final String label, final String value) => '$label: $value';

    final List<String> lines = <String>[
      field('id', p.id),
      '${field('رقم الحيازة', p.holdingId)}، ${field('عدد القطع', parcelCount.toString())}',
      field('اسم الجمعية', slot(p.associationName)),
      field('اسم الحائز', holderSlot),
      field('اسم المالك', ownerSlot),
      field('الرقم القومي', displayNationalId(p)),
      '${field('اسم الحوض', slot(p.basinName))}، ${field('كود الحوض', slot(p.basinCode))}',
      field('رقم الأرض', displayLandNumber(p)),
      'المساحة: ${formatNumber(p.feddan) ?? 0} فدان، '
          '${formatNumber(p.qirat) ?? 0} قيراط، '
          '${formatNumber(p.sahm) ?? 0} سهم',
      field('نوع الاستخدام', slot(p.usageType)),
      if (isAgricultural) field('نوع المحصول', slot(p.cropType)),
      if (isAgricultural) field('مرحلة النمو', slot(p.growthStages)),
      if (notesJoined.isNotEmpty && notesJoined != emptyPlaceholder)
        field('الملاحظات', notesJoined),
    ];

    return lines.join(' | ');
  }

  /// `null`/empty values are formatted with [emptyPlaceholder] so the
  /// on-screen display and the copy-all text stay consistent.
  String? formatNumber(final double? value) {
    if (value == null) return null;
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  String areaFraction(final Parcel p) {
    final String feddan = formatNumber(p.feddan) ?? '0';
    final String qirat = formatNumber(p.qirat) ?? '0';
    final String sahm = formatNumber(p.sahm) ?? '0';
    return '$feddan فدان، $qirat قيراط، $sahm سهم';
  }
}
