import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';

/// [DetailScreen]'s top bar — back button and holding id / parcel-count
/// title only. "Add parcel for this person" moved to a floating action
/// button (`REFACTOR_ROADMAP.md` Phase 9 #7), matching `HomeScreen`'s
/// existing add-person FAB, so it stays reachable without occupying header
/// space.
class DetailScreenHeader extends StatelessWidget {
  const DetailScreenHeader({
    super.key,
    required this.holdingId,
    required this.parcelCount,
  });

  final String holdingId;
  final int parcelCount;

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
            ],
          ),
          verticalSpacing(16),
        ],
      ),
    );
  }
}
