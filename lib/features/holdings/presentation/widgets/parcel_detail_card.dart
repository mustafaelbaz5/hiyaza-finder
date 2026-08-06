import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/responsive_fields_wrap.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/see_more_section.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../../cities/domain/entities/association_type.dart';
import '../../data/repository/holdings_repository.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/services/clipboard_formatter.dart';
import '../../domain/services/field_change_tracker.dart';
import '../../domain/services/area_calculator.dart';
import 'border_compass.dart';
import 'copy_all_button.dart';
import 'crop_type_picker.dart';
import 'field_edit_dialogs.dart';
import 'field_row.dart';
import 'parcel_detail_header.dart';
import 'required_field_gaps.dart';

class ParcelDetailCard extends StatelessWidget {
  const ParcelDetailCard({
    super.key,
    required this.parcel,
    required this.onFieldChanged,
    this.originalParcel,
    this.isNew = false,
    this.hideCreditType = false,
    this.associationType,
    this.animationDelay = Duration.zero,
    this.resolveBorderMatch,
    this.onDelete,
    this.onFinish,
    this.onReopen,
  });

  final Parcel parcel;
  final void Function(Parcel updated) onFieldChanged;
  final Parcel? originalParcel;
  final bool isNew;
  final VoidCallback? onDelete;
  final bool hideCreditType;
  final AssociationType? associationType;
  final Duration animationDelay;
  final Parcel? Function(String? borderText)? resolveBorderMatch;
  final VoidCallback? onFinish;
  final VoidCallback? onReopen;

  static const ClipboardFormatter _formatter = ClipboardFormatter();

