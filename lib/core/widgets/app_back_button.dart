import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import '../utils/extensions/context_ext.dart';

/// Rounded, tinted back button used across pushed screens so navigation
/// affordances look consistent with the home top bar. Uses a
/// direction-aware chevron so it points the correct way in RTL and LTR.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return InkWell(
      onTap: onTap ?? () => context.pop(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isRtl ? Icons.arrow_back_ios_new_outlined : Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.primary200,
        ),
      ),
    );
  }
}
