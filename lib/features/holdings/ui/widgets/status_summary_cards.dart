import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';

/// Lightweight per-status breakdown row for the home screen — added /
/// pending-review / reviewed parcel counts (`REFACTOR_ROADMAP.md` Phase 7,
/// `PROJECT_OBJECTIVES.md` §4). Deliberately just three numbers, no filters
/// or drill-down — anything more crosses into the "activity center" scope
/// §4 explicitly excludes from the in-app experience.
class StatusSummaryCards extends StatelessWidget {
  const StatusSummaryCards({
    super.key,
    required this.addedCount,
    required this.pendingReviewCount,
    required this.reviewedCount,
  });

  final int addedCount;
  final int pendingReviewCount;
  final int reviewedCount;

  @override
  Widget build(final BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatusSummaryCard(
            icon: Icons.add_box_rounded,
            label: 'holdings.home.summary_added'.tr(),
            count: addedCount,
            color: AppColors.blue200,
          ),
        ),
        horizontalSpacing(8),
        Expanded(
          child: _StatusSummaryCard(
            icon: Icons.task_alt_rounded,
            label: 'holdings.home.summary_pending_review'.tr(),
            count: pendingReviewCount,
            color: AppColors.amber200,
          ),
        ),
        horizontalSpacing(8),
        Expanded(
          child: _StatusSummaryCard(
            icon: Icons.check_circle_rounded,
            label: 'holdings.home.summary_reviewed'.tr(),
            count: reviewedCount,
            color: AppColors.green200,
          ),
        ),
      ],
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  const _StatusSummaryCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              horizontalSpacing(6),
              Text(
                count.toString(),
                style: AppTextStyles.font16Bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          verticalSpacing(2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.font12Bold.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
