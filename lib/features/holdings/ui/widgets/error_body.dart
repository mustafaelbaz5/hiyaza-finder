import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/core/widgets/custom_text_button.dart';
import 'package:hiyaza_finder/features/holdings/logic/cubit/home_state.dart';

class ErrorBody extends StatelessWidget {
  const ErrorBody({super.key, required this.state, required this.onPickFile});

  final HomeState state;
  final VoidCallback onPickFile;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final bool isColumnsError = state.missingColumns.isNotEmpty;
    final String message = isColumnsError
        ? 'holdings.error.invalid_file'.tr(
            namedArgs: {'columns': state.missingColumns.join('، ')},
          )
        : (state.errorMessage ?? 'holdings.error.generic'.tr());

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(rw(24)),
              decoration: BoxDecoration(
                color: AppColors.red200.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: rf(56),
                color: AppColors.red200,
              ),
            ).animate().shake(duration: 400.ms, hz: 4),
            verticalSpacing(20),
            Text(
              message,
              style: AppTextStyles.font16SemiBold.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(28),
            CustomTextButton(
              text: 'holdings.error.pick_another'.tr(),
              onPressed: onPickFile,
              isFullWidth: false,
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }
}
