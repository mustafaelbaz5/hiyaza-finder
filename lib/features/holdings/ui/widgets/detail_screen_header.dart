import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';

/// [DetailScreen]'s top bar — back button, Previous/Next between holdings
/// in the same basin (APP_CLAUDE.md § Screen 3), and the holding id/holder
/// title, all in one AppBar-style row (UI/UX Updates prompt "Change 1" —
/// previously Previous/Next lived in a separate row below this one; now
/// they sit directly beside the back button and title, matching an
/// AppBar's leading/title/actions layout even though this stays a plain
/// widget rather than `Scaffold.appBar`, so the existing back-button/title
/// styling doesn't need to be rebuilt around Material's AppBar). "Add
/// parcel for this person" is on a floating action button instead, matching
/// `HomeScreen`'s add-person FAB, so it stays reachable without occupying
/// header space.
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

  /// `null` disables/hides that direction — first/last holding in the
  /// basin, or no basin context at all (e.g. reached from a search result
  /// rather than a `BasinScreen`).
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

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
              const AppBackButton(),
              if (onPrevious != null)
                IconButton(
                  tooltip: 'holdings.detail.previous_holding'.tr(),
                  onPressed: () => _navigate(onPrevious!),
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary200,
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
              if (onNext != null)
                IconButton(
                  tooltip: 'holdings.detail.next_holding'.tr(),
                  onPressed: () => _navigate(onNext!),
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.primary200,
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
