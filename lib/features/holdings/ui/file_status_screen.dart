import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/errors/error_message_resolver.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/custom_text_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../crop_type/ui/widgets/crop_type_picker.dart';
import '../data/model/bulk_edit_outcome.dart';
import '../data/model/bulk_editable_field.dart';
import '../data/model/parcel.dart';
import '../data/repo/holdings_repository.dart';
import 'widgets/picker_row.dart';
import 'widgets/section_card.dart';
import 'widgets/specify_other_picker.dart';

/// Localized display label for a [BulkEditableField] — kept here (UI layer)
/// rather than as a `.label` getter on the enum itself, since
/// `BulkEditableField` lives in `domain/entities/` (pure Dart, no Flutter/
/// easy_localization dependency allowed per CLAUDE.md's layering rule).
String bulkEditableFieldLabel(final BulkEditableField field) => switch (field) {
      BulkEditableField.cropType => 'holdings.fields.crop_type'.tr(),
      BulkEditableField.notes => 'holdings.fields.notes'.tr(),
      BulkEditableField.creditType => 'holdings.fields.credit_type'.tr(),
      BulkEditableField.reformType => 'holdings.fields.reform_type'.tr(),
      BulkEditableField.usageType => 'holdings.fields.usage_type'.tr(),
      BulkEditableField.isInheritance => 'holdings.fields.inheritance'.tr(),
      BulkEditableField.growthStages => 'holdings.fields.growth_stages'.tr(),
    };

/// Overview of the active city's data — holding counts per حوض — plus a
/// bulk edit tool applying one of the app-added fields (نوع الزرع،
/// ملاحظات، …) to every parcel in one حوض (or the whole city) at once.
class FileStatusScreen extends StatefulWidget {
  const FileStatusScreen({super.key});

  @override
  State<FileStatusScreen> createState() => _FileStatusScreenState();
}

class _FileStatusScreenState extends State<FileStatusScreen> {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();

  String? _bulkBasin; // null = whole city
  BulkEditableField _bulkField = BulkEditableField.cropType;
  Object? _bulkValue;
  bool _isApplying = false;
  double _applyProgress = 0;

