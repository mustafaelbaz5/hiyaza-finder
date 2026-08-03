import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../cubit/sync_status_cubit.dart';
import '../cubit/sync_status_state.dart';
import 'sync_details_sheet.dart';

/// Small top-bar affordance showing whether there's unsynced work — the
/// user's only way to tell their edits are safe, per APP_PLAN.md § 7.6.
/// Hidden entirely when there's nothing pending and nothing failed (the
/// common case), so it never competes for attention with the rest of the
/// top bar.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(final BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (final BuildContext context, final SyncStatusState state) {
        if (!state.hasPending && !state.hasFailed && !state.isSyncing) {
          return const SizedBox.shrink();
        }

        // Offline only overrides the label when there's actually something
        // waiting on connectivity to go out — no point announcing "offline"
        // when nothing is pending (the badge would already be hidden above
        // in that case anyway, since neither hasFailed nor isSyncing would
        // be true either).
        final bool showWaitingForInternet = state.isOffline && state.hasPending;

        final Color tint = state.hasFailed ? AppColors.red200 : AppColors.amber300;
        final String label = showWaitingForInternet
            ? 'sync.status.waiting_for_internet'.tr()
            : state.isSyncing
                ? 'sync.status.syncing'.tr()
                : state.hasFailed
                    ? 'sync.status.failed'.tr(
                        namedArgs: {'count': state.failedCount.toString()},
                      )
                    : 'sync.status.pending'.tr(
                        namedArgs: {'count': state.pendingCount.toString()},
                      );

        return Tooltip(
          message: 'sync.status.tap_to_sync'.tr(),
          child: InkWell(
            onTap: () => showSyncDetailsSheet(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tint.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isSyncing)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tint,
                      ),
                    )
                  else
                    Icon(
                      state.hasFailed
                          ? Icons.sync_problem_rounded
                          : showWaitingForInternet
                              ? Icons.wifi_off_rounded
                              : Icons.cloud_sync_rounded,
                      size: 14,
                      color: tint,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.font12Bold.copyWith(color: tint),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
