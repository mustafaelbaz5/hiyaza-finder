import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                horizontalSpacing(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              basin.basinName,
                              style: AppTextStyles.font18Bold.copyWith(
                                color: colors.textPrimary,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _CopyButton(
                            tooltip: 'holdings.basin.copy_name'.tr(),
                            onTap: () => _copy(context, basin.basinName),
                          ),
                        ],
                      ),
                      if (basin.basinCode != null) ...[
                        verticalSpacing(2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'holdings.basin.code_label'.tr(
                                  namedArgs: {'code': basin.basinCode!},
                                ),
                                style: AppTextStyles.font12Regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            _CopyButton(
                              tooltip: 'holdings.basin.copy_code'.tr(),
                              onTap: () => _copy(context, basin.basinCode!),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                horizontalSpacing(10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${basin.completedCount}/${basin.totalCount}',
                      style: AppTextStyles.font16Bold.copyWith(
                        color: dotColor,
                      ),
                    ),
                    Text(
                      'holdings.basin.total_parcels'.tr(),
                      style: AppTextStyles.font12Regular.copyWith(
                        color: colors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            verticalSpacing(14),
            BasinProgressBar(
              progress: basin.progress,
              isFullyCompleted: basin.isFullyCompleted,
            ),
            verticalSpacing(12),
            Divider(height: 1, color: colors.border),
            verticalSpacing(8),
            Row(
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 12, color: AppColors.primary200),
                horizontalSpacing(6),
                Expanded(
                  child: Text(
                    'holdings.basin.open_parcels'.tr(),
                    style: AppTextStyles.font12Bold.copyWith(
                      color: AppColors.primary200,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: (animationIndex * 30).ms)
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }

  Future<void> _copy(final BuildContext context, final String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      HapticFeedback.lightImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.copy_rounded,
            size: 20, color: AppColors.primary200),
      );
}
