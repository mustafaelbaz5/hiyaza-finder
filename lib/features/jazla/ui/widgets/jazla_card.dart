import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
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
    final String target = jazla.targetAreaSqm == null
        ? 'jazla.area.no_target'.tr()
        : '${jazla.targetAreaSqm!.toStringAsFixed(2)} م²';

    return Semantics(
      button: true,
      label: jazla.name,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary200.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    color: AppColors.primary200,
                  ),
                ),
                horizontalSpacing(12),
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
                      verticalSpacing(3),
                      Text(
                        jazla.basinName ?? '—',
                        style: AppTextStyles.font12Regular
                            .copyWith(color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                      verticalSpacing(10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            icon: Icons.grid_view_rounded,
                            text: 'jazla.parcel_count'.tr(
                              namedArgs: <String, String>{
                                'count': jazla.parcelCount.toString(),
                              },
                            ),
                          ),
                          _InfoChip(
                            icon: Icons.straighten_rounded,
                            text: target,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: colors.iconSecondary),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 180.ms, curve: Curves.easeOutCubic).slideY(
          begin: 0.025,
          end: 0,
          duration: 180.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.iconSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.font12Regular
                .copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
