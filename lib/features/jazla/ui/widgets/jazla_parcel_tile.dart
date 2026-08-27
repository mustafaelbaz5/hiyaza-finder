import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../holdings/data/model/parcel.dart';

/// One row inside [JazlaDetailScreen]'s ordered list — sequence number,
/// حائز/حوض, and المساحة. Tapping opens the app's existing full Detail
/// Screen (handled by the caller), swiping removes it from this Jazla only.
class JazlaParcelTile extends StatelessWidget {
  const JazlaParcelTile({
    super.key,
    required this.index,
    required this.parcel,
    required this.onTap,
  });

  final int index;
  final Parcel parcel;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String holder = parcel.holderName?.trim().isNotEmpty == true
        ? parcel.holderName!.trim()
        : '—';
    final String basin = parcel.basinName?.trim().isNotEmpty == true
        ? parcel.basinName!.trim()
        : '—';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary50.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: AppTextStyles.font12Bold.copyWith(color: AppColors.primary200),
                ),
              ),
              const SizedBox(width: 12),
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
                      '${parcel.feddan ?? 0} ف | ${parcel.qirat ?? 0} ق | ${parcel.sahm ?? 0} س',
                      style: AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              Icon(Icons.drag_handle_rounded, color: colors.iconSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
