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

  /// اسم المالك defaults to اسم الحائز when not explicitly set — most
  /// owners and holders are the same person, so this saves re-typing the
  /// name while still letting it be overridden per parcel.
  String? effectiveOwnerName(final Parcel p) {
    final String? owner = p.ownerName?.trim();
    if (owner != null && owner.isNotEmpty) return owner;
    final String? holder = p.holderName?.trim();
    return (holder != null && holder.isNotEmpty) ? holder : null;
  }

  /// وراثة/مفوض prefix for the الحائز display — same rule [format] uses for
  /// its clipboard text (`REFACTOR_ROADMAP.md` Phase 10 §6): مفوض overrides
  /// وراثة for الحائز specifically, otherwise وراثة alone if set, otherwise
  /// no prefix. Kept here (not duplicated in the widget) so the on-screen
  /// display and the copy-all text can never drift apart.
  String? holderNamePrefix(final Parcel p) =>
      p.isDelegate ? '(مفوض عنه)' : (p.isInheritance ? '(ورثة)' : null);

  /// وراثة prefix for the المالك display — مفوض never affects المالك, only
  /// وراثة does. Same rule [format] uses.
  String? ownerNamePrefix(final Parcel p) =>
      p.isInheritance ? '(ورثة)' : null;

  /// اسم الحائز as shown anywhere in the UI/copy-all/export — prefixed with
  /// [holderNamePrefix] (مفوض overrides وراثة for الحائز specifically). The
  /// stored [Parcel.holderName] value itself is never touched by this; only
  /// the display/output text is.
  String displayHolderName(final Parcel p) {
    final String name = p.holderName?.trim() ?? '';
    if (name.isEmpty) return name;
    final String? prefix = holderNamePrefix(p);
    return prefix == null ? name : '$prefix $name';
  }

  /// اسم المالك as shown anywhere in the UI/copy-all/export — same
  /// [ownerNamePrefix] rule [format] uses, applied to [effectiveOwnerName]
  /// (which already falls back to اسم الحائز when اسم المالك isn't set).
  String displayOwnerName(final Parcel p) {
    final String name = effectiveOwnerName(p) ?? '';
    if (name.isEmpty) return name;
    final String? prefix = ownerNamePrefix(p);
    return prefix == null ? name : '$prefix $name';
  }

  /// One "label: value" field per line, no trailing commas and no comma
  /// separators between fields (Copy All Format Fix prompt) — nothing here
  /// pastes into a spreadsheet template anymore, so the old
  /// comma-per-field/shared-line grouping no longer serves a purpose. ID is
  /// always first; اسم الجمعية/رقم الأرض/المساحة بالمتر are dropped
  /// entirely; نوع المحصول/مرحلة النمو only appear for زراعة; ملاحظات is
  /// omitted (not shown as a placeholder) when there's nothing to say.
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
    final String notesJoined = p.notes.join('، ').trim();

    String field(final String label, final String value) => '$label: $value';

    final List<String> lines = <String>[
      field('ID', p.id),
      field('رقم الحيازة', p.holdingId),
      field('اسم المالك', ownerSlot),
      field('اسم الحائز', holderSlot),
      field('الرقم القومي', slot(p.nationalId)),
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
