import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../holdings/data/local/clipboard_formatter.dart';
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

  static const ClipboardFormatter _formatter = ClipboardFormatter();

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String holder = parcel.holderName?.trim().isNotEmpty == true
        ? parcel.holderName!.trim()
        : '—';
    final String basin = parcel.basinName?.trim().isNotEmpty == true
        ? parcel.basinName!.trim()
        : '—';
    // Same formatter the main Detail Screen uses — plain `.toString()`
    // rendering, always Western digits, never derived from ambient locale.
    final String feddan = _formatter.formatNumber(parcel.feddan) ?? '0';
    final String qirat = _formatter.formatNumber(parcel.qirat) ?? '0';
    final String sahm = _formatter.formatNumber(parcel.sahm) ?? '0';

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
                      '$feddan ف | $qirat ق | $sahm س',
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
