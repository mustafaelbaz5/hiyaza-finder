import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// Previous/Next between holdings in the same basin (APP_CLAUDE.md § Screen
/// 3) — a `null` callback disables that direction's button (first/last
/// holding in the basin).
class ParcelNavButtons extends StatelessWidget {
  const ParcelNavButtons({
    super.key,
    required this.onPrevious,
    required this.onNext,
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'holdings.detail.previous_holding'.tr(),
          onPressed: onPrevious,
          icon: Icon(
            Icons.chevron_right_rounded,
            color: onPrevious == null ? colors.textHint : AppColors.primary200,
          ),
        ),
        IconButton(
          tooltip: 'holdings.detail.next_holding'.tr(),
          onPressed: onNext,
          icon: Icon(
            Icons.chevron_left_rounded,
            color: onNext == null ? colors.textHint : AppColors.primary200,
          ),
        ),
      ],
    );
  }
}
