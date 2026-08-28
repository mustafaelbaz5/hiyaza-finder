import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';

/// `ManageCitiesScreen`'s error state — tinted circle icon + shake +
/// retry, matching the visual language `EmptyBody`/`ErrorBody` established
/// for the home screen (Phase 4 consistency pass).
class ManageCitiesErrorState extends StatelessWidget {
  const ManageCitiesErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(rw(24)),
              decoration: BoxDecoration(
                color: AppColors.red200.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: rf(40),
                color: AppColors.red200,
              ),
            ).animate().shake(duration: 400.ms, hz: 4),
            verticalSpacing(20),
            Text(
              'errors.unknown'.tr(),
              style: AppTextStyles.font16SemiBold.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(20),
            CustomTextButton(
              text: 'errors.retry'.tr(),
              onPressed: onRetry,
              isFullWidth: false,
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }
}

/// `ManageCitiesScreen`'s "no downloaded cities" state.
class ManageCitiesEmptyState extends StatelessWidget {
  const ManageCitiesEmptyState({super.key});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(rw(24)),
              decoration: BoxDecoration(
                color: AppColors.primary50.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_city_outlined,
                size: rf(56),
                color: AppColors.primary200,
              ),
            ),
            verticalSpacing(20),
            Text(
              'cities.manage.empty'.tr(),
              style: AppTextStyles.font16SemiBold.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }
}
