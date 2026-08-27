import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../data/local/jazla_search_service.dart';
import 'jazla_locked_badge.dart';

/// One search result row in [JazlaAddParcelSheet] — a "+" to add a free
/// parcel (opens Quick View), or a [JazlaLockedBadge] for one already in
/// another Jazla.
class JazlaParcelResultTile extends StatelessWidget {
  const JazlaParcelResultTile({
    super.key,
    required this.result,
    required this.onAddTap,
  });

  final ParcelSearchResult result;
  final VoidCallback onAddTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String holder = result.parcel.holderName?.trim().isNotEmpty == true
        ? result.parcel.holderName!.trim()
        : '—';
    final String basin = result.parcel.basinName?.trim().isNotEmpty == true
        ? result.parcel.basinName!.trim()
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          if (result.isLocked)
            JazlaLockedBadge(jazlaName: result.jazlaName!)
          else
            InkWell(
              onTap: onAddTap,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary200,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$holder | $basin',
                  style: AppTextStyles.font14SemiBold.copyWith(color: colors.textPrimary),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.parcel.feddan ?? 0}ف | ${result.parcel.qirat ?? 0}ق | ${result.parcel.sahm ?? 0}س',
                  style: AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
