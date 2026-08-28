import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../data/model/basin_progress.dart';
import 'basin_progress_bar.dart';

/// One row on the basin-first home screen — اسم الحوض, X/Y completion, and
/// a progress bar. 🟢/🟡/⚪ per APP_CLAUDE.md's mockup: green once every
/// holding is completed, amber once at least one is, a hollow dot when
/// none are yet.
class BasinCard extends StatelessWidget {
  const BasinCard({
    super.key,
    required this.basin,
    required this.onTap,
    this.animationIndex = 0,
  });

  final BasinProgress basin;
  final VoidCallback onTap;

  /// Position in the list — drives the fade/slide-in stagger delay.
  final int animationIndex;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final (Color dotColor, IconData dotIcon) = basin.isFullyCompleted
        ? (AppColors.green200, Icons.circle)
        : basin.isNotStarted
            ? (colors.textHint, Icons.circle_outlined)
            : (AppColors.amber300, Icons.circle);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(dotIcon, size: 10, color: dotColor),
                horizontalSpacing(8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        basin.basinName,
                        style: AppTextStyles.font16SemiBold.copyWith(
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (basin.basinCode != null)
                        Text(
                          'holdings.basin.code_label'.tr(
                            namedArgs: {'code': basin.basinCode!},
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
                Text(
                  '${basin.completedCount}/${basin.totalCount}',
                  style: AppTextStyles.font14Bold.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            verticalSpacing(10),
            BasinProgressBar(
              progress: basin.progress,
              isFullyCompleted: basin.isFullyCompleted,
            ),
          ],
        ),
      ),
    )
        .animate(delay: (animationIndex * 30).ms)
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }
}
