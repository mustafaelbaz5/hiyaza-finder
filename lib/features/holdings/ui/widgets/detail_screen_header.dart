import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'parcel_nav_buttons.dart';

/// [DetailScreen]'s top bar — back button, holding id / parcel-count title,
/// and Previous/Next between holdings in the same basin (APP_CLAUDE.md §
/// Screen 3). "Add parcel for this person" is on a floating action button
/// instead, matching `HomeScreen`'s add-person FAB, so it stays reachable
/// without occupying header space.
class DetailScreenHeader extends StatelessWidget {
  const DetailScreenHeader({
    super.key,
    required this.holdingId,
    required this.parcelCount,
    this.onPrevious,
    this.onNext,
  });

  final String holdingId;
  final int parcelCount;

  /// `null` disables that direction — first/last holding in the basin, or
  /// no basin context at all (e.g. reached from a search result rather
  /// than a `BasinScreen`).
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rw(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          verticalSpacing(16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const AppBackButton(),
              horizontalSpacing(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'holdings.detail.title'.tr(namedArgs: {'id': holdingId}),
                      style: AppTextStyles.font20Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    if (parcelCount > 1) ...<Widget>[
                      verticalSpacing(2),
                      Text(
                        'holdings.detail.parcel_count'.tr(
                          namedArgs: {'count': parcelCount.toString()},
                        ),
                        style: AppTextStyles.font12Regular.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),
              if (onPrevious != null || onNext != null)
                ParcelNavButtons(onPrevious: onPrevious, onNext: onNext),
            ],
          ),
          verticalSpacing(16),
        ],
      ),
    );
  }
}
