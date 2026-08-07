import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// A small, compact text action for the card's copy-all action — deliberately
/// lighter-weight and not full-width (`REFACTOR_ROADMAP.md` Phase 9 #4,
/// Phase 10 §7): Copy ID is the primary, most-used action and the app is
/// primarily a data-entry tool, not a copy/export one — this stays a
/// low-emphasis, occasional action that doesn't compete for attention or
/// screen space.
class CopyAllButton extends StatelessWidget {
  const CopyAllButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final TextStyle textStyle = AppTextStyles.font12Medium.copyWith(
      color: colors.textSecondary,
    );

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.copy_all_rounded,
                  size: 14,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text('holdings.detail.copy_all'.tr(), style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
