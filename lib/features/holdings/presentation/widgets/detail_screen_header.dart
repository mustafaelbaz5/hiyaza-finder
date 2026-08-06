import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/custom_text_button.dart';

/// [DetailScreen]'s top bar — back button, holding id / parcel-count title,
/// refresh action, and (when parcels exist) the "add parcel for this
/// person" button — extracted so the screen's own build method is just the
/// parcel list itself.
class DetailScreenHeader extends StatelessWidget {
  const DetailScreenHeader({
    super.key,
    required this.holdingId,
    required this.parcelCount,
    required this.isBusy,
    required this.onRefresh,
    required this.onAddParcel,
  });

  final String holdingId;
  final int parcelCount;
  final bool isBusy;
  final VoidCallback onRefresh;
  final VoidCallback? onAddParcel;

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
              IconButton(
                onPressed: isBusy ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'holdings.detail.refresh'.tr(),
              ),
            ],
          ),
          if (onAddParcel != null) ...<Widget>[
            verticalSpacing(12),
            CustomTextButton.outlined(
              text: 'holdings.add.new_parcel_title'.tr(),
              size: CustomButtonSize.small,
              isFullWidth: false,
              prefixIcon: const Icon(Icons.add_location_alt_rounded),
              onPressed: onAddParcel,
            ),
          ],
          verticalSpacing(16),
        ],
      ),
    );
  }
}
