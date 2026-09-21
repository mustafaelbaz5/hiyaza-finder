import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/spacing.dart';
import '../../../holdings/data/model/parcel.dart';
import '../../data/model/jazla.dart';
import 'jazla_area_summary.dart';

Future<void> showJazlaActionsSheet(
  final BuildContext context, {
  required final Jazla jazla,
  required final List<Parcel> parcels,
  required final VoidCallback onEditArea,
  required final VoidCallback onEditBasin,
  required final VoidCallback onBulkApply,
  required final Widget exportExcelAction,
  required final Widget sharePdfAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (final BuildContext sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(jazla.name, style: AppTextStyles.font18Bold),
            if (jazla.basinName != null) Text(jazla.basinName!),
            JazlaAreaSummary(jazla: jazla, parcels: parcels),
            verticalSpacing(8),
            _Action(title: 'jazla.actions.edit_area'.tr(), icon: Icons.straighten_rounded, onTap: onEditArea),
            _Action(title: 'jazla.actions.edit_basin'.tr(), icon: Icons.location_on_outlined, onTap: onEditBasin),
            _ActionWithWidget(title: 'jazla.actions.export_excel'.tr(), icon: Icons.table_chart_outlined, child: exportExcelAction),
            _ActionWithWidget(title: 'jazla.actions.share_pdf'.tr(), icon: Icons.picture_as_pdf_outlined, child: sharePdfAction),
            _Action(title: 'jazla.actions.bulk_apply'.tr(), icon: Icons.bolt_rounded, onTap: onBulkApply),
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.title, required this.icon, required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title, textAlign: TextAlign.right),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
}

class _ActionWithWidget extends StatelessWidget {
  const _ActionWithWidget({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(final BuildContext context) => Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(child: Text(title, textAlign: TextAlign.right)),
          child,
        ],
      );
}
