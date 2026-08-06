import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// A prominent, full-width filled pill for the card's copy-all action.
class CopyAllButton extends StatelessWidget {
  const CopyAllButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final TextStyle textStyle =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .merge(AppTextStyles.font16Bold)
            .copyWith(color: AppColors.white);

    return Material(
      color: AppColors.primary200,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      shadowColor: AppColors.primary200.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.copy_all_rounded,
                size: 22,
                color: AppColors.white,
              ),
              const SizedBox(width: 8),
              Text('holdings.detail.copy_all'.tr(), style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}
