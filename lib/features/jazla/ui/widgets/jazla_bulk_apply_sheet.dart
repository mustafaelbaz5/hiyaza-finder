import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/errors/error_message_resolver.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../crop_type/ui/widgets/crop_type_picker.dart';
import '../../../holdings/data/model/bulk_edit_outcome.dart';
import '../../../holdings/data/model/bulk_editable_field.dart';
import '../../../holdings/data/model/parcel.dart';
import '../../../holdings/data/repo/holdings_writer.dart';
import '../../../holdings/ui/file_status_screen.dart' show bulkEditableFieldLabel;
import '../../../holdings/ui/widgets/picker_row.dart';

/// تطبيق جماعي on one Jazla's own parcels — reuses the exact same
/// `HoldingsWriter.bulkApplyField`/`BulkEditService` this app already uses
/// for City Tools' bulk edit (no new bulk-write logic), scoped via
/// `parcelIds` to just this Jazla instead of a basin/city-wide scope. Only
/// fields meaningful across arbitrary parcels are offered — نوع الاستخدام
/// isn't included since (per `BulkEditableField`) it isn't part of this
/// picker set to begin with.
///
/// Doesn't need [jazlaId] itself — the write is scoped by [parcels]' own
/// ids, not by re-deriving them from the Jazla — but takes it for a
/// consistent call-site shape with the other Jazla sheet launchers.
Future<void> showJazlaBulkApplySheet(
  final BuildContext context, {
  required final String jazlaId,
  required final List<Parcel> parcels,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => JazlaBulkApplySheet(parcels: parcels),
  );
}

class JazlaBulkApplySheet extends StatefulWidget {
  const JazlaBulkApplySheet({super.key, required this.parcels});

  final List<Parcel> parcels;

  @override
  State<JazlaBulkApplySheet> createState() => _JazlaBulkApplySheetState();
}

class _JazlaBulkApplySheetState extends State<JazlaBulkApplySheet> {
  /// Fields that make sense to apply across an arbitrary set of parcels —
  /// excludes نوع الائتمان/نوع الإصلاح (association-type-specific) the same
  /// way `FileStatusScreen._pickBulkField` conditionally hides them, but
  /// simplified here to just the fields relevant regardless of city type.
  static const List<BulkEditableField> _applicableFields = <BulkEditableField>[
    BulkEditableField.cropType,
    BulkEditableField.growthStages,
    BulkEditableField.usageType,
    BulkEditableField.notes,
    BulkEditableField.isInheritance,
  ];

  BulkEditableField _field = BulkEditableField.cropType;
  Object? _value;
  bool _isApplying = false;
  double _progress = 0;

  Future<void> _pickField() async {
    final ChoiceDialogResult<BulkEditableField>? result =
        await showChoiceDialog<BulkEditableField>(
      context,
      title: 'jazla.bulk_apply.field_label'.tr(),
      options: [
        for (final BulkEditableField f in _applicableFields)
          ChoiceOption<BulkEditableField>(value: f, label: bulkEditableFieldLabel(f)),
      ],
      selected: _field,
    );
    if (result == null || result.isClear) return;
    setState(() {
      _field = result.value!;
      _value = null;
    });
  }

  Future<void> _pickValue() async {
    if (_field.isBoolean) {
      final ChoiceDialogResult<bool>? result = await showChoiceDialog<bool>(
        context,
        title: bulkEditableFieldLabel(_field),
        options: [
          ChoiceOption<bool>(value: true, label: 'holdings.bulk_edit.inheritance_true'.tr()),
          ChoiceOption<bool>(value: false, label: 'holdings.bulk_edit.inheritance_false'.tr()),
        ],
        selected: _value as bool?,
      );
      if (result == null || result.isClear) return;
      setState(() => _value = result.value);
      return;
    }

    if (_field == BulkEditableField.cropType) {
      final ChoiceDialogResult<String>? result = await pickCropType(
        context,
        selected: _value as String?,
      );
      if (result == null) return;
      setState(() => _value = result.isClear ? null : result.value);
      return;
    }

    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: bulkEditableFieldLabel(_field),
      options: [
        for (final String o in _field.textOptions) ChoiceOption<String>(value: o, label: o),
      ],
      selected: _value as String?,
      clearLabel:
          _field.allowClear ? 'holdings.bulk_edit.value_placeholder'.tr() : null,
    );
    if (result == null) return;
    setState(() => _value = result.isClear ? null : result.value);
  }

  String _valueLabel(final Object? value) {
    if (value == null) return 'holdings.bulk_edit.value_placeholder'.tr();
    if (value is bool) {
      return value
          ? 'holdings.bulk_edit.inheritance_true'.tr()
          : 'holdings.bulk_edit.inheritance_false'.tr();
    }
    return value as String;
  }

  Future<void> _apply() async {
    setState(() {
      _isApplying = true;
      _progress = 0;
    });
    try {
      final Set<String> parcelIds = widget.parcels.map((final Parcel p) => p.id).toSet();
      final BulkEditOutcome outcome = await getIt<HoldingsWriter>().bulkApplyField(
        field: _field,
        value: _value,
        parcelIds: parcelIds,
        onProgress: (final double progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _isApplying = false);
      if (outcome.failed == 0) {
        context.showSuccessSnackBar(
          'jazla.bulk_apply.applied_message'.tr(
            namedArgs: {'count': outcome.succeeded.toString()},
          ),
        );
        Navigator.pop(context);
      } else if (outcome.succeeded == 0) {
        context.showErrorSnackBar(
          'jazla.bulk_apply.applied_failed_message'.tr(
            namedArgs: {'failed': outcome.failed.toString()},
          ),
        );
      } else {
        context.showErrorSnackBar(
          'jazla.bulk_apply.applied_partial_message'.tr(
            namedArgs: {
              'succeeded': outcome.succeeded.toString(),
              'failed': outcome.failed.toString(),
            },
          ),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      context.showErrorSnackBar(
        resolveWriteErrorMessage(error, fallback: 'errors.unknown'.tr()),
      );
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'jazla.detail.bulk_apply'.tr(),
                        style: AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
                        textAlign: TextAlign.right,
                      ),
                      Text(
                        'jazla.bulk_apply.parcel_count'
                            .tr(namedArgs: {'count': widget.parcels.length.toString()}),
                        style: AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.iconSecondary),
                  onPressed: _isApplying ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            verticalSpacing(16),
            PickerRow(
              label: 'jazla.bulk_apply.field_label'.tr(),
              value: bulkEditableFieldLabel(_field),
              onTap: _isApplying ? () {} : _pickField,
            ),
            verticalSpacing(8),
            PickerRow(
              label: 'jazla.bulk_apply.value_label'.tr(),
              value: _valueLabel(_value),
              onTap: _isApplying ? () {} : _pickValue,
            ),
            if (_isApplying) ...[
              verticalSpacing(12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 6,
                ),
              ),
            ],
            verticalSpacing(16),
            Row(
              children: [
                Expanded(
                  child: CustomTextButton.outlined(
                    text: 'jazla.bulk_apply.cancel'.tr(),
                    onPressed: _isApplying ? null : () => Navigator.pop(context),
                  ),
                ),
                horizontalSpacing(8),
                Expanded(
                  child: CustomTextButton(
                    text: 'jazla.bulk_apply.apply'.tr(),
                    isLoading: _isApplying,
                    onPressed:
                        (_isApplying || widget.parcels.isEmpty) ? null : _apply,
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
