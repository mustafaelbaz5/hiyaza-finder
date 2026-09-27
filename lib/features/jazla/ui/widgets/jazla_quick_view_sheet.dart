import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/ui/fields/field_row.dart';
import '../../../../core/widgets/ui/fields/toggle_field_row.dart';
import '../../../crop_type/ui/widgets/crop_type_picker.dart';
import '../../../parcel_catalog/data/local/area_calculator.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/model/usage_type.dart';
import '../../../parcel_details/ui/widgets/delegate_owner_dialog.dart';
import '../../../parcel_details/ui/widgets/field_edit_dialogs.dart';
import '../../../parcel_details/ui/widgets/parcel_quick_choice_sheet.dart';
import '../../../parcel_editor/data/local/delegate_notes_policy.dart';
import '../../../parcel_editor/data/local/usage_type_notes_sync.dart';

/// Opens from a free search result. The sheet owns only a temporary draft;
/// persistence and Jazla membership are injected by its caller.
Future<Parcel?> showJazlaQuickViewSheet(
  final BuildContext context, {
  required final Parcel parcel,
  required final Future<Parcel?> Function(Parcel draft) onSave,
}) {
  return showModalBottomSheet<Parcel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => JazlaQuickViewSheet(
      original: parcel,
      onSave: onSave,
    ),
  );
}

class JazlaQuickViewSheet extends StatefulWidget {
  const JazlaQuickViewSheet({
    super.key,
    required this.original,
    required this.onSave,
  });

  final Parcel original;
  final Future<Parcel?> Function(Parcel draft) onSave;

  @override
  State<JazlaQuickViewSheet> createState() => _JazlaQuickViewSheetState();
}

class _JazlaQuickViewSheetState extends State<JazlaQuickViewSheet> {
  late Parcel _draft = widget.original;
  bool _isSaving = false;

  Future<void> _confirm() async {
    setState(() => _isSaving = true);
    try {
      final Parcel? saved = await widget.onSave(_draft);
      if (mounted && saved != null) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        context.showErrorSnackBar(error.toString());
      }
    }
  }

  Future<void> _editArea() async {
    final AreaEditResult? result = await showAreaFieldEditDialog(
      context,
      feddan: _draft.feddan,
      qirat: _draft.qirat,
      sahm: _draft.sahm,
    );
    if (result == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        feddan: result.feddan,
        qirat: result.qirat,
        sahm: result.sahm,
        totalSqm: AreaCalculator.totalSqm(
          feddan: result.feddan,
          qirat: result.qirat,
          sahm: result.sahm,
        ),
      );
    });
  }

  Future<void> _editUsage() async {
    final String? selected = await showParcelQuickChoiceSheet(
      context,
      title: 'holdings.fields.usage_type'.tr(),
      selected: _draft.usageType,
      options: Parcel.usageTypeOptions,
    );
    if (selected == null || selected == _draft.usageType || !mounted) return;
    setState(() {
      _draft = UsageTypeNotesSync.applyUsageTypeChange(_draft, selected);
    });
  }

  Future<void> _editCrop() async {
    final result = await pickCropType(context, selected: _draft.cropType);
    if (result == null || result.isClear || !mounted) return;
    setState(() => _draft = _draft.copyWith(cropType: result.value));
  }

  Future<void> _enableDelegate() async {
    final String? ownerName = await showDelegateOwnerDialog(
      context,
      holderName: _draft.holderName ?? '',
      initialOwnerName: _draft.ownerName,
    );
    if (ownerName == null || !mounted) return;
    final String note = 'holdings.delegate.auto_note'.tr(
      namedArgs: {'holder': _draft.holderName ?? ''},
    );
    setState(() {
      _draft = DelegateNotesPolicy.enable(
        _draft,
        ownerName: ownerName,
        delegateNote: note,
      );
    });
  }

  void _disableDelegate() {
    _draft = DelegateNotesPolicy.disable(_draft);
  }

  Future<void> _editOwner() async {
    final String? ownerName = await showDelegateOwnerDialog(
      context,
      holderName: _draft.holderName ?? '',
      initialOwnerName: _draft.ownerName,
    );
    if (ownerName == null || !mounted) return;
    final String note = 'holdings.delegate.auto_note'.tr(
      namedArgs: {'holder': _draft.holderName ?? ''},
    );
    setState(() {
      _draft = DelegateNotesPolicy.enable(
        _draft,
        ownerName: ownerName,
        delegateNote: note,
      );
    });
  }

  String _areaText() {
    final String feddan = _draft.feddan?.toStringAsFixed(0) ?? '0';
    final String qirat = _draft.qirat?.toStringAsFixed(0) ?? '0';
    final String sahm = _draft.sahm?.toStringAsFixed(0) ?? '0';
    return '$feddan فدان، $qirat قيراط، $sahm سهم';
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final bool isAgricultural =
        UsageType.fromLabel(_draft.usageType) == UsageType.agricultural;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: rh(600)),
        padding: EdgeInsets.fromLTRB(
          rw(20),
          rh(16),
          rw(20),
          rh(20) + MediaQuery.of(context).viewInsets.bottom,
        ),
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
                const Icon(Icons.tune_rounded, color: AppColors.primary200),
                horizontalSpacing(8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'jazla.quick_view.title'.tr(),
                        style: AppTextStyles.font18Bold
                            .copyWith(color: colors.textPrimary),
                      ),
                      Text(
                        widget.original.holderName?.trim().isNotEmpty == true
                            ? widget.original.holderName!.trim()
                            : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.font12Regular
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: Icon(Icons.close_rounded, color: colors.iconSecondary),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            verticalSpacing(12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldRow(
                      label: 'holdings.fields.holding_id'.tr(),
                      value: _draft.holdingId,
                    ),
                    verticalSpacing(8),
                    FieldRow(
                      label: 'holdings.fields.basin_name'.tr(),
                      value: _draft.basinName ?? '—',
                    ),
                    verticalSpacing(12),
                    FieldRow(
                      label: 'holdings.fields.area'.tr(),
                      value: _areaText(),
                      onTap: _editArea,
                      showEditAction: false,
                    ),
                    verticalSpacing(8),
                    FieldRow(
                      label: 'holdings.fields.usage_type'.tr(),
                      value: _draft.usageType,
                      onTap: _editUsage,
                      showEditAction: false,
                    ),
                    if (isAgricultural) ...[
                      verticalSpacing(8),
                      FieldRow(
                        label: 'holdings.fields.crop_type'.tr(),
                        value: _draft.cropType ?? '—',
                        onTap: _editCrop,
                        showEditAction: false,
                      ),
                    ],
                    verticalSpacing(12),
                    Row(
                      children: [
                        Expanded(
                          child: ToggleFieldRow(
                            label: 'jazla.quick_view.inheritance'.tr(),
                            value: _draft.isInheritance,
                            onChanged: (final bool value) => setState(() {
                              _draft = _draft.copyWith(isInheritance: value);
                            }),
                          ),
                        ),
                        horizontalSpacing(8),
                        Expanded(
                          child: ToggleFieldRow(
                            label: 'jazla.quick_view.delegate'.tr(),
                            value: _draft.isDelegate,
                            onChanged: (final bool value) => value
                                ? _enableDelegate()
                                : setState(_disableDelegate),
                          ),
                        ),
                      ],
                    ),
                    if (_draft.isDelegate) ...[
                      verticalSpacing(8),
                      FieldRow(
                        label: 'holdings.fields.owner_name'.tr(),
                        value: _draft.ownerName ?? '—',
                        onTap: _editOwner,
                        showEditAction: false,
                      ),
                    ],
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
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
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
