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
import '../../data/models/parcel.dart';
import '../../logic/services/area_calculator.dart';
import 'border_compass.dart';
import 'copy_all_button.dart';
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
    this.animationDelay = Duration.zero,
  });

  final Parcel parcel;

  /// Called with a fully-updated [Parcel] whenever a single field is saved
  /// via its inline pencil-icon editor — the only way fields are edited.
  final void Function(Parcel updated) onFieldChanged;
  final bool isEdited;
  final Duration animationDelay;

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
          if (isEdited) ...<Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber200.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 14,
                      color: AppColors.amber300,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'holdings.edit.edited_badge'.tr(),
                      style: AppTextStyles.font12Bold.copyWith(
                        color: AppColors.amber300,
                      ),
                    ),
                  ],
                ),
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
                value: parcel.holdingId,
              ),
              FieldRow(
                label: 'اسم المالك',
                value: _effectiveOwnerName(parcel),
                onEdit: () => _editText(
                  context,
                  title: 'اسم المالك',
                  initialValue: _effectiveOwnerName(parcel) ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(ownerName: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(label: 'اسم الحائز', value: parcel.holderName),
              FieldRow(label: 'الرقم القومي', value: parcel.nationalId),
              FieldRow(label: 'اسم الجمعية', value: parcel.associationName),
              FieldRow(label: 'اسم الحوض', value: parcel.basinName),
              FieldRow(label: 'رقم الأرض', value: parcel.landNumber),
              FieldRow(
                label: 'المساحة',
                value: _areaFraction(parcel),
                onEdit: () => _editArea(context),
              ),
              FieldRow(
                label: 'المساحة بالمتر',
                value: _formatNumber(parcel.totalSqm),
              ),
              FieldRow(
                label: 'نوع الزرع',
                value: parcel.cropType,
                onEdit: () => _editDropdown(
                  context,
                  title: 'نوع الزرع',
                  initialValue: parcel.cropType,
                  options: Parcel.cropTypeOptions,
                  apply: (final String? v) => parcel.copyWith(cropType: v),
                ),
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
          SeeMoreSection(parcel: parcel, onFieldChanged: onFieldChanged),
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

  /// اسم المالك defaults to اسم الحائز when not explicitly set — most
  /// owners and holders are the same person, so this saves re-typing the
  /// name while still letting it be overridden per parcel.
  String? _effectiveOwnerName(final Parcel p) {
    final String? owner = p.ownerName?.trim();
    if (owner != null && owner.isNotEmpty) return owner;
    final String? holder = p.holderName?.trim();
    return (holder != null && holder.isNotEmpty) ? holder : null;
  }

  /// `null`/empty values are formatted with [FieldRow.emptyPlaceholder] so
  /// the on-screen display and the copy-all text stay consistent.
  String? _formatNumber(final double? value) {
    if (value == null) return null;
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  String _areaFraction(final Parcel p) {
    final String feddan = _formatNumber(p.feddan) ?? FieldRow.emptyPlaceholder;
    final String qirat = _formatNumber(p.qirat) ?? FieldRow.emptyPlaceholder;
    final String sahm = _formatNumber(p.sahm) ?? FieldRow.emptyPlaceholder;
    return '$feddan فدان، $qirat قيراط، $sahm سهم';
  }

  Future<void> _copyAll(final BuildContext context) async {
    final String text = _formatForClipboard(parcel);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }

  /// One "label: value," field per line (blank slots kept, never skipped)
  /// so the pasted text both reads clearly on its own and lines up
  /// row-for-row when pasted into an external spreadsheet template.
  String _formatForClipboard(final Parcel p) {
    String slot(final String? v) =>
        (v == null || v.trim().isEmpty) ? FieldRow.emptyPlaceholder : v.trim();

    // اسم المالك only ever gets "(ورثة)" (مفوض doesn't touch it). اسم الحائز
    // gets "(مفوض عنه)" whenever مفوض is on — overriding "(ورثة)" there
    // specifically — otherwise "(ورثة)" if وراثة alone is on.
    String withPrefix(final String? prefixLabel, final String name) {
      final String display = name.isEmpty ? FieldRow.emptyPlaceholder : name;
      return prefixLabel == null ? display : '$prefixLabel $display';
    }

    final String holderName = p.holderName?.trim() ?? '';
    final String? holderPrefix =
        p.isDelegate ? '(مفوض عنه)' : (p.isInheritance ? '(ورثة)' : null);
    final String holderSlot = holderPrefix == null
        ? slot(p.holderName)
        : withPrefix(holderPrefix, holderName);

    final String ownerName = _effectiveOwnerName(p) ?? '';
    final String? ownerPrefix = p.isInheritance ? '(ورثة)' : null;
    final String ownerSlot = ownerPrefix == null
        ? slot(ownerName.isEmpty ? null : ownerName)
        : withPrefix(ownerPrefix, ownerName);
    final String nationalIdSlot =
        (p.nationalId == null || p.nationalId!.trim().isEmpty)
            ? '11111111111111'
            : p.nationalId!.trim();
    final String creditSentence =
        p.creditType == 'أوقاف' ? 'هذه الأرض تابعة لهيئة الأوقاف المصرية' : '';

    // Grouping فدان/قيراط/سهم and نوع الزرع/نوع الائتمان on shared lines
    // (instead of one field per line) trims the message's height while
    // keeping every field's own "label: value," so it still pastes cleanly
    // into a spreadsheet.
    String field(final String label, final String value) => '$label: $value,';

    final List<String> lines = <String>[
      field('رقم الحيازة', p.holdingId),
      field('اسم المالك', ownerSlot),
      field('اسم الحائز', holderSlot),
      field('الرقم القومي', nationalIdSlot),
      field('اسم الجمعية', slot(p.associationName)),
      field('اسم الحوض', slot(p.basinName)),
      field('رقم الأرض', slot(p.landNumber)),
      '${field('فدان', _formatNumber(p.feddan) ?? FieldRow.emptyPlaceholder)}     '
          '${field('قيراط', _formatNumber(p.qirat) ?? FieldRow.emptyPlaceholder)}   '
          '${field('سهم', _formatNumber(p.sahm) ?? FieldRow.emptyPlaceholder)}',
      field(
        'المساحة بالمتر',
        _formatNumber(p.totalSqm) ?? FieldRow.emptyPlaceholder,
      ),
      '${field('نوع الزرع', slot(p.cropType))}   '
          '${field('نوع الائتمان', creditSentence.isEmpty ? p.creditType : creditSentence)}',
      field('ملاحظات', slot(p.notes)),
    ];

    return lines.join('\n');
  }
}
