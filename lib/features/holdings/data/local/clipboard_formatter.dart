import '../model/parcel.dart';
import '../model/usage_type.dart';

import '../../../cities/data/model/association_type.dart';


/// Builds the "copy all" clipboard text for a parcel, and the shared
/// اسم المالك default-value rule the detail card also displays inline.
/// Extracted from `ParcelDetailCard` — this is real business logic (the
/// وراثة/مفوض prefix interaction has four distinct states) and deserves
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
  /// "مفوض عنه {holder}" ملاحظات entry, and وراثة only ever prefixes اسم
  /// المالك, never اسم الحائز. Kept as a method (not inlined at call sites)
  /// so a future rule change has one place to land.
  String? holderNamePrefix(final Parcel p) => null;

  /// وراثة prefix for اسم المالك display — "وارثه " (no brackets, trailing
  /// space; UI/UX Updates prompt "Change 2"). مفوض never affects اسم المالك.
  String? ownerNamePrefix(final Parcel p) => p.isInheritance ? 'وارثه ' : null;

  /// اسم الحائز as shown anywhere in the UI/copy-all/export — never
  /// prefixed (see [holderNamePrefix]). The stored [Parcel.holderName]
  /// value itself is never touched by this; only the display/output text is.
  String displayHolderName(final Parcel p) => p.holderName?.trim() ?? '';

  /// اسم المالك as shown anywhere in the UI/copy-all/export — prefixed with
  /// [ownerNamePrefix] ("وارثه ") when وراثة is set, applied to
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

  /// One "label: value" field per line, no trailing commas and no comma
  /// separators between fields (Copy All Format Fix prompt) — nothing here
  /// pastes into a spreadsheet template anymore, so the old
  /// comma-per-field/shared-line grouping no longer serves a purpose.
  /// Order and inclusion rules per the UI/UX Updates prompt "Change 10":
  /// ID, then رقم الأرض, then رقم الحيازة; اسم الجمعية/المساحة بالمتر are
  /// dropped entirely; نوع المحصول/مرحلة النمو only appear for زراعة;
  /// الملاحظات is omitted (not shown as a placeholder) when there's nothing
  /// to say. [hideCreditType]/[associationType] are accepted for call-site
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
    final String notesJoined = p.notes.join('، ').trim();

    String field(final String label, final String value) => '$label: $value';

    final List<String> lines = <String>[
      field('ID', p.id),
      field('رقم الأرض', displayLandNumber(p)),
      field('رقم الحيازة', p.holdingId),
      field('اسم المالك', ownerSlot),
      field('اسم الحائز', holderSlot),
      field('الرقم القومي', displayNationalId(p)),
      field('عدد القطع', parcelCount.toString()),
      field('اسم الحوض', slot(p.basinName)),
      field('كود الحوض', slot(p.basinCode)),
      'المساحة:',
      '  ${field('فدان', formatNumber(p.feddan) ?? emptyPlaceholder)}',
      '  ${field('قيراط', formatNumber(p.qirat) ?? emptyPlaceholder)}',
      '  ${field('سهم', formatNumber(p.sahm) ?? emptyPlaceholder)}',
      if (isAgricultural) field('نوع المحصول', slot(p.cropType)),
      if (isAgricultural) field('مرحلة النمو', slot(p.growthStages)),
      field('نوع الاستخدام', slot(p.usageType)),
      if (notesJoined.isNotEmpty && notesJoined != emptyPlaceholder)
        field('الملاحظات', notesJoined),
    ];

    return lines.join('\n');
  }

  /// `null`/empty values are formatted with [emptyPlaceholder] so the
  /// on-screen display and the copy-all text stay consistent.
  String? formatNumber(final double? value) {
    if (value == null) return null;
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  String areaFraction(final Parcel p) {
    final String feddan = formatNumber(p.feddan) ?? emptyPlaceholder;
    final String qirat = formatNumber(p.qirat) ?? emptyPlaceholder;
    final String sahm = formatNumber(p.sahm) ?? emptyPlaceholder;
    return '$feddan فدان، $qirat قيراط، $sahm سهم';
  }
}
