import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/core/widgets/custom_text_button.dart';

class EmptyBody extends StatelessWidget {
  const EmptyBody({super.key, required this.onPickFile});

  final VoidCallback onPickFile;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(rw(28)),
              decoration: BoxDecoration(
                color: AppColors.primary50.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_city_rounded,
                size: rf(64),
                color: AppColors.primary200,
              ),
            ).animate().fadeIn(duration: 350.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: 400.ms,
                ),
            verticalSpacing(24),
            Text(
              'holdings.empty.title'.tr(),
              style: AppTextStyles.font20Bold.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(8),
            Text(
              'holdings.empty.desc'.tr(),
              style: AppTextStyles.font16Regular.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(32),
            CustomTextButton(
              text: 'holdings.empty.pick_file'.tr(),
              onPressed: onPickFile,
              prefixIcon: const Icon(
                Icons.location_city_rounded,
                color: AppColors.white,
              ),
              isFullWidth: false,
              size: CustomButtonSize.large,
            ),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
      ),
    );
  }
}
