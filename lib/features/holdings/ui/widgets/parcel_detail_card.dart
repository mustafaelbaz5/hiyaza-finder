import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/responsive_fields_wrap.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/see_more_section.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../../cities/domain/entities/city_type.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/services/clipboard_formatter.dart';
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
    this.isEdited = false,
    this.isNew = false,
    this.hideCreditType = false,
    this.cityType = CityType.unspecified,
    this.animationDelay = Duration.zero,
  });

  final Parcel parcel;

  /// Called with a fully-updated [Parcel] whenever a single field is saved
  /// via its inline pencil-icon editor — the only way fields are edited.
  final void Function(Parcel updated) onFieldChanged;
  final bool isEdited;

  /// Added in the field this session and not yet confirmed synced — shown
  /// independently of [isEdited] (a record can be both).
  final bool isNew;

  /// Omits نوع الائتمان from the field list, see-more section, and
  /// copy-all output for الإصلاح الزراعي cities. Passed in by the caller
  /// (`HoldingsRepository.hideCreditType`) rather than read via DI here,
  /// so this reusable/tested widget stays a pure function of its props.
  final bool hideCreditType;

  /// The active city's detected agricultural system — determines whether to
  /// display نوع الائتمان (agricultural credit) or نوع الإصلاح (reform).
  final CityType cityType;
  final Duration animationDelay;

  static const ClipboardFormatter _formatter = ClipboardFormatter();

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
          if (isEdited || isNew) ...<Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
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
                  if (isEdited)
                    _StatusBadge(
                      icon: Icons.edit_note_rounded,
                      label: 'holdings.edit.edited_badge'.tr(),
                      color: AppColors.amber300,
                    ),
                ],
              ),
            ),
            verticalSpacing(8),
          ],
          BorderCompass(
            holdingId: parcel.holdingId,
            north: parcel.borderNorth,
            south: parcel.borderSouth,
            east: parcel.borderEast,
            west: parcel.borderWest,
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
              ),
              FieldRow(
                label: 'اسم المالك',
                value: _formatter.effectiveOwnerName(parcel),
                onEdit: () => _editText(
                  context,
                  title: 'اسم المالك',
                  initialValue: _formatter.effectiveOwnerName(parcel) ?? '',
                  apply: (final String v) => parcel.copyWith(ownerName: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(label: 'اسم الحائز', value: parcel.holderName),
              FieldRow(label: 'الرقم القومي', value: parcel.nationalId),
              FieldRow(label: 'اسم الجمعية', value: parcel.associationName),
              FieldRow(label: 'اسم الحوض', value: parcel.basinName),
              FieldRow(label: 'رقم الأرض', value: parcel.landNumber),
              FieldRow(
                label: 'المساحة',
                value: _formatter.areaFraction(parcel),
                onEdit: () => _editArea(context),
              ),
              FieldRow(
                label: 'المساحة بالمتر',
                value: _formatter.formatNumber(parcel.totalSqm),
              ),
              FieldRow(
                label: 'نوع الزرع',
                value: parcel.cropType,
                onEdit: () => _editCropType(context),
              ),
              FieldRow(
                label: 'ملاحظات',
                value: parcel.notes,
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
            hideCreditType: hideCreditType,
            cityType: cityType,
          ),
        ],
      ),
    ).animate(delay: animationDelay).fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0);
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
        for (final String option in options) ChoiceOption<String>(value: option, label: option),
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

  Future<void> _copyAll(final BuildContext context) async {
    final String text = _formatter.format(
      parcel,
      hideCreditType: hideCreditType,
      cityType: cityType,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
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
