import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';

/// Shown when a non-empty search query returns nothing (UI/UX Updates
/// prompt "Change 3") — distinct from [HomeEmptyState], which is the
/// before-the-user-types default. Still offers "إضافة بيانات جديدة" since a
/// query someone expected to find could just as easily be a person who
/// genuinely isn't in the data yet.
class HomeNoResults extends StatelessWidget {
  const HomeNoResults({super.key, required this.query, this.onAddNew});

  final String query;
  final VoidCallback? onAddNew;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 48,
              color: colors.iconSecondary,
            ),
            verticalSpacing(16),
            Text(
              'holdings.search.no_results_for'.tr(namedArgs: {'query': query}),
              style: AppTextStyles.font16SemiBold.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(8),
            Text(
              'holdings.search.no_results_hint'.tr(),
              style: AppTextStyles.font14Regular.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAddNew != null) ...[
              verticalSpacing(16),
              CustomTextButton(
                text: 'holdings.add.new_person_cta'.tr(),
                onPressed: onAddNew,
                isFullWidth: false,
                prefixIcon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
