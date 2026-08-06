import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import 'status_badge.dart';

/// The status/actions row at the top of [ParcelDetailCard] — badges for
/// added/pending-review/reviewed state, plus delete/finish/reopen actions.
class ParcelDetailTopRow extends StatelessWidget {
  const ParcelDetailTopRow({
    super.key,
    required this.isAdded,
    required this.isReviewed,
    required this.onFinish,
    required this.onReopen,
    required this.onDelete,
    required this.onDeleteConfirmed,
  });

  final bool isAdded;
  final bool isReviewed;
  final VoidCallback? onFinish;
  final VoidCallback? onReopen;
  final VoidCallback? onDelete;
  final VoidCallback onDeleteConfirmed;

  @override
  Widget build(final BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (isAdded)
                StatusBadge(
                  icon: Icons.add_box_rounded,
                  label: 'holdings.status.added_from_app'.tr(),
                  color: AppColors.blue200,
                ),
              if (!isReviewed && onFinish != null)
                StatusBadge(
                  icon: Icons.task_alt_rounded,
                  label: 'holdings.status.pending_review'.tr(),
                  color: AppColors.amber200,
                ),
              if (isReviewed)
                StatusBadge(
                  icon: Icons.check_circle_rounded,
                  label: 'holdings.status.reviewed'.tr(),
                  color: AppColors.green200,
                ),
            ],
          ),
        ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.red200),
            tooltip: 'holdings.detail.delete'.tr(),
            onPressed: onDeleteConfirmed,
          ),
        if (isReviewed && onReopen != null)
          FilledButton.tonalIcon(
            onPressed: onReopen,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('holdings.detail.reopen'.tr()),
          )
        else if (!isReviewed && onFinish != null)
          FilledButton.tonalIcon(
            onPressed: onFinish,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text('holdings.detail.finished'.tr()),
          ),
      ],
    );
  }
}

/// A labeled info banner shown under [ParcelDetailTopRow] for the
/// added/reviewed states — icon, bold label, and a secondary subtitle.
class ParcelDetailInfoBanner extends StatelessWidget {
  const ParcelDetailInfoBanner({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.font14Bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.font12Bold.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The tappable رقم القطعة chip — copies [id] to the clipboard via [onCopy].
class ParcelIdChip extends StatelessWidget {
  const ParcelIdChip({super.key, required this.id, required this.onCopy});

  final String id;
  final VoidCallback onCopy;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Material(
      color: colors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onCopy,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.green200.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.fingerprint_rounded,
                  size: 18, color: AppColors.green200),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'holdings.detail.parcel_id'.tr(),
                      style: AppTextStyles.font12Bold.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.font14Bold,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded,
                  size: 18, color: AppColors.green200),
            ],
          ),
        ),
      ),
    );
  }
}
