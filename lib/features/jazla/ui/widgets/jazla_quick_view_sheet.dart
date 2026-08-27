import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../holdings/data/model/parcel.dart';
import '../../../holdings/data/repo/holdings_repository.dart';
import '../../../holdings/data/repo/holdings_writer.dart';
import '../../../holdings/ui/widgets/field_row.dart';
import '../../../holdings/ui/widgets/toggle_field_row.dart';
import '../../data/repo/jazla_repo.dart';

/// Opens on "+" for a free search result — shows key fields read-only, plus
/// EDITABLE وراثة/مفوض toggles held as a purely in-memory draft. "إلغاء"
/// discards the draft entirely; "إضافة للجزلة" commits it via
/// `HoldingsWriter.updateParcel` THEN adds the id to the Jazla. No new
/// persistence layer — the draft never touches `JazlaStore`.
Future<bool?> showJazlaQuickViewSheet(
  final BuildContext context, {
  required final Parcel parcel,
  required final String jazlaId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => JazlaQuickViewSheet(
      original: parcel,
      jazlaId: jazlaId,
    ),
  );
}

class JazlaQuickViewSheet extends StatefulWidget {
  const JazlaQuickViewSheet({
    super.key,
    required this.original,
    required this.jazlaId,
  });

  final Parcel original;
  final String jazlaId;

  @override
  State<JazlaQuickViewSheet> createState() => _JazlaQuickViewSheetState();
}

class _JazlaQuickViewSheetState extends State<JazlaQuickViewSheet> {
  late Parcel _draft = widget.original;
  bool _isSaving = false;

  Future<void> _confirm() async {
    setState(() => _isSaving = true);
    try {
      if (_draft != widget.original) {
        await getIt<HoldingsWriter>().updateParcel(_draft);
      }
      final String cityId = getIt<HoldingsRepository>().activeCityId ?? '';
      await getIt<JazlaRepo>().addParcel(widget.jazlaId, _draft.id, cityId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        context.showErrorSnackBar(e.toString());
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: rh(600)),
        padding: EdgeInsets.fromLTRB(rw(20), rh(16), rw(20), rh(20)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(rr(20))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.original.holderName?.trim().isNotEmpty == true
                        ? widget.original.holderName!.trim()
                        : 'jazla.quick_view.title'.tr(),
                    style: AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.right,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.iconSecondary),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            verticalSpacing(12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldRow(label: 'رقم الحيازة', value: widget.original.holdingId),
                    verticalSpacing(8),
                    FieldRow(
                      label: 'اسم الحائز',
                      value: widget.original.holderName ?? '-',
                    ),
                    verticalSpacing(8),
                    FieldRow(
                      label: 'اسم المالك',
                      value: widget.original.ownerName ?? '-',
                    ),
                    verticalSpacing(8),
                    FieldRow(
                      label: 'اسم الحوض',
                      value: widget.original.basinName ?? '-',
                    ),
                    verticalSpacing(8),
                    FieldRow(
                      label: 'المساحة',
                      value: '${widget.original.feddan ?? 0}ف '
                          '${widget.original.qirat ?? 0}ق '
                          '${widget.original.sahm ?? 0}س',
                    ),
                    verticalSpacing(16),
                    ToggleFieldRow(
                      label: 'jazla.quick_view.inheritance'.tr(),
                      value: _draft.isInheritance,
                      onChanged: (final bool v) =>
                          setState(() => _draft = _draft.copyWith(isInheritance: v)),
                    ),
                    verticalSpacing(8),
                    ToggleFieldRow(
                      label: 'jazla.quick_view.delegate'.tr(),
                      value: _draft.isDelegate,
                      onChanged: (final bool v) =>
                          setState(() => _draft = _draft.copyWith(isDelegate: v)),
                    ),
                  ],
                ),
              ),
            ),
            verticalSpacing(16),
            Row(
              children: [
                Expanded(
                  child: CustomTextButton.outlined(
                    text: 'jazla.quick_view.cancel'.tr(),
                    onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                  ),
                ),
                horizontalSpacing(8),
                Expanded(
                  child: CustomTextButton(
                    text: 'jazla.quick_view.confirm'.tr(),
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _confirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

