import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// The card's copy-all action — a full-width, clearly tappable outlined
/// button (`REFACTOR_ROADMAP.md` Phase 12): previously shrunk down to a
/// small right-aligned text link (Phase 9 #4/Phase 10 §7), which made it
/// hard to notice and hard to hit accurately. Kept visually secondary to
/// [ParcelIdChip] — outlined rather than filled, so Copy ID still reads as
/// the primary action — but restored to a real, easy-to-use button rather
/// than a barely-visible link.
class CopyAllButton extends StatelessWidget {
  const CopyAllButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final TextStyle textStyle = AppTextStyles.font14SemiBold.copyWith(
      color: AppColors.primary200,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary200.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.copy_all_rounded,
                size: 18,
                color: AppColors.primary200,
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
