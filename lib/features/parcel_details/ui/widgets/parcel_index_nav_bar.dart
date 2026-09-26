import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';

/// Previous/Next between the parcels of the *same* person shown on
/// `DetailScreen` — lets a field worker with a 5-parcel holding step through
/// each parcel's card one at a time instead of scrolling a stacked list.
/// Only rendered when the active tab has more than one parcel to page
/// through; a single-parcel holding never shows this row.
class ParcelIndexNavBar extends StatelessWidget {
  const ParcelIndexNavBar({
    super.key,
    required this.index,
    required this.count,
    required this.onPrevious,
    required this.onNext,
  });

  /// 0-based index of the currently shown parcel within the active tab's
  /// filtered list.
  final int index;
  final int count;

  /// `null` disables that direction — first/last parcel in the list.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'holdings.detail.previous_parcel'.tr(),
          onPressed: onPrevious,
          icon: Icon(
            Icons.chevron_right_rounded,
            color: onPrevious == null ? colors.textHint : AppColors.primary200,
          ),
        ),
        horizontalSpacing(4),
        Text(
          'holdings.detail.parcel_index'.tr(
            namedArgs: {
              'index': (index + 1).toString(),
              'count': count.toString(),
            },
          ),
          style: AppTextStyles.font14SemiBold.copyWith(
            color: colors.textSecondary,
          ),
        ),
        horizontalSpacing(4),
        IconButton(
          tooltip: 'holdings.detail.next_parcel'.tr(),
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
