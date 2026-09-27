import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../data/model/jazla.dart';
import 'jazla_area_summary.dart';

/// The single place for a Jazla's summary and management actions.
Future<void> showJazlaActionsSheet(
  final BuildContext context, {
  required final Jazla jazla,
  required final List<Parcel> parcels,
  required final VoidCallback onRename,
  required final VoidCallback onEditArea,
  required final VoidCallback onEditBasin,
  required final VoidCallback onBulkApply,
  required final VoidCallback onDelete,
  required final Widget exportExcelAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.customColors.surface,
    builder: (final BuildContext sheetContext) => _JazlaActionsSheet(
      jazla: jazla,
      parcels: parcels,
      onRename: onRename,
      onEditArea: onEditArea,
      onEditBasin: onEditBasin,
      onBulkApply: onBulkApply,
      onDelete: onDelete,
      exportExcelAction: exportExcelAction,
    ),
  );
}

class _JazlaActionsSheet extends StatelessWidget {
  const _JazlaActionsSheet({
    required this.jazla,
    required this.parcels,
    required this.onRename,
    required this.onEditArea,
    required this.onEditBasin,
    required this.onBulkApply,
    required this.onDelete,
    required this.exportExcelAction,
  });

  final Jazla jazla;
  final List<Parcel> parcels;
  final VoidCallback onRename;
  final VoidCallback onEditArea;
  final VoidCallback onEditBasin;
  final VoidCallback onBulkApply;
  final VoidCallback onDelete;
  final Widget exportExcelAction;

  void _closeThen(final BuildContext context, final VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(rw(20), rh(10), rw(12), rh(10)),
              child: Row(
                children: [
                  Expanded(child: _JazlaIdentity(jazla: jazla)),
                  IconButton(
                    tooltip: 'app_dialogs.close'.tr(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(rw(20), rh(16), rw(20), rh(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    JazlaAreaSummary(jazla: jazla, parcels: parcels),
                    verticalSpacing(22),
                    _ActionGroup(
                      title: 'jazla.actions.manage_section'.tr(),
                      children: [
                        _ActionTile(
                          title: 'jazla.rename'.tr(),
                          subtitle: jazla.name,
                          icon: Icons.drive_file_rename_outline_rounded,
                          onTap: () => _closeThen(context, onRename),
                        ),
                        _ActionTile(
                          title: 'jazla.actions.edit_basin'.tr(),
                          subtitle: jazla.basinName ?? '—',
                          icon: Icons.location_on_outlined,
                          onTap: () => _closeThen(context, onEditBasin),
                        ),
                        _ActionTile(
                          title: 'jazla.actions.edit_area'.tr(),
                          subtitle: jazla.targetAreaSqm == null
                              ? 'jazla.area.no_target'.tr()
                              : '${jazla.targetAreaSqm!.toStringAsFixed(2)} م²',
                          icon: Icons.straighten_rounded,
                          onTap: () => _closeThen(context, onEditArea),
                        ),
                      ],
                    ),
                    verticalSpacing(18),
                    _ActionGroup(
                      title: 'jazla.actions.operations_section'.tr(),
                      children: [
                        _ActionTile(
                          title: 'jazla.actions.export_excel'.tr(),
                          subtitle: 'jazla.actions.export_excel_hint'.tr(),
                          icon: Icons.table_chart_outlined,
                          trailing: exportExcelAction,
                        ),
                        _ActionTile(
                          title: 'jazla.actions.bulk_apply'.tr(),
                          subtitle: parcels.isEmpty
                              ? 'jazla.actions.no_parcels_hint'.tr()
                              : 'jazla.actions.bulk_apply_hint'.tr(),
                          icon: Icons.bolt_rounded,
                          enabled: parcels.isNotEmpty,
                          onTap: () => _closeThen(context, onBulkApply),
                        ),
                      ],
                    ),
                    verticalSpacing(18),
                    _ActionGroup(
                      title: 'jazla.actions.danger_section'.tr(),
                      children: [
                        _ActionTile(
                          title: 'jazla.delete'.tr(),
                          subtitle: 'jazla.actions.delete_hint'.tr(),
                          icon: Icons.delete_outline_rounded,
                          destructive: true,
                          onTap: () => _closeThen(context, onDelete),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JazlaIdentity extends StatelessWidget {
  const _JazlaIdentity({required this.jazla});

  final Jazla jazla;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary200.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.layers_rounded, color: AppColors.primary200),
        ),
        horizontalSpacing(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              verticalSpacing(5),
              Text(
                jazla.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.font18Bold
                    .copyWith(color: colors.textPrimary),
              ),
              verticalSpacing(2),
              Text(
                jazla.basinName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.font12Regular
                    .copyWith(color: colors.textSecondary),
              ),
              verticalSpacing(2),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style:
              AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.right,
        ),
        verticalSpacing(8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.enabled = true,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final Color foreground = destructive
        ? AppColors.red200
        : enabled
            ? colors.textPrimary
            : colors.textDisabled;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(icon,
                color: destructive ? AppColors.red200 : AppColors.primary200),
            horizontalSpacing(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.font14SemiBold
                        .copyWith(color: foreground),
                    textAlign: TextAlign.right,
                  ),
                  verticalSpacing(2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.font12Regular.copyWith(
                        color: enabled
                            ? colors.textSecondary
                            : colors.textDisabled),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: enabled ? colors.iconSecondary : colors.textDisabled,
                ),
          ],
        ),
      ),
    );
  }
}
