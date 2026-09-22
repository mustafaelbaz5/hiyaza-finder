import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';

class CityToolTile extends StatelessWidget {
  const CityToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.embedded = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool embedded;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final Widget content = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        rw(embedded ? 4 : 16),
        rh(embedded ? 10 : 14),
        rw(embedded ? 4 : 12),
        rh(embedded ? 10 : 14),
      ),
      child: Row(
        textDirection: Directionality.of(context),
        children: <Widget>[
          Container(
            width: rw(42),
            height: rw(42),
            decoration: BoxDecoration(
              color: AppColors.primary50.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary200, size: 21),
          ),
          horizontalSpacing(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.font16SemiBold.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
                verticalSpacing(3),
                Text(
                  subtitle,
                  style: AppTextStyles.font12Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          horizontalSpacing(8),
          Icon(
            Icons.chevron_left_rounded,
            size: 21,
            color: colors.textHint,
          ),
        ],
      ),
    );

    return Material(
      color: embedded ? Colors.transparent : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(embedded ? 10 : 16),
        child: embedded
            ? content
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: content,
              ),
      ),
    );
  }
}
