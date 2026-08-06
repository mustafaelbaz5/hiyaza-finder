import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../domain/entities/parcel.dart';

/// The detail-screen filter dimensions (`REFACTOR_ROADMAP.md` Phase 9 #12,
/// previously blocked on the live `completed_at` column). A holding's
/// parcel list is typically small (1–3 rows), so this is a filter row over
/// the same on-screen list, not separate navigable tab pages/screens —
/// matches the app's "lightweight, not a Dashboard replacement" philosophy
/// used for the home summary cards (`StatusSummaryCards`).
enum ParcelStatusFilter { all, original, added, modified, completed, pending }

extension ParcelStatusFilterMatch on ParcelStatusFilter {
  /// Whether [parcel] belongs to this filter. [isModified] is supplied by
  /// the caller (from `HoldingsRepository.isParcelEdited`) since that check
  /// needs the repository, which this pure entity-matching function
  /// shouldn't depend on directly.
  bool matches(final Parcel parcel, {required final bool isModified}) {
    return switch (this) {
      ParcelStatusFilter.all => true,
      ParcelStatusFilter.original => !parcel.isFieldAdded,
      ParcelStatusFilter.added => parcel.isFieldAdded,
      ParcelStatusFilter.modified => isModified,
      ParcelStatusFilter.completed => parcel.completedAt != null,
      ParcelStatusFilter.pending => parcel.completedAt == null,
    };
  }

  String label() => switch (this) {
        ParcelStatusFilter.all => 'holdings.detail.filter_all'.tr(),
        ParcelStatusFilter.original => 'holdings.detail.filter_original'.tr(),
        ParcelStatusFilter.added => 'holdings.detail.filter_added'.tr(),
        ParcelStatusFilter.modified => 'holdings.detail.filter_modified'.tr(),
        ParcelStatusFilter.completed => 'holdings.detail.filter_completed'.tr(),
        ParcelStatusFilter.pending => 'holdings.detail.filter_pending'.tr(),
      };
}

/// Horizontal scrollable chip row for [ParcelStatusFilter] — [counts] shows
/// how many of the current holding's parcels fall in each filter, `0`-count
/// filters are still shown (so the user can see nothing matches a filter
/// rather than it silently disappearing) except when the whole holding has
/// only 1 parcel, where filtering is pointless clutter — the caller decides
/// whether to show this row at all in that case.
class ParcelStatusFilterRow extends StatelessWidget {
  const ParcelStatusFilterRow({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final ParcelStatusFilter selected;
  final Map<ParcelStatusFilter, int> counts;
  final ValueChanged<ParcelStatusFilter> onSelected;

  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      height: rh(36),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ParcelStatusFilter.values.length,
        separatorBuilder: (final _, final __) => horizontalSpacing(8),
        itemBuilder: (final BuildContext context, final int i) {
          final ParcelStatusFilter filter = ParcelStatusFilter.values[i];
          final bool isSelected = filter == selected;
          final int count = counts[filter] ?? 0;
          return _FilterChip(
            label: filter.label(),
            count: count,
            isSelected: isSelected,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: rw(12), vertical: rh(6)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary200
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary200 : colors.border,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: AppTextStyles.font12Medium.copyWith(
            color: isSelected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
