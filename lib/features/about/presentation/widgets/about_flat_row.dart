import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// _AboutFlatRow — reusable row for the about screen
/// Used for both static info and tappable links

class AboutFlatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final bool showDivider;

  const AboutFlatRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.trailingWidget,
    this.onTap,
    this.showDivider = true,
  });

  bool get _isTappable => onTap != null;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Column(
      children: [
        InkWell(
          onTap: _isTappable
              ? () {
                  HapticFeedback.lightImpact();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      _isTappable ? AppColors.primary200 : colors.iconSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.font14Regular.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: AppTextStyles.font14Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                if (trailingWidget != null) trailingWidget!,
                if (_isTappable) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: colors.textHint,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.divider,
          ),
      ],
    );
  }
}
