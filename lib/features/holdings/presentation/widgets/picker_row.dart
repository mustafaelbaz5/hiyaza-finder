import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';

class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary200,
            ),
            horizontalSpacing(6),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.font14SemiBold.copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            horizontalSpacing(8),
            Text(
              label,
              style: AppTextStyles.font12Regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
