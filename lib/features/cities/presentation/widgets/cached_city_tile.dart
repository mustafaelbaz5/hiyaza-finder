import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../domain/entities/cached_city_meta.dart';

String _formatSize(final int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// One row on `ManageCitiesScreen` — a locally cached city, its size/parcel
/// count, an "active" badge if it's the currently loaded one, and a delete
/// action (with its own in-flight spinner state).
class CachedCityTile extends StatelessWidget {
  const CachedCityTile({
    super.key,
    required this.city,
    required this.isActive,
    required this.isDeleting,
    required this.onDelete,
    required this.animationIndex,
  });

  final CachedCityMeta city;
  final bool isActive;
  final bool isDeleting;
  final VoidCallback onDelete;

  /// Position in the list — drives the fade/slide-in stagger delay.
  final int animationIndex;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.primary200 : colors.border,
          width: isActive ? 1.5 : 1,
        ),
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
                Row(
                  children: [
                    if (isActive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary200.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'cities.manage.current_badge'.tr(),
                          style: AppTextStyles.font12Bold.copyWith(
                            color: AppColors.primary200,
                          ),
                        ),
                      ),
                      horizontalSpacing(6),
                    ],
                    Expanded(
                      child: Text(
                        city.cityName,
                        style: AppTextStyles.font16SemiBold.copyWith(
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'cities.manage.summary'.tr(
                    namedArgs: {
                      'count': city.parcelsCount.toString(),
                      'size': _formatSize(city.fileSizeBytes),
                    },
                  ),
                  style: AppTextStyles.font12Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          horizontalSpacing(8),
          if (isDeleting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.red200,
              ),
            )
          else
            IconButton(
              tooltip: 'cities.manage.delete'.tr(),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.red200,
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    )
        .animate(key: ValueKey<String>('${city.cityId}-anim'))
        .fadeIn(duration: 200.ms, delay: (animationIndex * 20).ms)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: 200.ms,
          delay: (animationIndex * 20).ms,
          curve: Curves.easeOutCubic,
        );
  }
}
