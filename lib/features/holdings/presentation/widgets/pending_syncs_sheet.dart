import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/services/sync_runner.dart';
import 'sync_operation_summary.dart';

/// Shows the outbox's queued/parked writes (`REFACTOR_ROADMAP.md` Phase 9
/// #9's failed-syncs UI) — the visibility half of the optimistic-write
/// contract: a write always applies locally immediately, but a
/// permanently-failed background sync must never just silently vanish.
/// Retry/discard act directly on the shared `SyncRunner` singleton, so the
/// list updates live via `onQueueChanged` while the sheet is open.
Future<void> showPendingSyncsSheet(final BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => const _PendingSyncsSheet(),
  );
}

class _PendingSyncsSheet extends StatelessWidget {
  const _PendingSyncsSheet();

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final SyncRunner syncRunner = getIt<SyncRunner>();

    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(top: rh(60)),
        constraints: BoxConstraints(maxHeight: rh(560)),
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
              child: Text(
                'sync.details.title'.tr(),
                style: AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.right,
              ),
            ),
            verticalSpacing(4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(20)),
              child: Text(
                'sync.details.explainer'.tr(),
                style: AppTextStyles.font14Regular.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.right,
              ),
            ),
            verticalSpacing(12),
            Flexible(
              child: StreamBuilder<List<SyncOperation>>(
                stream: syncRunner.onQueueChanged,
                initialData: syncRunner.operations,
                builder: (final BuildContext context, final snapshot) {
                  final List<SyncOperation> ops = snapshot.data ?? const <SyncOperation>[];
                  if (ops.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: rw(20),
                        vertical: rh(32),
                      ),
                      child: Text(
                        'sync.details.empty'.tr(),
                        style: AppTextStyles.font14Regular.copyWith(
                          color: colors.textHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(horizontal: rw(16)).copyWith(bottom: rh(24)),
                    children: [
                      for (final (int i, SyncOperation op) in ops.indexed)
                        _PendingSyncTile(
                          key: ValueKey<String>(op.operationId),
                          operation: op,
                          onRetry: () => syncRunner.retry(op.operationId),
                          onDiscard: () => _confirmDiscard(context, syncRunner, op),
                        ).animate(delay: (i * 25).ms).fadeIn(duration: 180.ms),
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

  Future<void> _confirmDiscard(
    final BuildContext context,
    final SyncRunner syncRunner,
    final SyncOperation op,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (final BuildContext dialogContext) => AlertDialog(
        title: Text('sync.details.discard'.tr()),
        content: Text('sync.details.discard_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('app_dialogs.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('sync.details.discard'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    syncRunner.remove(op.operationId);
    if (context.mounted) {
      context.showSuccessSnackBar('sync.details.discarded'.tr());
    }
  }
}

/// Owns its own in-flight state for the retry button (`REFACTOR_ROADMAP.md`
/// Phase 26) — previously this was a `StatelessWidget` whose "retry" button
/// called `SyncRunner.retry` and then *unconditionally* showed a success
/// snackbar, regardless of whether the retry actually worked. A retry that
/// fails (e.g. still offline) left the tile showing the exact same
/// unchanged error, while the button appeared to do nothing — no loading
/// feedback, and a misleading "success" message on top of a silent failure.
/// Now: a spinner replaces the button label while the retry is in flight,
/// and the result snackbar reflects [SyncRunner.retry]'s real return value.
class _PendingSyncTile extends StatefulWidget {
  const _PendingSyncTile({
    super.key,
    required this.operation,
    required this.onRetry,
    required this.onDiscard,
  });

  final SyncOperation operation;
  final Future<bool> Function() onRetry;
  final VoidCallback onDiscard;

  @override
  State<_PendingSyncTile> createState() => _PendingSyncTileState();
}

class _PendingSyncTileState extends State<_PendingSyncTile> {
  bool _isRetrying = false;

  bool get _isFailed => widget.operation.attempts > 0;

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    final bool succeeded = await widget.onRetry();
    if (!mounted) return;
    setState(() => _isRetrying = false);
    if (succeeded) {
      context.showSuccessSnackBar('sync.details.retry_succeeded'.tr());
    } else {
      context.showErrorSnackBar('sync.details.retry_failed'.tr());
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _isFailed
            ? AppColors.red200.withValues(alpha: 0.06)
            : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFailed ? AppColors.red200.withValues(alpha: 0.3) : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _isFailed ? Icons.error_outline_rounded : Icons.sync_rounded,
                size: 18,
                color: _isFailed ? AppColors.red200 : colors.iconSecondary,
              ),
              horizontalSpacing(8),
              Expanded(
                child: Text(
                  syncOperationSummary(widget.operation),
                  style: AppTextStyles.font14SemiBold.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (_isFailed) ...[
            verticalSpacing(6),
            Text(
              'sync.details.result_none'.tr(),
              style: AppTextStyles.font12Regular.copyWith(color: colors.textHint),
              textAlign: TextAlign.right,
            ),
            verticalSpacing(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomTextButton(
                  text: 'sync.details.discard'.tr(),
                  size: CustomButtonSize.small,
                  isFullWidth: false,
                  onPressed: _isRetrying ? null : widget.onDiscard,
                ),
                horizontalSpacing(8),
                CustomTextButton.outlined(
                  text: 'errors.retry'.tr(),
                  size: CustomButtonSize.small,
                  isFullWidth: false,
                  isLoading: _isRetrying,
                  onPressed: _isRetrying ? null : _handleRetry,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
