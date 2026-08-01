import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../logic/services/holding_search_service.dart';

class RecommendationTile extends StatelessWidget {
  const RecommendationTile({
    super.key,
    required this.result,
    required this.onTap,
    this.animationDelay = Duration.zero,
  });

  final SearchResult result;
  final VoidCallback onTap;
  final Duration animationDelay;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String holderName = result.holderName ?? '—';
    final String suffix = result.parcelCount > 1 ? ' (${result.parcelCount} قطع)' : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$holderName$suffix',
                    style: AppTextStyles.font16SemiBold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${result.holdingId}',
                    style: AppTextStyles.font14Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppColors.primary200,
            ),
          ],
        ),
      ),
    )
        .animate(delay: animationDelay)
        .fadeIn(duration: 220.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}
