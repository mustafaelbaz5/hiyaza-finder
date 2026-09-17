import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';

/// Shared empty-state layout for the cities feature's list screens
/// (`CityPickerScreen`'s no-cities/no-search-results states,
/// `ManageCitiesScreen`'s no-downloaded-cities state).
class CityListEmptyState extends StatelessWidget {
  const CityListEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.textHint),
            verticalSpacing(12),
            Text(
              title,
              style:
                  AppTextStyles.font16Regular.copyWith(color: colors.textHint),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              verticalSpacing(4),
              Text(
                subtitle!,
                style: AppTextStyles.font12Regular
                    .copyWith(color: colors.textHint),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

/// Shared error-state layout (message + retry button) for the cities
/// feature's list screens.
class CityListErrorState extends StatelessWidget {
  const CityListErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.red200),
            verticalSpacing(12),
            Text(
              message,
              style: AppTextStyles.font16Regular
                  .copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(16),
            TextButton(
              onPressed: onRetry,
              child: Text('errors.retry'.tr()),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
