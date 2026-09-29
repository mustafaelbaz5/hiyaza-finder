import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../parcel_catalog/data/model/parcel_visibility_filter.dart';

class ParcelVisibilityFilterButton extends StatelessWidget {
  const ParcelVisibilityFilterButton({
    super.key,
    required this.value,
    required this.onSelected,
  });

  final ParcelVisibilityFilter value;
  final ValueChanged<ParcelVisibilityFilter> onSelected;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => _showSheet(context),
        icon: const Icon(Icons.filter_alt_outlined,
            size: 18, color: AppColors.primary200),
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
        await showParcelVisibilityFilterSheet(context, value: value);
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
}) =>
    showModalBottomSheet<ParcelVisibilityFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (final BuildContext sheetContext) =>
          _VisibilitySheet(value: value),
    );

class _VisibilitySheet extends StatelessWidget {
  const _VisibilitySheet({required this.value});
  final ParcelVisibilityFilter value;

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
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            verticalSpacing(18),
            Text('holdings.home.activity.filter_title'.tr(),
                style: AppTextStyles.font18Bold
                    .copyWith(color: colors.textPrimary),
                textAlign: TextAlign.right),
            verticalSpacing(8),
            for (final ParcelVisibilityFilter filter
                in ParcelVisibilityFilter.values)
              _FilterOption(filter: filter, isSelected: filter == value),
          ],
        ),
      ),
    );
  }
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
              ? AppColors.primary200.withValues(alpha: 0.12)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon,
                color:
                    isSelected ? AppColors.primary200 : colors.iconSecondary),
            horizontalSpacing(12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                  Text(title,
                      style: AppTextStyles.font14SemiBold
                          .copyWith(color: colors.textPrimary),
                      textAlign: TextAlign.right),
                  verticalSpacing(2),
                  Text(subtitle,
                      style: AppTextStyles.font12Regular
                          .copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.right),
                ])),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary200),
          ],
        ),
      ),
    );
  }
}
