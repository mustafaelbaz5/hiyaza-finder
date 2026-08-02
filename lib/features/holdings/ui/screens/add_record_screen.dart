import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../data/repository/holdings_repository.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/services/field_change_tracker.dart';
import '../../logic/services/area_calculator.dart';
import '../widgets/crop_type_picker.dart';
import '../widgets/field_edit_dialogs.dart';
import '../widgets/field_row.dart';
import '../widgets/responsive_fields_wrap.dart';
import '../widgets/toggle_field_row.dart';

/// Navigation arguments for the add-record route.
class AddRecordArgs {
  const AddRecordArgs({required this.initialParcel, this.parentHoldingId});

  final Parcel initialParcel;
  final String? parentHoldingId;
}

/// Shared form for both add flows (APP_PLAN.md § 7.4/7.5):
/// - "Add new person": [initialParcel] is a blank [Parcel] ([Parcel]'s own
///   constructor defaults), [parentHoldingId] is `null`.
/// - "Add parcel for existing person": [initialParcel] is pre-filled from
///   that person's most recent parcel per decision #8 (everything copied
///   except المساحة, blanked, and رقم الأرض, defaulted to `-1` — the
///   caller is responsible for producing that shape), [parentHoldingId]
///   is that person's `Parcel.id`.
///
/// Reuses the exact same field-edit dialogs the detail card uses
/// (`showTextInputDialog`, `showChoiceDialog`, `pickCropType`,
/// `showAreaFieldEditDialog`) so the editing UX is identical, just against
/// a record that doesn't exist on the server yet instead of one being
/// corrected.
class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({
    super.key,
    required this.initialParcel,
    this.parentHoldingId,
  });

  final Parcel initialParcel;
  final String? parentHoldingId;

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  late Parcel _parcel;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _parcel = widget.initialParcel;
  }

  bool get _canSave => (_parcel.holderName?.trim().isNotEmpty ?? false);

  /// Whether the field read via [current] from `_parcel` differs from
  /// `widget.initialParcel`'s value for the same field — drives every
  /// `FieldRow`/`ToggleFieldRow`'s modified-indicator below. One generic
  /// comparison instead of duplicating `!=` at each field.
  bool _isModified<T>(final T Function(Parcel p) current) =>
      FieldChangeTracker.isModified(
        current(_parcel),
        current(widget.initialParcel),
      );

  /// Owner name defaults to holder name when left blank — most parcels
  /// have the same person as both, so this avoids making the user type
  /// the same name twice. Association name is auto-populated from the city
  /// data for consistency.
  Parcel get _parcelToSave {
    final HoldingsRepository repo = getIt<HoldingsRepository>();
    final String? defaultAssociation = repo.defaultAssociationName;

    Parcel result = _parcel;
    if ((_parcel.ownerName?.trim().isEmpty ?? true)) {
      result = result.copyWith(ownerName: _parcel.holderName);
    }
    if ((result.associationName?.trim().isEmpty ?? true) &&
        defaultAssociation != null) {
      result = result.copyWith(associationName: defaultAssociation);
    }
    return result;
  }

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final Parcel? saved = await getIt<HoldingsRepository>().addLocalParcel(
        _parcelToSave,
        parentHoldingId: widget.parentHoldingId,
      );
      if (!mounted) return;
      if (saved == null) {
        context.showErrorSnackBar('holdings.add.no_active_city'.tr());
        setState(() => _isSaving = false);
        return;
      }
      context.showSuccessSnackBar('holdings.add.saved'.tr());
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar('errors.unknown'.tr());
      setState(() => _isSaving = false);
    }
  }

  bool get _hasUnsavedChanges => !identical(_parcel, widget.initialParcel);

  Future<void> _confirmDiscardAndPop(final BuildContext context) async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    await AppDialogs.showConfirm(
      context,
      message: 'holdings.add.discard_confirm'.tr(),
      onConfirm: () => Navigator.pop(context),
    );
  }

  Future<void> _editText(
    final BuildContext context, {
    required final String title,
    required final String initialValue,
    required final Parcel Function(String value) apply,
    final TextInputType? keyboardType,
  }) async {
    final String? value = await showTextInputDialog(
      context,
      title: title,
      initialValue: initialValue,
      keyboardType: keyboardType,
    );
    if (value == null) return;
    setState(() => _parcel = apply(value));
  }

  Future<void> _editDropdown(
    final BuildContext context, {
    required final String title,
    required final String? initialValue,
    required final List<String> options,
    required final Parcel Function(String? value) apply,
    final bool allowClear = true,
  }) async {
    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: title,
      options: [
        for (final String option in options)
          ChoiceOption<String>(value: option, label: option),
      ],
      selected: initialValue,
      clearLabel: allowClear ? '—' : null,
    );
    if (result == null) return;
    setState(() => _parcel = apply(result.isClear ? null : result.value));
  }

  Future<void> _editCropType(final BuildContext context) async {
    final ChoiceDialogResult<String>? result = await pickCropType(
      context,
      selected: _parcel.cropType,
    );
    if (result == null) return;
    setState(
      () => _parcel = _parcel.copyWith(
        cropType: result.isClear ? null : result.value,
      ),
    );
  }

  Future<void> _editArea(final BuildContext context) async {
    final AreaEditResult? result = await showAreaFieldEditDialog(
      context,
      feddan: _parcel.feddan,
      qirat: _parcel.qirat,
      sahm: _parcel.sahm,
    );
    if (result == null) return;
    setState(
      () => _parcel = _parcel.copyWith(
        feddan: result.feddan,
        qirat: result.qirat,
        sahm: result.sahm,
        totalSqm: AreaCalculator.totalSqm(
          feddan: result.feddan,
          qirat: result.qirat,
          sahm: result.sahm,
        ),
      ),
    );
  }

  Future<void> _editBasin(final BuildContext context) async {
    final List<String> basins = getIt<HoldingsRepository>().availableBasins;
    if (basins.isEmpty) {
      await _editText(
        context,
        title: 'اسم الحوض',
        initialValue: _parcel.basinName ?? '',
        apply: (final String v) => _parcel.copyWith(
          basinName: v.isEmpty ? null : v,
        ),
      );
      return;
    }

    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: 'اسم الحوض',
      options: [
        for (final String basin in basins)
          ChoiceOption<String>(value: basin, label: basin),
      ],
      selected: _parcel.basinName,
      clearLabel: '—',
    );
    if (result == null) return;
    setState(
      () => _parcel = _parcel.copyWith(
        basinName: result.isClear ? null : result.value,
      ),
    );
  }

  String _areaFraction(final Parcel p) {
    String fmt(final double? v) {
      if (v == null) return FieldRow.emptyPlaceholder;
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }

    return '${fmt(p.feddan)} فدان، ${fmt(p.qirat)} قيراط، ${fmt(p.sahm)} سهم';
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final bool hideCreditType = getIt<HoldingsRepository>().hideCreditType;
    final String title = widget.parentHoldingId == null
        ? 'holdings.add.new_person_title'.tr()
        : 'holdings.add.new_parcel_title'.tr();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (final bool didPop, final _) {
        if (didPop) return;
        _confirmDiscardAndPop(context);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              verticalSpacing(16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: rw(16)),
                child: Row(
                  children: [
                    AppBackButton(
                      onTap: () => _confirmDiscardAndPop(context),
                    ),
                    horizontalSpacing(12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.font20Bold.copyWith(
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.parentHoldingId != null) ...[
                verticalSpacing(12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: rw(16)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blue200.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'holdings.add.for_person'.tr(
                        namedArgs: {
                          'name': widget.initialParcel.holderName ?? '',
                        },
                      ),
                      style: AppTextStyles.font12Bold.copyWith(
                        color: AppColors.blue200,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
              verticalSpacing(16),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: rw(16)).copyWith(
                    bottom: rh(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ResponsiveFieldsWrap(
                        children: [
                          FieldRow(
                            label: 'رقم الحيازة',
                            value: _parcel.holdingId,
                            isModified: _isModified((final p) => p.holdingId),
                            onEdit: () => _editText(
                              context,
                              title: 'رقم الحيازة',
                              initialValue: _parcel.holdingId,
                              apply: (final String v) => _parcel.copyWith(
                                holdingId: v.isEmpty ? '-1' : v,
                              ),
                            ),
                          ),
                          if (_parcel.holdingsCount != null)
                            FieldRow(
                              label: 'holdings.detail.holdings_count'.tr(),
                              value: _parcel.holdingsCount.toString(),
                            ),
                          FieldRow(
                            label: 'اسم الحائز *',
                            value: _parcel.holderName,
                            isModified: _isModified((final p) => p.holderName),
                            onEdit: () => _editText(
                              context,
                              title: 'اسم الحائز',
                              initialValue: _parcel.holderName ?? '',
                              apply: (final String v) => _parcel.copyWith(
                                holderName: v.isEmpty ? null : v,
                              ),
                            ),
                          ),
                          FieldRow(
                            label: 'اسم المالك',
                            value: _parcel.ownerName,
                            isModified: _isModified((final p) => p.ownerName),
                            onEdit: () => _editText(
                              context,
                              title: 'اسم المالك',
                              initialValue: _parcel.ownerName ?? '',
                              apply: (final String v) => _parcel.copyWith(
                                ownerName: v.isEmpty ? null : v,
                              ),
                            ),
                          ),
                          FieldRow(
                            label: 'الرقم القومي',
                            value: _parcel.nationalId,
                            isModified: _isModified((final p) => p.nationalId),
                            onEdit: () => _editText(
                              context,
                              title: 'الرقم القومي',
                              initialValue: _parcel.nationalId ?? '',
                              keyboardType: TextInputType.number,
                              apply: (final String v) => _parcel.copyWith(
                                nationalId: v.isEmpty ? null : v,
                              ),
                            ),
                          ),
                          FieldRow(
                            label: 'اسم الحوض',
                            value: _parcel.basinName,
                            isModified: _isModified((final p) => p.basinName),
                            onEdit: () => _editBasin(context),
                          ),
                          FieldRow(
                            label: 'رقم الأرض',
                            value: _parcel.landNumber,
                            isModified: _isModified((final p) => p.landNumber),
                            onEdit: () => _editText(
                              context,
                              title: 'رقم الأرض',
                              initialValue: _parcel.landNumber ?? '',
                              apply: (final String v) => _parcel.copyWith(
                                landNumber: v.isEmpty ? null : v,
                              ),
                            ),
                          ),
                          if (widget.parentHoldingId != null &&
                              _parcel.landNumber == '-1')
                            Padding(
                              padding: EdgeInsets.only(top: rh(4)),
                              child: Text(
                                'holdings.add.land_number_hint'.tr(),
                                style: AppTextStyles.font12Regular.copyWith(
                                  color: AppColors.amber300,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          FieldRow(
                            label: 'المساحة',
                            value: _areaFraction(_parcel),
                            isModified: _isModified((final p) => p.feddan) ||
                                _isModified((final p) => p.qirat) ||
                                _isModified((final p) => p.sahm),
                            onEdit: () => _editArea(context),
                          ),
                          FieldRow(
                            label: 'نوع الزرع',
                            value: _parcel.cropType,
                            isModified: _isModified((final p) => p.cropType),
                            onEdit: () => _editCropType(context),
                          ),
                          FieldRow(
                            label: 'ملاحظات',
                            value: _parcel.notes,
                            isModified: _isModified((final p) => p.notes),
                            onEdit: () => _editDropdown(
                              context,
                              title: 'ملاحظات',
                              initialValue: _parcel.notes,
                              options: Parcel.notesOptions,
                              apply: (final String? v) =>
                                  _parcel.copyWith(notes: v),
                            ),
                          ),
                          if (!hideCreditType)
                            FieldRow(
                              label: 'نوع الائتمان',
                              value: _parcel.creditType,
                              isModified: _isModified((final p) => p.creditType),
                              onEdit: () => _editDropdown(
                                context,
                                title: 'نوع الائتمان',
                                initialValue: _parcel.creditType,
                                options: Parcel.creditTypeOptions,
                                allowClear: false,
                                apply: (final String? v) => _parcel.copyWith(
                                  creditType: v ?? Parcel.defaultCreditType,
                                ),
                              ),
                            ),
                          FieldRow(
                            label: 'نوع الاستخدام',
                            value: _parcel.usageType,
                            isModified: _isModified((final p) => p.usageType),
                            onEdit: () => _editDropdown(
                              context,
                              title: 'نوع الاستخدام',
                              initialValue: _parcel.usageType,
                              options: Parcel.usageTypeOptions,
                              allowClear: false,
                              apply: (final String? v) => _parcel.copyWith(
                                usageType: v ?? Parcel.defaultUsageType,
                              ),
                            ),
                          ),
                          ToggleFieldRow(
                            label: 'وراثة',
                            value: _parcel.isInheritance,
                            isModified: _isModified((final p) => p.isInheritance),
                            onChanged: (final bool v) => setState(
                              () =>
                                  _parcel = _parcel.copyWith(isInheritance: v),
                            ),
                          ),
                          ToggleFieldRow(
                            label: 'مفوض',
                            value: _parcel.isDelegate,
                            isModified: _isModified((final p) => p.isDelegate),
                            onChanged: (final bool v) => setState(
                              () => _parcel = _parcel.copyWith(isDelegate: v),
                            ),
                          ),
                        ],
                      ),
                      verticalSpacing(24),
                      CustomTextButton(
                        text: 'holdings.add.save'.tr(),
                        onPressed: _canSave ? _save : null,
                        isLoading: _isSaving,
                        size: CustomButtonSize.large,
                      ),
                      if (!_canSave) ...[
                        verticalSpacing(8),
                        Text(
                          'holdings.add.holder_required'.tr(),
                          style: AppTextStyles.font12Regular.copyWith(
                            color: colors.textHint,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
