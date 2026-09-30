import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../parcel_catalog/data/model/parcel_activity_summary.dart';
import '../../../parcel_catalog/data/model/parcel_visibility_filter.dart';

/// Compatibility trigger for places that still need a labeled visibility
/// filter. Home uses the icon-only trigger in its city header.
class ParcelVisibilityFilterButton extends StatelessWidget {
  const ParcelVisibilityFilterButton({
    super.key,
    required this.value,
    required this.onSelected,
    this.summary = const ParcelActivitySummary(),
  });

  final ParcelVisibilityFilter value;
  final ValueChanged<ParcelVisibilityFilter> onSelected;
  final ParcelActivitySummary summary;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => _showSheet(context),
        icon: const Icon(
          Icons.tune_rounded,
          size: 18,
          color: AppColors.primary200,
        ),
        label: Text(
          _label(value),
          style: AppTextStyles.font12Bold.copyWith(color: colors.textPrimary),
        ),
        style: TextButton.styleFrom(
          backgroundColor: colors.surfaceVariant,
          foregroundColor: colors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.border),
          ),
        ),
      ),
    );
  }

  Future<void> _showSheet(final BuildContext context) async {
    final ParcelVisibilityFilter? selected =
        await showParcelVisibilityFilterSheet(
      context,
      value: value,
      summary: summary,
    );
    if (selected != null) onSelected(selected);
  }

  static String _label(final ParcelVisibilityFilter filter) => switch (filter) {
        ParcelVisibilityFilter.activeOnly =>
          'holdings.home.activity.filter_active'.tr(),
        ParcelVisibilityFilter.all => 'holdings.home.activity.filter_all'.tr(),
        ParcelVisibilityFilter.zeroAreaOnly =>
          'holdings.home.activity.filter_zero'.tr(),
      };
}

Future<ParcelVisibilityFilter?> showParcelVisibilityFilterSheet(
  final BuildContext context, {
  required final ParcelVisibilityFilter value,
  final ParcelActivitySummary summary = const ParcelActivitySummary(),
}) =>
    showModalBottomSheet<ParcelVisibilityFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (final BuildContext sheetContext) =>
          _VisibilitySheet(value: value, summary: summary),
    );

class _VisibilitySheet extends StatelessWidget {
  const _VisibilitySheet({required this.value, required this.summary});

  final ParcelVisibilityFilter value;
  final ParcelActivitySummary summary;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            verticalSpacing(18),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'holdings.home.activity.filter_title'.tr(),
                    style: AppTextStyles.font18Bold
                        .copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.right,
                  ),
                ),
                const Icon(Icons.tune_rounded, color: AppColors.primary200),
              ],
            ),
            verticalSpacing(14),
            _ActivitySummaryStrip(summary: summary),
            verticalSpacing(18),
            for (final ParcelVisibilityFilter filter
                in ParcelVisibilityFilter.values)
              _FilterOption(filter: filter, isSelected: filter == value),
          ],
        ),
      ),
    );
  }
}

class _ActivitySummaryStrip extends StatelessWidget {
  const _ActivitySummaryStrip({required this.summary});

  final ParcelActivitySummary summary;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          _SummaryValue(
            value: summary.activeParcelCount,
            label: 'holdings.home.activity.active_parcels'.tr(),
            icon: Icons.agriculture_rounded,
            color: AppColors.primary200,
          ),
          _SummaryDivider(color: colors.border),
          _SummaryValue(
            value: summary.totalParcelCount,
            label: 'holdings.home.activity.total_records'.tr(),
            icon: Icons.view_list_rounded,
            color: colors.iconSecondary,
          ),
          _SummaryDivider(color: colors.border),
          _SummaryValue(
            value: summary.zeroAreaParcelCount,
            label: 'holdings.home.activity.zero_area_short'.tr(),
            icon: Icons.inventory_2_outlined,
            color: colors.textHint,
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider({required this.color});

  final Color color;

  @override
  Widget build(final BuildContext context) => SizedBox(
        height: 36,
        child: VerticalDivider(color: color, width: 1, thickness: 1),
      );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(final BuildContext context) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 18),
            verticalSpacing(4),
            Text(
              '$value',
              style: AppTextStyles.font16SemiBold.copyWith(color: color),
            ),
            Text(
              label,
              style: AppTextStyles.font12Regular.copyWith(color: color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({required this.filter, required this.isSelected});

  final ParcelVisibilityFilter filter;
  final bool isSelected;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final (String title, String subtitle, IconData icon) = switch (filter) {
      ParcelVisibilityFilter.activeOnly => (
          'holdings.home.activity.filter_active'.tr(),
          'holdings.home.activity.filter_active_hint'.tr(),
          Icons.agriculture_rounded,
        ),
      ParcelVisibilityFilter.all => (
          'holdings.home.activity.filter_all'.tr(),
          'holdings.home.activity.filter_all_hint'.tr(),
          Icons.view_list_rounded,
        ),
      ParcelVisibilityFilter.zeroAreaOnly => (
          'holdings.home.activity.filter_zero'.tr(),
          'holdings.home.activity.filter_zero_hint'.tr(),
          Icons.inventory_2_outlined,
        ),
    };
    return InkWell(
      onTap: () => Navigator.of(context).pop(filter),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary200.withValues(alpha: .12)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: isSelected ? AppColors.primary200 : colors.iconSecondary,
            ),
            horizontalSpacing(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTextStyles.font14SemiBold
                        .copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.right,
                  ),
                  verticalSpacing(2),
                  Text(
                    subtitle,
                    style: AppTextStyles.font12Regular
                        .copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary200,
              ),
          ],
        ),
      ),
    );
  }
}