  Future<void> _pickBulkBasin() async {
    final List<String> basins = _repository.availableBasins;
    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: 'holdings.bulk_edit.pick_basin_title'.tr(),
      options: [
        for (final String b in basins) ChoiceOption<String>(value: b, label: b),
      ],
      selected: _bulkBasin,
      clearLabel: 'holdings.bulk_edit.scope_all'.tr(),
    );
    if (result == null) return;
    setState(() {
      _bulkBasin = result.isClear ? null : result.value;
    });
  }

  Future<void> _pickBulkField() async {
    final List<BulkEditableField> selectableFields = <BulkEditableField>[
      for (final BulkEditableField f in BulkEditableField.values)
        if ((f != BulkEditableField.creditType ||
                !_repository.hideCreditType) &&
            (f != BulkEditableField.reformType || _repository.hideCreditType))
          f,
    ];
    final ChoiceDialogResult<BulkEditableField>? result =
        await showChoiceDialog<BulkEditableField>(
      context,
      title: 'holdings.bulk_edit.pick_field_title'.tr(),
      options: [
        for (final BulkEditableField f in selectableFields)
          ChoiceOption<BulkEditableField>(
              value: f, label: bulkEditableFieldLabel(f)),
      ],
      selected: _bulkField,
    );
    if (result == null || result.isClear) return;
    setState(() {
      _bulkField = result.value!;
      _bulkValue = null;
    });
  }

  Future<void> _pickBulkValue() async {
    if (_bulkField.isBoolean) {
      final ChoiceDialogResult<bool>? result = await showChoiceDialog<bool>(
        context,
        title: bulkEditableFieldLabel(_bulkField),
        options: [
          ChoiceOption<bool>(
            value: true,
            label: 'holdings.bulk_edit.inheritance_true'.tr(),
          ),
          ChoiceOption<bool>(
            value: false,
            label: 'holdings.bulk_edit.inheritance_false'.tr(),
          ),
        ],
        selected: _bulkValue as bool?,
      );
      if (result == null || result.isClear) return;
      setState(() => _bulkValue = result.value);
      return;
    }

    if (_bulkField == BulkEditableField.cropType) {
      final ChoiceDialogResult<String>? result = await pickCropType(
        context,
        selected: _bulkValue as String?,
      );
      if (result == null) return;
      setState(() => _bulkValue = result.isClear ? null : result.value);
      return;
    }

    if (_bulkField == BulkEditableField.notes) {
      final ChoiceDialogResult<String>? result = await pickWithOther(
        context,
        title: bulkEditableFieldLabel(_bulkField),
        selected: _bulkValue as String?,
        options: Parcel.notesOptions,
        otherOption: Parcel.notesOtherOption,
        specifyTitle: 'holdings.notes_field.specify_title'.tr(),
        clearLabel: 'holdings.bulk_edit.value_placeholder'.tr(),
      );
      if (result == null) return;
      setState(() => _bulkValue = result.isClear ? null : result.value);
      return;
    }

    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: bulkEditableFieldLabel(_bulkField),
      options: [
        for (final String o in _bulkField.textOptions)
          ChoiceOption<String>(value: o, label: o),
      ],
      selected: _bulkValue as String?,
      clearLabel: _bulkField.allowClear
          ? 'holdings.bulk_edit.value_placeholder'.tr()
          : null,
    );
    if (result == null) return;
    setState(() => _bulkValue = result.isClear ? null : result.value);
  }

  Future<void> _confirmAndApplyBulkEdit() async {
    final String scope = _bulkBasin ?? 'holdings.bulk_edit.scope_all'.tr();
    await AppDialogs.showConfirm(
      context,
      message: 'holdings.bulk_edit.confirm_message'.tr(
        namedArgs: {
          'field': bulkEditableFieldLabel(_bulkField),
          'value': _valueLabel(_bulkValue),
          'scope': scope,
        },
      ),
      onConfirm: _applyBulkEdit,
    );
  }

  Future<void> _applyBulkEdit() async {
    setState(() {
      _isApplying = true;
      _applyProgress = 0;
    });
    try {
      final BulkEditOutcome outcome = await _repository.bulkApplyField(
        field: _bulkField,
        value: _bulkValue,
        basin: _bulkBasin,
        onProgress: (final double progress) {
          if (mounted) setState(() => _applyProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _isApplying = false);
      if (outcome.failed == 0) {
        context.showSuccessSnackBar(
          'holdings.bulk_edit.applied_message'.tr(
            namedArgs: {'count': outcome.succeeded.toString()},
          ),
        );
      } else if (outcome.succeeded == 0) {
        context.showErrorSnackBar(
          'holdings.bulk_edit.applied_failed_message'.tr(
            namedArgs: {'failed': outcome.failed.toString()},
          ),
        );
      } else {
        context.showErrorSnackBar(
          'holdings.bulk_edit.applied_partial_message'.tr(
            namedArgs: {
              'succeeded': outcome.succeeded.toString(),
              'failed': outcome.failed.toString(),
            },
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      context.showErrorSnackBar(
        resolveWriteErrorMessage(error, fallback: 'errors.unknown'.tr()),
      );
    }
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

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(title: 'holdings.bulk_edit.title'.tr()),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: rw(16)).copyWith(
                  bottom: rh(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bulk Edit is first (`REFACTOR_ROADMAP.md` Phase 11 §1)
                    // — the primary reason a field worker opens City Tools.
                    SectionCard(
                      title: 'holdings.bulk_edit.section_title'.tr(),
                      subtitle: 'holdings.bulk_edit.section_subtitle'.tr(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PickerRow(
                            label: 'holdings.bulk_edit.scope_label'.tr(),
                            value: _bulkBasin ??
                                'holdings.bulk_edit.scope_all'.tr(),
                            onTap: _pickBulkBasin,
                          ),
                          verticalSpacing(8),
                          PickerRow(
                            label: 'holdings.bulk_edit.field_label'.tr(),
                            value: bulkEditableFieldLabel(_bulkField),
                            onTap: _pickBulkField,
                          ),
                          verticalSpacing(8),
                          PickerRow(
                            label: 'holdings.bulk_edit.value_label'.tr(),
                            value: _valueLabel(_bulkValue),
                            onTap: _pickBulkValue,
                          ),
                          if (_isApplying) ...[
                            verticalSpacing(12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value:
                                    _applyProgress == 0 ? null : _applyProgress,
                                minHeight: 6,
                              ),
                            ),
                          ],
                          verticalSpacing(16),
                          CustomTextButton(
                            text: 'holdings.bulk_edit.apply'.tr(),
                            onPressed:
                                _isApplying ? null : _confirmAndApplyBulkEdit,
                            isLoading: _isApplying,
                            prefixIcon: const Icon(
                              Icons.done_all_rounded,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
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
