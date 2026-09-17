import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// Shown on a search result already claimed by another Jazla — not
/// addable, names the owning Jazla so the field worker knows where to look.
class JazlaLockedBadge extends StatelessWidget {
  const JazlaLockedBadge({super.key, required this.jazlaName});

  final String jazlaName;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amber200.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.amber200),
          const SizedBox(width: 4),
          Text(
            'jazla.add_sheet.locked_badge'.tr(namedArgs: {'jazlaName': jazlaName}),
            style: AppTextStyles.font12Bold.copyWith(color: AppColors.amber200),
          ),
        ],
      ),
    );
  }
}
