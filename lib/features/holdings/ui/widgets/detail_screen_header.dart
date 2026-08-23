import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';

/// [DetailScreen]'s top bar (UI/UX Updates prompt "Change 4") — the
/// between-holdings/between-persons arrows this used to show are gone
/// entirely; the only navigation left here is between the *same* person's
/// own parcels, moved from a separate row below the AppBar into the AppBar
/// itself. RTL layout (right = leading, per the prompt):
/// `[ ◀ prev-parcel ] [ Title: holder name ] [ next-parcel ▶ ] [ back ← ]`.
/// Both arrows are always rendered — greyed out (never hidden) when there's
/// only one parcel to page through, or at the first/last one — so the
/// control's presence never shifts the title's position.
class DetailScreenHeader extends StatelessWidget {
  const DetailScreenHeader({
    super.key,
    required this.holdingId,
    required this.parcelCount,
    this.onPreviousParcel,
    this.onNextParcel,
  });

  final String holdingId;
  final int parcelCount;

  /// `null` disables (greys out, never hides) that direction — first/last
  /// parcel among the currently-visible ones, or a single-parcel holding.
  final VoidCallback? onPreviousParcel;
  final VoidCallback? onNextParcel;

  void _navigate(final VoidCallback callback) {
    HapticFeedback.selectionClick();
    callback();
  }

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
              IconButton(
                tooltip: 'holdings.detail.previous_parcel'.tr(),
                onPressed: onPreviousParcel == null
                    ? null
                    : () => _navigate(onPreviousParcel!),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: onPreviousParcel == null
                      ? colors.textHint
                      : AppColors.primary200,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'holdings.detail.title'.tr(namedArgs: {'id': holdingId}),
                      style: AppTextStyles.font20Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'holdings.detail.next_parcel'.tr(),
                onPressed:
                    onNextParcel == null ? null : () => _navigate(onNextParcel!),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color:
                      onNextParcel == null ? colors.textHint : AppColors.primary200,
                ),
              ),
              const AppBackButton(),
            ],
          ),
          verticalSpacing(16),
        ],
      ),
    );
  }
}
