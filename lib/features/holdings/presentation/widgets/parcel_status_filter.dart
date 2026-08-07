import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/parcel.dart';

/// The details screen's tab dimensions (`REFACTOR_ROADMAP.md` Phase 11
/// §11) — exactly three, replacing the previous six-option filter-chip row
/// (`all/original/added/modified/completed/pending`) with a fixed
/// `TabBar`: الكل is always the default/first tab.
enum DetailScreenTab { all, added, reviewed }

extension DetailScreenTabMatch on DetailScreenTab {
  bool matches(final Parcel parcel) {
    return switch (this) {
      DetailScreenTab.all => true,
      // Matches `ParcelDetailCard`'s own "is this an added parcel" check —
      // `isFieldAdded` alone misses a parcel whose provenance is only
      // carried via `sourceAddedHoldingId` (e.g. right after promotion, or
      // a currently-unsynced local add), which would otherwise show the
      // "مضافة" badge on the card but never appear under this tab.
      DetailScreenTab.added =>
        parcel.isFieldAdded || parcel.sourceAddedHoldingId != null,
      DetailScreenTab.reviewed => parcel.completedAt != null,
    };
  }

  String label() => switch (this) {
        DetailScreenTab.all => 'holdings.detail.filter_all'.tr(),
        DetailScreenTab.added => 'holdings.detail.filter_added'.tr(),
        DetailScreenTab.reviewed => 'holdings.detail.tab_reviewed'.tr(),
      };
}

/// Display order for the الكل tab: original (imported) parcels first, then
/// parcels added through the app, with reviewed parcels of either kind
/// sunk to the very end regardless of origin — a reviewed record is done,
/// so it shouldn't compete with what still needs attention for the top of
/// the list.
int compareParcelsForDisplay(final Parcel a, final Parcel b) {
  final bool aReviewed = a.completedAt != null;
  final bool bReviewed = b.completedAt != null;
  if (aReviewed != bReviewed) return aReviewed ? 1 : -1;

  final bool aAdded = a.isFieldAdded || a.sourceAddedHoldingId != null;
  final bool bAdded = b.isFieldAdded || b.sourceAddedHoldingId != null;
  if (aAdded != bAdded) return aAdded ? 1 : -1;

  return 0;
}