  bool _isModified<T>(final T Function(Parcel p) current) {
    final Parcel? original = originalParcel;
    if (original == null) return false;
    return FieldChangeTracker.isModified(current(parcel), current(original));
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final bool isAdded =
        parcel.isFieldAdded || parcel.sourceAddedHoldingId != null || isNew;
    final bool isCompleted = parcel.completedAt != null;
    return Container(
      padding: EdgeInsets.all(rw(12)),
      decoration: BoxDecoration(
        color: isCompleted
            ? colors.surface.withValues(alpha: 0.76)
            : colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? AppColors.green200.withValues(alpha: 0.28)
              : isAdded
                  ? AppColors.blue200.withValues(alpha: 0.35)
                  : colors.border,
          width: isAdded || isCompleted ? 1.2 : 1,
        ),
        boxShadow: <BoxShadow>[
          if (isCompleted)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Opacity(
        opacity: isCompleted ? 0.68 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ParcelDetailTopRow(
              isAdded: isAdded,
              isReviewed: isCompleted,
              onFinish: onFinish,
              onReopen: onReopen,
              onDelete: onDelete,
              onDeleteConfirmed: () => _confirmDelete(context),
              isInheritance: parcel.isInheritance,
              isDelegate: parcel.isDelegate,
            ),
            if (isAdded || isCompleted) verticalSpacing(8),
            if (isAdded)
              ParcelDetailInfoBanner(
                icon: Icons.add_box_rounded,
                label: 'holdings.detail.added_badge'.tr(),
                subtitle: 'holdings.detail.added_badge_hint'.tr(),
                color: AppColors.blue200,
              ),
            if (isAdded && isCompleted) verticalSpacing(8),
            if (isCompleted)
              ParcelDetailInfoBanner(
                icon: Icons.check_circle_rounded,
                label: 'holdings.detail.reviewed_badge'.tr(),
                subtitle: 'holdings.detail.reviewed_hint'.tr(),
                color: colors.success,
              ),
            verticalSpacing(10),
            ParcelIdChip(id: parcel.id, onCopy: () => _copyId(context)),
            verticalSpacing(10),
            BorderCompass(
              holdingId: parcel.holdingId,
              north: parcel.borderNorth,
              south: parcel.borderSouth,
              east: parcel.borderEast,
              west: parcel.borderWest,
              onTapBorder: resolveBorderMatch == null
                  ? null
                  : (final String? borderText) =>
                      _openBorderPerson(context, borderText),
              isBorderNavigable: resolveBorderMatch == null
                  ? null
                  : (final String? borderText) =>
                      resolveBorderMatch!(borderText) != null,
            ),
            verticalSpacing(10),
            CopyAllButton(onTap: () => _copyAll(context)),
            verticalSpacing(12),
            verticalSpacing(8),
            ResponsiveFieldsWrap(
              children: [
                FieldRow(
                  label: 'holdings.detail.holding_id'.tr(),
                  value: parcel.isHoldingIdPending
                      ? 'holdings.detail.holding_id_pending'.tr()
                      : parcel.holdingId,
                  isModified: _isModified((final p) => p.holdingId),
                  onEdit: () => _editText(
                    context,
                    title: 'holdings.detail.holding_id'.tr(),
                    initialValue:
                        parcel.isHoldingIdPending ? '' : parcel.holdingId,
                    apply: (final String v) => parcel.copyWith(holdingId: v),
                  ),
                ),
                if (parcel.holdingsCount != null)
                  FieldRow(
                    label: 'holdings.detail.holdings_count'.tr(),
                    value: parcel.holdingsCount.toString(),
                  ),
                FieldRow(
                  label: 'holdings.fields.owner_name'.tr(),
                  value: _formatter.effectiveOwnerName(parcel),
                  isModified: _isModified((final p) => p.ownerName),
                  onEdit: () => _editText(
                    context,
                    title: 'holdings.fields.owner_name'.tr(),
                    initialValue: _formatter.effectiveOwnerName(parcel) ?? '',
                    apply: (final String v) =>
                        parcel.copyWith(ownerName: v.isEmpty ? null : v),
                  ),
                ),
                FieldRow(
                  label: 'holdings.fields.holder_name'.tr(),
                  value: parcel.holderName,
                  isModified: _isModified((final p) => p.holderName),
                  onEdit: () => _editText(
                    context,
                    title: 'holdings.fields.holder_name'.tr(),
                    initialValue: parcel.holderName ?? '',
                    apply: (final String v) =>
                        parcel.copyWith(holderName: v.isEmpty ? null : v),
                  ),
                ),
                FieldRow(
                  label: 'holdings.fields.national_id'.tr(),
                  value: parcel.nationalId,
                  isModified: _isModified((final p) => p.nationalId),
                  onEdit: () => _editText(
                    context,
                    title: 'holdings.fields.national_id'.tr(),
                    initialValue: parcel.nationalId ?? '',
                    keyboardType: TextInputType.number,
                    apply: (final String v) =>
                        parcel.copyWith(nationalId: v.isEmpty ? null : v),
                  ),
                ),
                FieldRow(
                  label: 'holdings.fields.association_name'.tr(),
                  value: parcel.associationName,
                  isModified: _isModified((final p) => p.associationName),
                  onEdit: () => _editText(
                    context,
                    title: 'holdings.fields.association_name'.tr(),
                    initialValue: parcel.associationName ?? '',
                    apply: (final String v) =>
                        parcel.copyWith(associationName: v.isEmpty ? null : v),
                  ),
                ),
                FieldRow(
                  label: 'holdings.fields.basin_name'.tr(),
                  value: parcel.basinName,
                  isModified: _isModified((final p) => p.basinName),
                  onEdit: () => _editBasin(context),
                ),
                FieldRow(
                  label: 'holdings.fields.land_number'.tr(),
                  value: parcel.landNumber,
                  isModified: _isModified((final p) => p.landNumber),
                  onEdit: () => _editText(
                    context,
                    title: 'holdings.fields.land_number'.tr(),
                    initialValue: parcel.landNumber ?? '',
                    apply: (final String v) =>
                        parcel.copyWith(landNumber: v.isEmpty ? null : v),
                  ),
                ),
                FieldRow(
                  label: 'holdings.fields.area'.tr(),
                  value: _formatter.areaFraction(parcel),
                  isModified: _isModified((final p) => p.feddan) ||
                      _isModified((final p) => p.qirat) ||
                      _isModified((final p) => p.sahm),
                  onEdit: () => _editArea(context),
                ),
                FieldRow(
                  label: 'holdings.fields.area_sqm'.tr(),
                  value: _formatter.formatNumber(parcel.totalSqm),
                  isModified: _isModified((final p) => p.totalSqm),
                  onEdit: () => _editArea(context),
                ),
                FieldRow(
                  label: 'holdings.fields.crop_type'.tr(),
                  value: parcel.cropType,
                  isModified: _isModified((final p) => p.cropType),
                  onEdit: () => _editCropType(context),
                ),
                FieldRow(
                  label: 'holdings.fields.notes'.tr(),
                  value: parcel.notes,
                  isModified: _isModified((final p) => p.notes),
                  onEdit: () => _editDropdown(
                    context,
                    title: 'holdings.fields.notes'.tr(),
                    initialValue: parcel.notes,
                    options: Parcel.notesOptions,
                    apply: (final String? v) => parcel.copyWith(notes: v),
                  ),
                ),
              ],
            ),
            verticalSpacing(12),
            verticalSpacing(8),
            SeeMoreSection(
              parcel: parcel,
              onFieldChanged: onFieldChanged,
              originalParcel: originalParcel,
              hideCreditType: hideCreditType,
              associationType: associationType,
            ),
          ],
        ),
      ),
    )
        .animate(delay: animationDelay)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0);
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
    onFieldChanged(apply(value));
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
    onFieldChanged(apply(result.isClear ? null : result.value));
  }

  Future<void> _editCropType(final BuildContext context) async {
    final ChoiceDialogResult<String>? result = await pickCropType(
      context,
      selected: parcel.cropType,
    );
    if (result == null) return;
    onFieldChanged(
      parcel.copyWith(cropType: result.isClear ? null : result.value),
    );
  }

  Future<void> _editArea(final BuildContext context) async {
    final AreaEditResult? result = await showAreaFieldEditDialog(
      context,
      feddan: parcel.feddan,
      qirat: parcel.qirat,
      sahm: parcel.sahm,
    );
    if (result == null) return;
    onFieldChanged(
      parcel.copyWith(
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
        title: 'holdings.fields.basin_name'.tr(),
        initialValue: parcel.basinName ?? '',
        apply: (final String v) =>
            parcel.copyWith(basinName: v.isEmpty ? null : v),
      );
      return;
    }

    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: 'holdings.fields.basin_name'.tr(),
      options: [
        for (final String basin in basins)
          ChoiceOption<String>(value: basin, label: basin),
      ],
      selected: parcel.basinName,
      clearLabel: '—',
    );
    if (result == null) return;
    onFieldChanged(
      parcel.copyWith(basinName: result.isClear ? null : result.value),
    );
  }

  Future<void> _openBorderPerson(
    final BuildContext context,
    final String? borderText,
  ) async {
    final Parcel? match = resolveBorderMatch?.call(borderText);
    if (match == null) {
      context.showSnackBar('holdings.detail.border_no_data'.tr());
      return;
    }

    final List<Parcel> holdingParcels =
        getIt<HoldingsRepository>().parcelsForHolding(match.groupKey);
    await context.pushNamed(
      Routes.holdingDetail,
      arguments: holdingParcels,
    );
  }

  /// Copy ID is the field-worker completion action (`REFACTOR_ROADMAP.md`
  /// Phase 7, migrated to `completed_at`/`completed_by` in Phase 9 #12):
  /// validates required fields, copies the id, then marks the parcel
  /// completed via the same `setParcelCompleted` path `onFinish` uses —
  /// unless it's already completed, in which case this is a plain re-copy
  /// (re-marking an already-completed parcel via Copy ID would be a
  /// surprising side effect of an action the user takes repeatedly while
  /// working, e.g. to paste the id elsewhere after completion).
  Future<void> _copyId(final BuildContext context) async {
    final bool isCompleted = parcel.completedAt != null;
    if (!isNew && !isCompleted && !parcel.hasRequiredFieldsFilled) {
      final List<String> gaps = requiredFieldGapMessages(parcel);
      context.showErrorSnackBar(gaps.first);
      return;
    }

    await Clipboard.setData(ClipboardData(text: parcel.id));
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();

    if (isNew || isCompleted) {
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
      return;
    }

    try {
      await getIt<HoldingsRepository>()
          .setParcelCompleted(parcel.id, completed: true);
      if (!context.mounted) return;
      onFieldChanged(parcel.copyWith(completedAt: DateTime.now()));
      context.showSuccessSnackBar('holdings.detail.copied_and_reviewed'.tr());
    } catch (_) {
      if (context.mounted) context.showErrorSnackBar('errors.unknown'.tr());
    }
  }

  Future<void> _copyAll(final BuildContext context) async {
    if (!Parcel.isValueFilled(parcel.cropType)) {
      context
          .showErrorSnackBar('holdings.detail.crop_type_required_to_copy'.tr());
      return;
    }

    final String text = _formatter.format(
      parcel,
      hideCreditType: hideCreditType,
      associationType: associationType,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }

  Future<void> _confirmDelete(final BuildContext context) async {
    await AppDialogs.showConfirm(
      context,
      message: 'holdings.detail.delete_confirm'.tr(),
      confirmText: 'holdings.detail.delete'.tr(),
      onConfirm: onDelete!,
    );
  }
}
