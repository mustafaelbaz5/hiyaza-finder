import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../data/model/jazla.dart';

class JazlaCard extends StatelessWidget {
  const JazlaCard({
    super.key,
    required this.jazla,
    required this.onTap,
    required this.onLongPress,
  });

  final Jazla jazla;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary50.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.layers_outlined,
                  color: AppColors.primary200),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jazla.name,
                    style: AppTextStyles.font16SemiBold
                        .copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'jazla.parcel_count'.tr(
                      namedArgs: {'count': jazla.parcelCount.toString()},
                    ),
                    style: AppTextStyles.font12Regular
                        .copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.right,
                  ),
                  if (jazla.basinName?.trim().isNotEmpty == true)
                    Text(
                      jazla.basinName!,
                      style: AppTextStyles.font12Regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (jazla.targetAreaSqm != null)
                    Text(
                      '${'jazla.area.target'.tr()}: ${jazla.targetAreaSqm!.toStringAsFixed(2)} م²',
                      style: AppTextStyles.font12Regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
