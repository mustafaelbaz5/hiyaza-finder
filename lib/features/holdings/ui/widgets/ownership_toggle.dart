import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// نوع الملكية — ملك/أوقاف segmented toggle, shown only for credit-type
/// cities (Credit/Reform Type Logic prompt). Reform cities never show this;
/// their equivalent lives entirely in the quick-select notes instead.
class OwnershipToggle extends StatelessWidget {
  const OwnershipToggle({
    super.key,
    required this.isAwqaf,
    required this.onChanged,
  });

  final bool isAwqaf;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'holdings.fields.ownership_type'.tr(),
          style: AppTextStyles.font12Regular.copyWith(
            color: colors.textSecondary,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _Segment(
                  label: 'holdings.fields.ownership_milk'.tr(),
                  isSelected: !isAwqaf,
                  onTap: () => onChanged(false),
                ),
              ),
              Expanded(
                child: _Segment(
                  label: 'holdings.fields.ownership_awqaf'.tr(),
                  isSelected: isAwqaf,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary200 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.font14Bold.copyWith(
            color: isSelected ? AppColors.white : colors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
