import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../data/sync_runner.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/services/sync_operation_summary.dart';
import '../cubit/sync_status_cubit.dart';
import '../cubit/sync_status_state.dart';

/// The sync badge's tap target: what's queued, why anything failed, and
/// the actions to do something about it — the badge itself only ever
/// showed a bare count with no way to see or act on individual items.
Future<void> showSyncDetailsSheet(final BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => BlocProvider.value(
      value: context.read<SyncStatusCubit>(),
      child: const _SyncDetailsSheet(),
    ),
  );
}

class _SyncDetailsSheet extends StatefulWidget {
  const _SyncDetailsSheet();

  @override
  State<_SyncDetailsSheet> createState() => _SyncDetailsSheetState();
}

class _SyncDetailsSheetState extends State<_SyncDetailsSheet> {
  late Future<List<SyncOperation>> _operations;

  @override
  void initState() {
    super.initState();
    _operations = context.read<SyncStatusCubit>().pendingOperations();
  }

  void _refresh() {
    setState(() {
      _operations = context.read<SyncStatusCubit>().pendingOperations();
    });
  }

  /// Runs [action] (a sync/retry trigger) and shows a snackbar reporting
  /// what actually happened — without this, a failing sync (e.g. no
  /// network, or a server error) looks identical to a successful one: the
  /// list just silently doesn't change, with no feedback that anything
  /// was even attempted.
  Future<void> _runAndReport(final Future<void> Function() action) async {
    final int before = (await context.read<SyncStatusCubit>().pendingOperations()).length;
    await action();
    if (!mounted) return;
    final int after = (await context.read<SyncStatusCubit>().pendingOperations()).length;
    _refresh();
    if (!mounted) return;

    final int synced = before - after;
    if (after == 0) {
      context.showSuccessSnackBar('sync.details.result_all_synced'.tr());
    } else if (synced > 0) {
      context.showSuccessSnackBar(
        'sync.details.result_partial'.tr(
          namedArgs: {'synced': synced.toString(), 'remaining': after.toString()},
        ),
      );
    } else {
      context.showErrorSnackBar('sync.details.result_none'.tr());
    }
  }

  Future<void> _confirmDiscard(final SyncOperation op) async {
    await AppDialogs.showConfirm(
      context,
      message: 'sync.details.discard_confirm'.tr(),
      onConfirm: () async {
        await context.read<SyncStatusCubit>().discardOperation(op.id);
        if (!mounted) return;
        _refresh();
        context.showSuccessSnackBar('sync.details.discarded'.tr());
      },
    );
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(top: rh(60)),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            verticalSpacing(12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            verticalSpacing(16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sync.details.title'.tr(),
                    style: AppTextStyles.font18Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  verticalSpacing(6),
                  Text(
                    'sync.details.explainer'.tr(),
                    style: AppTextStyles.font14Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            verticalSpacing(12),
            Flexible(
              child: FutureBuilder<List<SyncOperation>>(
                future: _operations,
                builder: (final BuildContext context, final snapshot) {
                  final List<SyncOperation> ops = snapshot.data ?? const [];
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: rh(32)),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (ops.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: rh(32)),
                      child: Center(
                        child: Text(
                          'sync.details.empty'.tr(),
                          style: AppTextStyles.font14Regular.copyWith(
                            color: colors.textHint,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(horizontal: rw(16)),
                    children: [
                      for (final SyncOperation op in ops)
                        _SyncOperationTile(
                          operation: op,
                          onDiscard: () => _confirmDiscard(op),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(rw(16), rh(12), rw(16), rh(16)),
              child: BlocBuilder<SyncStatusCubit, SyncStatusState>(
                builder: (final BuildContext context, final state) {
                  return Row(
                    children: [
                      if (state.hasFailed) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.isSyncing
                                ? null
                                : () => _runAndReport(
                                      () => context.read<SyncStatusCubit>().retryFailed(),
                                    ),
                            child: Text('sync.details.retry_all'.tr()),
                          ),
                        ),
                        horizontalSpacing(12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary200,
                          ),
                          onPressed: state.isSyncing
                              ? null
                              : () => _runAndReport(
                                    () => context.read<SyncStatusCubit>().flushNow(),
                                  ),
                          child: Text(
                            'sync.details.sync_now'.tr(),
                            style: const TextStyle(color: AppColors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncOperationTile extends StatelessWidget {
  const _SyncOperationTile({required this.operation, required this.onDiscard});

  final SyncOperation operation;

  /// Removes this operation from the outbox without pushing it — the
  /// escape hatch for one that can never succeed (e.g. a payload shaped
  /// by a since-fixed bug; the fix only prevents new operations from
  /// having the problem, not this already-queued one).
  final VoidCallback onDiscard;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final bool failed = operation.attempts >= syncMaxAttempts;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: failed ? AppColors.red50.withValues(alpha: 0.3) : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: failed ? AppColors.red200 : colors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed ? Icons.error_outline_rounded : Icons.schedule_rounded,
            size: 18,
            color: failed ? AppColors.red200 : AppColors.amber300,
          ),
          horizontalSpacing(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  syncOperationSummary(operation),
                  style: AppTextStyles.font14SemiBold.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
                if (operation.lastError != null) ...[
                  verticalSpacing(4),
                  Text(
                    operation.lastError!,
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textHint,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          horizontalSpacing(4),
          IconButton(
            tooltip: 'sync.details.discard'.tr(),
            icon: Icon(Icons.close_rounded, size: 18, color: colors.textHint),
            onPressed: onDiscard,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
