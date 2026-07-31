import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/spacing.dart';

/// Non-blocking notice shown when the server has newer data for the
/// active city than what's cached locally — never auto-downloads (the
/// user might be on mobile data), just offers the action.
class CityStaleBanner extends StatelessWidget {
  const CityStaleBanner({super.key, required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: rw(12), vertical: rh(10)),
      decoration: BoxDecoration(
        color: AppColors.amber200.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber200.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_sync_rounded,
            size: 18,
            color: AppColors.amber300,
          ),
          horizontalSpacing(8),
          Expanded(
            child: Text(
              'cities.stale_banner.message'.tr(),
              style: AppTextStyles.font12Medium.copyWith(
                color: AppColors.amber300,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          horizontalSpacing(8),
          GestureDetector(
            onTap: onRefresh,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'cities.stale_banner.refresh'.tr(),
              style: AppTextStyles.font12Bold.copyWith(
                color: AppColors.amber300,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
