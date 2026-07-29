import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/features/holdings/data/models/cached_file_entry.dart';

class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.entry, required this.onTap});

  final CachedFileEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String formattedDate = DateFormat(
      'yyyy/MM/dd – HH:mm',
    ).format(entry.cachedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary50.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: AppColors.primary200,
              ),
            ),
            horizontalSpacing(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    style: AppTextStyles.font16SemiBold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'holdings.history.holdings_count'.tr(
                      namedArgs: {'count': entry.holdingCount.toString()},
                    ),
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textHint,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: AppColors.primary200,
            ),
          ],
        ),
      ),
    );
  }
}
