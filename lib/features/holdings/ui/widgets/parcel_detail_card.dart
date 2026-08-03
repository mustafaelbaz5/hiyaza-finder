import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/responsive_fields_wrap.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/see_more_section.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
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
import '../../logic/services/area_calculator.dart';
import 'border_compass.dart';
import 'copy_all_button.dart';
import 'crop_type_picker.dart';
import 'field_edit_dialogs.dart';
import 'field_row.dart';

/// One parcel's full record: border compass + field tiles + copy-all.
/// Detail screens stack one of these per parcel belonging to a holding.
/// Fields are laid out in a responsive wrap (1 column on phones, more on
/// tablets/laptops) so the card stays compact instead of one long list.
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
  });

  final Parcel parcel;

  /// Called with a fully-updated [Parcel] whenever a single field is saved
  /// via its inline pencil-icon editor — the only way fields are edited.
  final void Function(Parcel updated) onFieldChanged;

  /// [parcel]'s pre-edit value (`HoldingsRepository.originalParcel`) — each
  /// field below compares itself against the matching field here to decide
  /// whether to show its own "معدلة" badge. `null` means "no original to
  /// compare against" (e.g. a widget test with no repository), in which
  /// case no field shows as modified. Deliberately per-field rather than
  /// one whole-card "edited" flag, so a card with many fields only flags
  /// the ones that actually changed.
  final Parcel? originalParcel;

  /// Added in the field this session and not yet confirmed synced.
  final bool isNew;

  /// Shows a delete (trash) icon when non-null and removes this parcel on
  /// confirm. Passed in by the caller (`DetailScreen`, gated on
  /// `HoldingsRepository.canDeleteLocalParcel`) rather than decided here —
  /// only a still-unsynced, field-added record can be deleted at all (see
  /// that method's doc for why), and checking eligibility is async, so this
  /// widget stays a pure function of its props instead of resolving it
  /// itself during `build()`.
  final VoidCallback? onDelete;

  /// Omits نوع الائتمان from the field list, see-more section, and
  /// copy-all output for الإصلاح الزراعي cities. Passed in by the caller
  /// (`HoldingsRepository.hideCreditType`) rather than read via DI here,
  /// so this reusable/tested widget stays a pure function of its props.
  final bool hideCreditType;

  /// The active city's association type, read from
  /// `cities.association_type` — determines whether to display نوع الائتمان
  /// (agricultural credit) or نوع الإصلاح (reform). `null` when unset.
  final AssociationType? associationType;
  final Duration animationDelay;

  /// Resolves a الحدود cell's text to the holding it refers to, for both
  /// the compass's navigable-cell highlighting and the tap navigation
  /// itself. Passed in by the caller (`DetailScreen`, via
  /// `HoldingsRepository.findByBorderText`) — same reasoning as
  /// [hideCreditType]: this widget stays a pure function of its props and
  /// never resolves DI during `build()`, so it renders correctly in
  /// isolation (incl. widget tests) whether or not one is provided. `null`
  /// means "no border navigation available" — every cell renders plain.
  final Parcel? Function(String? borderText)? resolveBorderMatch;

  static const ClipboardFormatter _formatter = ClipboardFormatter();

  /// Whether the field read via [current] from [parcel] differs from
  /// [originalParcel]'s value for the same field — `false` (never modified)
  /// when [originalParcel] is `null`. Mirrors `AddRecordScreen._isModified`,
  /// just comparing against the saved original instead of a form's
  /// in-session initial value.
  bool _isModified<T>(final T Function(Parcel p) current) {
    final Parcel? original = originalParcel;
    if (original == null) return false;
    return FieldChangeTracker.isModified(current(parcel), current(original));
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      padding: EdgeInsets.all(rw(12)),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isNew || onDelete != null) ...<Widget>[
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (isNew)
                        _StatusBadge(
                          icon: Icons.fiber_new_rounded,
                          label: 'holdings.detail.new_badge'.tr(),
                          color: AppColors.blue200,
                        ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.red200),
                    tooltip: 'holdings.detail.delete'.tr(),
                    onPressed: () => _confirmDelete(context),
                  ),
              ],
            ),
            verticalSpacing(8),
          ],
          _ParcelIdChip(id: parcel.id, onCopy: () => _copyId(context)),
          verticalSpacing(8),
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
          verticalSpacing(8),
          CopyAllButton(onTap: () => _copyAll(context)),
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
                label: 'اسم المالك',
                value: _formatter.effectiveOwnerName(parcel),
                isModified: _isModified((final p) => p.ownerName),
                onEdit: () => _editText(
                  context,
                  title: 'اسم المالك',
                  initialValue: _formatter.effectiveOwnerName(parcel) ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(ownerName: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'اسم الحائز',
                value: parcel.holderName,
                isModified: _isModified((final p) => p.holderName),
                onEdit: () => _editText(
                  context,
                  title: 'اسم الحائز',
                  initialValue: parcel.holderName ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(holderName: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'الرقم القومي',
                value: parcel.nationalId,
                isModified: _isModified((final p) => p.nationalId),
                onEdit: () => _editText(
                  context,
                  title: 'الرقم القومي',
                  initialValue: parcel.nationalId ?? '',
                  keyboardType: TextInputType.number,
                  apply: (final String v) =>
                      parcel.copyWith(nationalId: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'اسم الجمعية',
                value: parcel.associationName,
                isModified: _isModified((final p) => p.associationName),
                onEdit: () => _editText(
                  context,
                  title: 'اسم الجمعية',
                  initialValue: parcel.associationName ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(associationName: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'اسم الحوض',
                value: parcel.basinName,
                isModified: _isModified((final p) => p.basinName),
                onEdit: () => _editBasin(context),
              ),
              FieldRow(
                label: 'رقم الأرض',
                value: parcel.landNumber,
                isModified: _isModified((final p) => p.landNumber),
                onEdit: () => _editText(
                  context,
                  title: 'رقم الأرض',
                  initialValue: parcel.landNumber ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(landNumber: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'المساحة',
                value: _formatter.areaFraction(parcel),
                isModified: _isModified((final p) => p.feddan) ||
                    _isModified((final p) => p.qirat) ||
                    _isModified((final p) => p.sahm),
                onEdit: () => _editArea(context),
              ),
              FieldRow(
                label: 'المساحة بالمتر',
                value: _formatter.formatNumber(parcel.totalSqm),
                isModified: _isModified((final p) => p.totalSqm),
                onEdit: () => _editArea(context),
              ),
              FieldRow(
                label: 'نوع الزرع',
                value: parcel.cropType,
                isModified: _isModified((final p) => p.cropType),
                onEdit: () => _editCropType(context),
              ),
              FieldRow(
                label: 'ملاحظات',
                value: parcel.notes,
                isModified: _isModified((final p) => p.notes),
                onEdit: () => _editDropdown(
                  context,
                  title: 'ملاحظات',
                  initialValue: parcel.notes,
                  options: Parcel.notesOptions,
                  apply: (final String? v) => parcel.copyWith(notes: v),
                ),
              ),
            ],
          ),
          verticalSpacing(6),
          SeeMoreSection(
            parcel: parcel,
            onFieldChanged: onFieldChanged,
            originalParcel: originalParcel,
            hideCreditType: hideCreditType,
            associationType: associationType,
          ),
        ],
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
        title: 'اسم الحوض',
        initialValue: parcel.basinName ?? '',
        apply: (final String v) =>
            parcel.copyWith(basinName: v.isEmpty ? null : v),
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
      selected: parcel.basinName,
      clearLabel: '—',
    );
    if (result == null) return;
    onFieldChanged(
      parcel.copyWith(basinName: result.isClear ? null : result.value),
    );
  }

  /// Resolves [borderText] (a الحدود cell) to the holding it refers to and
  /// navigates there directly, or shows a "no data" snackbar when it can't
  /// be resolved (blank text, a road/canal/etc., or no matching حائز/مالك
  /// in the currently loaded city). See `ParcelQueryService.findByBorderText`
  /// for why the match is exact rather than fuzzy.
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

  Future<void> _copyId(final BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: parcel.id));
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }

  Future<void> _copyAll(final BuildContext context) async {
    // نوع الزرع must have a real value before copy-all is allowed — same
    // "not blank / not '-'" rule as the add-record form's required fields
    // (`Parcel.isValueFilled`), so a record missing it doesn't get copied
    // out with a meaningless placeholder.
    if (!Parcel.isValueFilled(parcel.cropType)) {
      context.showErrorSnackBar('holdings.detail.crop_type_required_to_copy'.tr());
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

/// A small tinted pill used for the "edited" and "new / pending sync"
/// markers above a [ParcelDetailCard]'s fields.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.font12Bold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// The parcel's stable cross-system id ([Parcel.id]) — shown above every
/// other field, in a dedicated tappable pill rather than a plain [FieldRow],
/// since it needs to be copied far more often than edited (it's never
/// editable at all) and is easy to mistake for رقم الحيازة otherwise.
class _ParcelIdChip extends StatelessWidget {
  const _ParcelIdChip({required this.id, required this.onCopy});

  final String id;
  final VoidCallback onCopy;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Material(
      color: colors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onCopy,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.green200.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.green200),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'holdings.detail.parcel_id'.tr(),
                      style: AppTextStyles.font12Bold.copyWith(color: colors.textSecondary),
                    ),
                    Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.font14Bold,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded, size: 18, color: AppColors.green200),
            ],
          ),
        ),
      ),
    );
  }
}
