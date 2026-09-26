import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../data/model/basin_holding_filter.dart';

/// Completion-filter controls for the holdings in one basin.
class BasinHoldingsFilter extends StatelessWidget {
  const BasinHoldingsFilter({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final BasinHoldingFilter selected;
  final ValueChanged<BasinHoldingFilter> onSelected;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(16)),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _FilterButton(
                label: 'holdings.basin_screen.filter_all'.tr(),
                isSelected: selected == BasinHoldingFilter.all,
                onTap: () => onSelected(BasinHoldingFilter.all),
              ),
            ),
            horizontalSpacing(8),
            Expanded(
              child: _FilterButton(
                label: 'holdings.basin_screen.filter_pending'.tr(),
                isSelected: selected == BasinHoldingFilter.pending,
                onTap: () => onSelected(BasinHoldingFilter.pending),
              ),
            ),
            horizontalSpacing(8),
            Expanded(
              child: _FilterButton(
                label: 'holdings.basin_screen.filter_completed'.tr(),
                isSelected: selected == BasinHoldingFilter.completed,
                onTap: () => onSelected(BasinHoldingFilter.completed),
              ),
            ),
          ],
        ),
      );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary200 : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.font12Bold.copyWith(
            color: isSelected ? AppColors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
