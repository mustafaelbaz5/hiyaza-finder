import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../core/utils/app_assets.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';

class AboutAppHeader extends StatelessWidget {
  const AboutAppHeader({super.key});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Row(
      children: [
        // App icon
        Container(
          width: rw(64),
          height: rh(64),
          decoration: BoxDecoration(
            color: AppColors.grey500.withAlpha(50),
            borderRadius: BorderRadius.circular(18),
          ),
          child: SvgPicture.asset(AppAssets.appLogoSvg),
        ),
        horizontalSpacing(16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConfig.appName,
              style: AppTextStyles.font20Bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            verticalSpacing(2),
            Text(
              'v${AppConfig.appVersion} (${AppConfig.buildNumber})',
              style: AppTextStyles.font14Regular.copyWith(
                color: colors.textHint,
              ),
            ),
            // Only show in development
            if (AppConfig.isDevelopment) ...[
              verticalSpacing(6),
              Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: rw(8),
                  vertical: rh(4),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary400,
                  borderRadius: BorderRadius.circular(rr(8)),
                ),
                child: Text(
                  'about.app_info.development_badge'.tr(),
                  style:
                      AppTextStyles.font12Bold.copyWith(color: AppColors.white),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
