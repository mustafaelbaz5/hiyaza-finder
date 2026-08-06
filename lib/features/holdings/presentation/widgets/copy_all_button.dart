import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// A secondary, outlined pill for the card's copy-all action — deliberately
/// lighter-weight than [ParcelIdChip] (`REFACTOR_ROADMAP.md` Phase 9 #4):
/// Copy ID is the primary, most-used action, this is an occasional one.
class CopyAllButton extends StatelessWidget {
  const CopyAllButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final TextStyle textStyle = AppTextStyles.font14SemiBold.copyWith(
      color: colors.textSecondary,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.copy_all_rounded,
                size: 18,
                color: colors.textSecondary,
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
