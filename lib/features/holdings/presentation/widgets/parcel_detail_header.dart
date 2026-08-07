import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import 'status_badge.dart';

/// The status/actions row at the top of [ParcelDetailCard] — badges for
/// added/pending-review/reviewed state, plus delete/reopen actions. Copy ID
/// is the sole completion trigger (`REFACTOR_ROADMAP.md` Phase 9 #3) — a
/// standalone "Finish" action used to exist here too and wrote the same
/// `completedAt` field via a second, independent path; removed so there's
/// only one way to complete a parcel. Reopen stays: it's the only UI path
/// that un-completes a parcel, which Copy ID intentionally never does.
class ParcelDetailTopRow extends StatelessWidget {
  const ParcelDetailTopRow({
    super.key,
    required this.isAdded,
    required this.isReviewed,
    required this.onReopen,
    required this.onDelete,
    required this.onDeleteConfirmed,
    this.isInheritance = false,
    this.isDelegate = false,
  });

  final bool isAdded;
  final bool isReviewed;
  final VoidCallback? onReopen;
  final VoidCallback? onDelete;
  final VoidCallback onDeleteConfirmed;

  /// وراثة / مفوض — real, DB-persisted `Parcel` fields (`REFACTOR_ROADMAP.md`
  /// Phase 7); previously only shown via the Copy-All clipboard text prefix,
  /// never as a visible in-app badge.
  final bool isInheritance;
  final bool isDelegate;

  @override
  Widget build(final BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              // The single "added" badge is `ParcelDetailInfoBanner` below
              // this top row (`REFACTOR_ROADMAP.md` Phase 11 §12) — this row
              // previously ALSO showed a small "added_from_app" StatusBadge
              // here, duplicating the same information the banner already
              // states more fully (label + hint + now the creator email).
              if (isInheritance)
                StatusBadge(
                  icon: Icons.groups_rounded,
                  label: 'holdings.status.inheritance'.tr(),
                  color: AppColors.amber200,
                ),
              if (isDelegate)
                StatusBadge(
                  icon: Icons.assignment_ind_rounded,
                  label: 'holdings.status.delegate'.tr(),
                  color: AppColors.amber200,
                ),
              if (!isReviewed)
                StatusBadge(
                  icon: Icons.task_alt_rounded,
                  label: 'holdings.status.pending_review'.tr(),
                  color: AppColors.amber200,
                ),
              if (isReviewed)
                // Lock icon (not a plain checkmark) reinforces that this
                // parcel is locked/read-only, not just "successfully
                // marked" — matches the card's own strengthened locked
                // styling below (`REFACTOR_ROADMAP.md` Phase 18).
                StatusBadge(
                  icon: Icons.lock_rounded,
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
          // Filled, high-contrast — the one interactive action left on a
          // locked card (`REFACTOR_ROADMAP.md` Phase 10 §9), so it needs to
          // read as clearly and immediately tappable, not as a muted
          // secondary control the way Reopen looked before.
          FilledButton.icon(
            onPressed: onReopen,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary200,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: Text('holdings.detail.reopen'.tr()),
          ),
      ],
    );
  }
}

/// A labeled info banner shown under [ParcelDetailTopRow] for the
/// added/reviewed states — icon, bold label, secondary subtitle, and an
/// optional third line (used for "تمت الإضافة بواسطة: …",
/// `REFACTOR_ROADMAP.md` Phase 11 §12) when [creatorLine] is given.
class ParcelDetailInfoBanner extends StatelessWidget {
  const ParcelDetailInfoBanner({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.creatorLine,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String? creatorLine;

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
                if (creatorLine != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    creatorLine!,
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The tappable رقم القطعة chip — copies [id] to the clipboard via [onCopy].
/// This is the screen's primary action (`REFACTOR_ROADMAP.md` Phase 9 #4):
/// it both identifies the parcel and, for an incomplete parcel, is what
/// completes it (see `ParcelDetailCard._copyId`) — filled and high-contrast
/// so it's the easiest thing on the card to find and tap, in contrast to
/// Reopen/Copy All/Delete's lighter outlined/icon-only treatments.
class ParcelIdChip extends StatelessWidget {
  const ParcelIdChip({super.key, required this.id, required this.onCopy});

  final String id;
  final VoidCallback onCopy;

  @override
  Widget build(final BuildContext context) {
    return Material(
      color: AppColors.green200,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onCopy,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: <Widget>[
              const Icon(Icons.fingerprint_rounded,
                  size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'holdings.detail.parcel_id'.tr(),
                      style: AppTextStyles.font12Bold.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.font14Bold.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
