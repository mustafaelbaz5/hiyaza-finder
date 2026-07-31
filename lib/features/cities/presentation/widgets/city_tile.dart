import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../domain/entities/city.dart';

class CityTile extends StatelessWidget {
  const CityTile({
    super.key,
    required this.city,
    required this.onTap,
    this.isDownloading = false,
  });

  final City city;
  final VoidCallback onTap;
  final bool isDownloading;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: isDownloading ? null : onTap,
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_city_rounded,
                color: AppColors.primary200,
              ),
            ),
            horizontalSpacing(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.name,
                    style: AppTextStyles.font16SemiBold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (city.directorate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      city.directorate!,
                      style: AppTextStyles.font12Regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
            if (isDownloading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary200,
                ),
              )
            else
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: AppColors.primary200,
              ),
          ],
        ),
      ),
    );
  }
}
