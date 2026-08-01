import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';

class InlineAction extends StatelessWidget {
  const InlineAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.primary50.withValues(alpha: 0.3) : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? AppColors.primary200 : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.primary200),
            horizontalSpacing(6),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.font12Bold.copyWith(
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
